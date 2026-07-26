//
//  XAdESSigner.swift
//  gym_systemOS
//
//  Firmador XAdES-BES para el SRI Ecuador — port fiel de sri/signer.py.
//  - C14N 1.0 inclusivo vía libxml2 (Canonicalizer) → bytes idénticos a lxml.
//  - Digests SHA1 con CryptoKit (Insecure.SHA1).
//  - Firma RSA-SHA1 PKCS#1 v1.5 con Security framework (SecKeyCreateSignature).
//  Estructura: 3 referencias (SignedProperties, KeyInfo, #comprobante enveloped),
//  con inyección de xmlns:ds/xmlns:etsi heredados antes de hashear (igual que Python).
//

import Foundation
import CryptoKit
import Security

enum XAdESError: LocalizedError {
    case c14nFallo
    case firmaFallo(String)
    var errorDescription: String? {
        switch self {
        case .c14nFallo: return "Error de canonicalización XML (C14N)."
        case .firmaFallo(let m): return "Error al firmar: \(m)"
        }
    }
}

enum XAdESSigner {

    private static let XMLNS_DS = "xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\""
    private static let XMLNS_ETSI = "xmlns:etsi=\"http://uri.etsi.org/01903/v1.3.2#\""

    static func firmar(xml xmlContent: String, certificado cert: LoadedCertificate) throws -> String {
        // Digest del comprobante (referencia enveloped = documento sin firma).
        guard let comprobanteC14N = Canonicalizer.c14n(xmlContent) else { throw XAdESError.c14nFallo }
        let sha1Comprobante = sha1B64(comprobanteC14N)

        // Datos del certificado.
        let certB64 = partirB64(cert.certDER.base64EncodedString())
        let sha1Cert = sha1B64(cert.certDER)
        let issuerName = cert.issuerRFC4514
        let serialNumber = cert.serialDecimal
        let moduloB64 = partirB64(cert.modulus.base64EncodedString())
        let exponenteB64 = cert.exponent.base64EncodedString()

        // IDs aleatorios (estilo ficha técnica SRI).
        let signatureId = randId()
        let signedinfoId = randId()
        let signedpropsId = randId()
        let signedpropsRefId = randId()
        let keyinfoId = randId()
        let sigvalueId = randId()
        let objectId = randId()
        let comprobanteRefId = randId()

        let signingTime = horaEcuador()

        // ── SignedProperties ──
        let signedProperties =
            "<etsi:SignedProperties Id=\"Signature\(signatureId)-SignedProperties\(signedpropsId)\">"
            + "<etsi:SignedSignatureProperties>"
            + "<etsi:SigningTime>\(signingTime)</etsi:SigningTime>"
            + "<etsi:SigningCertificate>"
            + "<etsi:Cert>"
            + "<etsi:CertDigest>"
            + "<ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></ds:DigestMethod>"
            + "<ds:DigestValue>\(sha1Cert)</ds:DigestValue>"
            + "</etsi:CertDigest>"
            + "<etsi:IssuerSerial>"
            + "<ds:X509IssuerName>\(issuerName)</ds:X509IssuerName>"
            + "<ds:X509SerialNumber>\(serialNumber)</ds:X509SerialNumber>"
            + "</etsi:IssuerSerial>"
            + "</etsi:Cert>"
            + "</etsi:SigningCertificate>"
            + "</etsi:SignedSignatureProperties>"
            + "<etsi:SignedDataObjectProperties>"
            + "<etsi:DataObjectFormat ObjectReference=\"#Reference-ID-\(comprobanteRefId)\">"
            + "<etsi:Description>contenido comprobante</etsi:Description>"
            + "<etsi:MimeType>text/xml</etsi:MimeType>"
            + "</etsi:DataObjectFormat>"
            + "</etsi:SignedDataObjectProperties>"
            + "</etsi:SignedProperties>"

        let spParaDigest = replacePrimero(signedProperties,
            "<etsi:SignedProperties ", "<etsi:SignedProperties \(XMLNS_DS) \(XMLNS_ETSI) ")
        guard let spC14N = Canonicalizer.c14n(spParaDigest) else { throw XAdESError.c14nFallo }
        let sha1SignedProperties = sha1B64(spC14N)

        // ── KeyInfo ──
        let keyInfo =
            "<ds:KeyInfo Id=\"Certificate\(keyinfoId)\">"
            + "<ds:X509Data>"
            + "<ds:X509Certificate>\n\(certB64)\n</ds:X509Certificate>"
            + "</ds:X509Data>"
            + "<ds:KeyValue>"
            + "<ds:RSAKeyValue>"
            + "<ds:Modulus>\n\(moduloB64)\n</ds:Modulus>"
            + "<ds:Exponent>\(exponenteB64)</ds:Exponent>"
            + "</ds:RSAKeyValue>"
            + "</ds:KeyValue>"
            + "</ds:KeyInfo>"

        let kiParaDigest = replacePrimero(keyInfo,
            "<ds:KeyInfo ", "<ds:KeyInfo \(XMLNS_DS) \(XMLNS_ETSI) ")
        guard let kiC14N = Canonicalizer.c14n(kiParaDigest) else { throw XAdESError.c14nFallo }
        let sha1KeyInfo = sha1B64(kiC14N)

        // ── SignedInfo ──
        let signedInfo =
            "<ds:SignedInfo Id=\"Signature-SignedInfo\(signedinfoId)\">"
            + "<ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"></ds:CanonicalizationMethod>"
            + "<ds:SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></ds:SignatureMethod>"
            + "<ds:Reference Id=\"SignedPropertiesID\(signedpropsRefId)\" "
            + "Type=\"http://uri.etsi.org/01903#SignedProperties\" "
            + "URI=\"#Signature\(signatureId)-SignedProperties\(signedpropsId)\">"
            + "<ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></ds:DigestMethod>"
            + "<ds:DigestValue>\(sha1SignedProperties)</ds:DigestValue>"
            + "</ds:Reference>"
            + "<ds:Reference URI=\"#Certificate\(keyinfoId)\">"
            + "<ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></ds:DigestMethod>"
            + "<ds:DigestValue>\(sha1KeyInfo)</ds:DigestValue>"
            + "</ds:Reference>"
            + "<ds:Reference Id=\"Reference-ID-\(comprobanteRefId)\" URI=\"#comprobante\">"
            + "<ds:Transforms>"
            + "<ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></ds:Transform>"
            + "</ds:Transforms>"
            + "<ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></ds:DigestMethod>"
            + "<ds:DigestValue>\(sha1Comprobante)</ds:DigestValue>"
            + "</ds:Reference>"
            + "</ds:SignedInfo>"

        let siParaFirma = replacePrimero(signedInfo,
            "<ds:SignedInfo ", "<ds:SignedInfo \(XMLNS_DS) \(XMLNS_ETSI) ")
        guard let siC14N = Canonicalizer.c14n(siParaFirma) else { throw XAdESError.c14nFallo }
        let firma = try rsaSha1(siC14N, key: cert.privateKey)
        let signatureValue = partirB64(firma.base64EncodedString())

        // ── Ensamblar firma completa ──
        let xades =
            "<ds:Signature \(XMLNS_DS) \(XMLNS_ETSI) Id=\"Signature\(signatureId)\">"
            + signedInfo
            + "<ds:SignatureValue Id=\"SignatureValue\(sigvalueId)\">\n\(signatureValue)\n</ds:SignatureValue>"
            + keyInfo
            + "<ds:Object Id=\"Signature\(signatureId)-Object\(objectId)\">"
            + "<etsi:QualifyingProperties Target=\"#Signature\(signatureId)\">"
            + signedProperties
            + "</etsi:QualifyingProperties>"
            + "</ds:Object>"
            + "</ds:Signature>"

        // Insertar la firma antes del cierre del elemento raíz.
        let sinDecl = quitarDeclaracion(xmlContent)
        guard let posCierre = sinDecl.range(of: "</", options: .backwards) else {
            throw XAdESError.firmaFallo("XML sin etiqueta de cierre")
        }
        let antes = String(sinDecl[sinDecl.startIndex..<posCierre.lowerBound])
        let despues = String(sinDecl[posCierre.lowerBound...])
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" + antes + xades + despues
    }

    // MARK: - Helpers

    private static func sha1B64(_ data: Data) -> String {
        Data(Insecure.SHA1.hash(data: data)).base64EncodedString()
    }

    private static func partirB64(_ b64: String, _ ancho: Int = 76) -> String {
        var out: [String] = []
        var idx = b64.startIndex
        while idx < b64.endIndex {
            let end = b64.index(idx, offsetBy: ancho, limitedBy: b64.endIndex) ?? b64.endIndex
            out.append(String(b64[idx..<end]))
            idx = end
        }
        return out.joined(separator: "\n")
    }

    private static func randId() -> Int { Int.random(in: 990...999000) }

    private static func replacePrimero(_ s: String, _ target: String, _ repl: String) -> String {
        guard let r = s.range(of: target) else { return s }
        return s.replacingCharacters(in: r, with: repl)
    }

    private static func quitarDeclaracion(_ xml: String) -> String {
        if let r = xml.range(of: "?>") {
            return String(xml[r.upperBound...])
        }
        return xml
    }

    /// Hora local de Ecuador (UTC-5) en formato `yyyy-MM-ddTHH:mm:ss-05:00`.
    private static func horaEcuador() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Guayaquil")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.string(from: Date()) + "-05:00"
    }

    /// Firma RSA-SHA1 PKCS#1 v1.5 sobre el MENSAJE (SecKey hace el SHA1 interno).
    private static func rsaSha1(_ data: Data, key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let sig = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA1,
                                              data as CFData, &error) as Data? else {
            let msg = (error?.takeRetainedValue()).map { CFErrorCopyDescription($0) as String } ?? "desconocido"
            throw XAdESError.firmaFallo(msg)
        }
        return sig
    }
}
