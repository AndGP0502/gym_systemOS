//
//  DER.swift
//  gym_systemOS
//
//  Lector ASN.1/DER mínimo para extraer del certificado X.509 el IssuerName
//  (formato RFC 4514, igual que cryptography.rfc4514_string) y el serial en
//  decimal — datos que el SRI exige en <ds:X509IssuerName>/<X509SerialNumber>.
//

import Foundation

/// Un TLV (Tag-Length-Value) DER.
struct DERNode {
    let tag: UInt8
    let bytes: [UInt8]        // contenido (value)
    let range: Range<Int>     // rango del value dentro del buffer original
}

struct DERReader {
    let data: [UInt8]
    var i: Int
    let end: Int

    init(_ data: [UInt8]) { self.data = data; self.i = 0; self.end = data.count }
    init(_ data: [UInt8], _ start: Int, _ end: Int) { self.data = data; self.i = start; self.end = end }

    /// Lee el siguiente TLV y avanza el cursor.
    mutating func read() -> DERNode? {
        guard i < end else { return nil }
        let tag = data[i]; i += 1
        guard i < end else { return nil }
        var len = Int(data[i]); i += 1
        if len & 0x80 != 0 {
            let n = len & 0x7F
            guard n > 0, i + n <= end else { return nil }
            len = 0
            for _ in 0..<n { len = (len << 8) | Int(data[i]); i += 1 }
        }
        guard i + len <= end else { return nil }
        let start = i
        let content = Array(data[start..<start + len])
        i += len
        return DERNode(tag: tag, bytes: content, range: start..<start + len)
    }
}

enum X509 {
    struct Fields {
        let issuer: String
        let serial: String
        let notBefore: String?
        let notAfter: String?
    }

    /// Extrae issuer (RFC4514), serial decimal y validez del DER del certificado.
    static func parse(certificate der: Data) -> Fields? {
        let bytes = [UInt8](der)
        var top = DERReader(bytes)
        // Certificate ::= SEQUENCE { tbsCertificate, sigAlg, sigValue }
        guard let cert = top.read(), cert.tag == 0x30 else { return nil }
        var tbsR = DERReader(cert.bytes)
        guard let tbs = tbsR.read(), tbs.tag == 0x30 else { return nil }

        // Dentro de tbsCertificate:
        //   [0] version (opcional, tag 0xA0), serialNumber INTEGER,
        //   signature SEQUENCE, issuer Name, validity SEQUENCE, ...
        var inner = DERReader(tbs.bytes)
        guard var node = inner.read() else { return nil }
        if node.tag == 0xA0 { // version explícita → saltar
            guard let n2 = inner.read() else { return nil }
            node = n2
        }
        guard node.tag == 0x02 else { return nil } // serialNumber INTEGER
        let serial = decimalString(fromBigEndian: node.bytes)

        guard let _ = inner.read() else { return nil }                 // signature AlgId
        guard let issuerNode = inner.read(), issuerNode.tag == 0x30 else { return nil }
        let issuer = rfc4514(fromName: issuerNode.bytes)

        // validity SEQUENCE { notBefore Time, notAfter Time }
        var nb: String? = nil, na: String? = nil
        if let validity = inner.read(), validity.tag == 0x30 {
            var vR = DERReader(validity.bytes)
            if let t1 = vR.read() { nb = decodeTime(t1) }
            if let t2 = vR.read() { na = decodeTime(t2) }
        }
        return Fields(issuer: issuer, serial: serial, notBefore: nb, notAfter: na)
    }

    /// Conveniencia para el firmador (solo issuer + serial).
    static func issuerAndSerial(fromCertificate der: Data) -> (issuer: String, serial: String)? {
        guard let f = parse(certificate: der) else { return nil }
        return (f.issuer, f.serial)
    }

    private static func decodeTime(_ node: DERNode) -> String? {
        String(bytes: node.bytes, encoding: .ascii)
    }

    // MARK: - Name → RFC 4514

    /// Mapa OID → nombre corto (idéntico al de cryptography rfc4514_string).
    private static let oidNames: [String: String] = [
        "2.5.4.3": "CN", "2.5.4.6": "C", "2.5.4.7": "L", "2.5.4.8": "ST",
        "2.5.4.10": "O", "2.5.4.11": "OU", "2.5.4.9": "STREET",
        "0.9.2342.19200300.100.1.25": "DC", "0.9.2342.19200300.100.1.1": "UID",
    ]

    /// Name ::= SEQUENCE OF RelativeDistinguishedName (SET OF ATV).
    /// RFC 4514 emite los RDN en orden INVERSO al DER.
    private static func rfc4514(fromName nameContent: [UInt8]) -> String {
        var r = DERReader(nameContent)
        var rdns: [String] = []
        while let rdn = r.read(), rdn.tag == 0x31 { // SET
            var setR = DERReader(rdn.bytes)
            var atvs: [String] = []
            while let atv = setR.read(), atv.tag == 0x30 { // SEQUENCE {OID, value}
                var aR = DERReader(atv.bytes)
                guard let oidNode = aR.read(), oidNode.tag == 0x06,
                      let valNode = aR.read() else { continue }
                let oid = decodeOID(oidNode.bytes)
                let name = oidNames[oid] ?? oid
                let value = decodeString(valNode.bytes)
                atvs.append("\(name)=\(escape(value))")
            }
            rdns.append(atvs.joined(separator: "+"))
        }
        return rdns.reversed().joined(separator: ",")
    }

    /// Escapado de valores DN según RFC 4514 (igual que cryptography).
    private static func escape(_ v: String) -> String {
        if v.isEmpty { return "" }
        var s = v
        s = s.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: "\"", with: "\\\"")
        s = s.replacingOccurrences(of: "+", with: "\\+")
        s = s.replacingOccurrences(of: ",", with: "\\,")
        s = s.replacingOccurrences(of: ";", with: "\\;")
        s = s.replacingOccurrences(of: "<", with: "\\<")
        s = s.replacingOccurrences(of: ">", with: "\\>")
        if let f = s.first, f == "#" || f == " " { s = "\\" + s }
        if let l = s.last, l == " " { s = String(s.dropLast()) + "\\ " }
        return s
    }

    private static func decodeString(_ bytes: [UInt8]) -> String {
        if let s = String(bytes: bytes, encoding: .utf8) { return s }
        return String(bytes: bytes, encoding: .isoLatin1) ?? ""
    }

    /// OID (tag 0x06) → dotted string.
    private static func decodeOID(_ bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else { return "" }
        var parts: [String] = []
        let first = Int(bytes[0])
        parts.append("\(first / 40)")
        parts.append("\(first % 40)")
        var value = 0
        for i in 1..<bytes.count {
            let b = Int(bytes[i])
            value = (value << 7) | (b & 0x7F)
            if b & 0x80 == 0 {
                parts.append("\(value)")
                value = 0
            }
        }
        return parts.joined(separator: ".")
    }

    /// Bytes big-endian (INTEGER positivo) → decimal string.
    static func decimalString(fromBigEndian bytes: [UInt8]) -> String {
        var b = bytes
        // Quitar posible byte de signo 0x00 inicial.
        while b.count > 1 && b.first == 0 { b.removeFirst() }
        if b.isEmpty { return "0" }
        var digits: [Int] = [0]
        for byte in b {
            var carry = Int(byte)
            for j in 0..<digits.count {
                let v = digits[j] * 256 + carry
                digits[j] = v % 10
                carry = v / 10
            }
            while carry > 0 { digits.append(carry % 10); carry /= 10 }
        }
        return digits.reversed().map(String.init).joined()
    }
}
