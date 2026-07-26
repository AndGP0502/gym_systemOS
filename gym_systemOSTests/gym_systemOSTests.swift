//
//  gym_systemOSTests.swift
//  gym_systemOSTests
//
//  Pruebas de auto-consistencia del motor SRI (firma XAdES-BES).
//  Como no se puede validar contra el SRI real en este entorno, se verifica que
//  la firma producida sea criptográficamente coherente: la firma RSA valida
//  contra el certificado y los 3 digests coinciden con los elementos firmados.
//

import XCTest
import CryptoKit
import Security
@testable import gym_systemOS

final class gym_systemOSTests: XCTestCase {

    private func loadCert() throws -> LoadedCertificate {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "test_cert", withExtension: "p12"),
                                "Falta test_cert.p12 en el bundle de pruebas")
        let data = try Data(contentsOf: url)
        return try CertificateStore.load(p12: data, password: "test123")
    }

    // MARK: - Extracción de certificado

    func testIssuerRFC4514_yModExp() throws {
        let cert = try loadCert()
        XCTAssertEqual(cert.issuerRFC4514,
                       "CN=PRUEBA GYM SYSTEM,OU=ENTIDAD DE CERTIFICACION,O=SECURITY DATA S.A.,C=EC")
        XCTAssertFalse(cert.serialDecimal.isEmpty)
        XCTAssertFalse(cert.modulus.isEmpty)
        XCTAssertEqual([UInt8](cert.exponent), [0x01, 0x00, 0x01]) // 65537
    }

    // MARK: - C14N

    func testC14NBasico() throws {
        let out = try XCTUnwrap(Canonicalizer.c14n("<a><b>x</b></a>"))
        XCTAssertEqual(String(data: out, encoding: .utf8), "<a><b>x</b></a>")
    }

    // MARK: - Clave de acceso / módulo 11

    func testModulo11Deterministico() {
        XCTAssertTrue((0...11).contains(SRIXMLGenerator.modulo11("123456789")))
        // clave de acceso: 49 dígitos (48 + verificador)
        let clave = SRIXMLGenerator.claveDeAcceso(fecha: "2026-07-26", tipoComprobante: "01",
            ruc: "9999999999001", ambiente: 1, serie: "001001", secuencial: "000000001",
            codigoNumerico: "12345678", tipoEmision: 1)
        XCTAssertEqual(clave.count, 49)
    }

    // MARK: - Firma XAdES-BES auto-consistente

    func testFirmaXAdESAutoConsistente() throws {
        let cert = try loadCert()
        let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
            + "<factura id=\"comprobante\" version=\"2.1.0\">"
            + "<infoTributaria><ruc>9999999999001</ruc></infoTributaria>"
            + "<infoFactura><importeTotal>1.15</importeTotal></infoFactura>"
            + "</factura>"

        let firmado = try XAdESSigner.firmar(xml: xml, certificado: cert)

        // Estructura básica
        XCTAssertTrue(firmado.contains("<ds:Signature"))
        XCTAssertTrue(firmado.contains("Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\""))
        XCTAssertEqual(firmado.components(separatedBy: "<ds:Reference").count - 1, 3, "Deben existir 3 referencias")

        // 1) La firma RSA sobre SignedInfo debe validar contra el certificado.
        let signedInfo = try extract(firmado, tag: "ds:SignedInfo")
        let siC14N = try XCTUnwrap(Canonicalizer.c14n(injectNs(signedInfo, "ds:SignedInfo")))
        let sigValue = try XCTUnwrap(Data(base64Encoded:
            innerText(try extract(firmado, tag: "ds:SignatureValue")).replacingOccurrences(of: "\n", with: "")))
        let pub = try XCTUnwrap(SecCertificateCopyKey(cert.certificate))
        var err: Unmanaged<CFError>?
        let ok = SecKeyVerifySignature(pub, .rsaSignatureMessagePKCS1v15SHA1,
                                       siC14N as CFData, sigValue as CFData, &err)
        XCTAssertTrue(ok, "La firma RSA sobre SignedInfo debe validar")

        // 2) Digest del comprobante (enveloped) = sha1(c14n(xml original)).
        let sha1Comp = sha1B64(try XCTUnwrap(Canonicalizer.c14n(xml)))
        XCTAssertTrue(signedInfo.contains(sha1Comp), "Digest del comprobante debe coincidir")

        // 3) Digest de SignedProperties (con ns heredados).
        let sp = try extract(firmado, tag: "etsi:SignedProperties")
        let sha1SP = sha1B64(try XCTUnwrap(Canonicalizer.c14n(injectNs(sp, "etsi:SignedProperties"))))
        XCTAssertTrue(signedInfo.contains(sha1SP), "Digest de SignedProperties debe coincidir")

        // 4) Digest de KeyInfo (con ns heredados).
        let ki = try extract(firmado, tag: "ds:KeyInfo")
        let sha1KI = sha1B64(try XCTUnwrap(Canonicalizer.c14n(injectNs(ki, "ds:KeyInfo"))))
        XCTAssertTrue(signedInfo.contains(sha1KI), "Digest de KeyInfo debe coincidir")
    }

    // MARK: - Helpers

    private func sha1B64(_ d: Data) -> String {
        Data(Insecure.SHA1.hash(data: d)).base64EncodedString()
    }

    private func extract(_ s: String, tag: String) throws -> String {
        let open = try XCTUnwrap(s.range(of: "<\(tag)"))
        let close = try XCTUnwrap(s.range(of: "</\(tag)>", range: open.upperBound..<s.endIndex))
        return String(s[open.lowerBound..<close.upperBound])
    }

    private func innerText(_ elem: String) -> String {
        guard let gt = elem.firstIndex(of: ">"),
              let lt = elem.range(of: "</", options: .backwards) else { return "" }
        return String(elem[elem.index(after: gt)..<lt.lowerBound])
    }

    private func injectNs(_ s: String, _ element: String) -> String {
        let ds = "xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\""
        let etsi = "xmlns:etsi=\"http://uri.etsi.org/01903/v1.3.2#\""
        return s.replacingOccurrences(of: "<\(element) ", with: "<\(element) \(ds) \(etsi) ")
    }
}
