//
//  CertificateStore.swift
//  gym_systemOS
//
//  Carga del certificado .p12 (SecPKCS12Import) y su almacenamiento seguro en
//  el Keychain de iOS. El .p12 y su clave se configuran EN RUNTIME (pantalla de
//  Configuración) — nunca se hardcodean ni viajan en el bundle. Sustituye a la
//  carga desde disco de sri/signer.py (cargar_p12).
//

import Foundation
import Security

/// Certificado cargado y listo para firmar.
struct LoadedCertificate {
    let privateKey: SecKey
    let certificate: SecCertificate
    let certDER: Data
    let issuerRFC4514: String
    let serialDecimal: String
    let modulus: Data     // big-endian mínimo (como pub.n.to_bytes en Python)
    let exponent: Data    // big-endian mínimo
}

/// Datos del certificado para mostrar en la UI (equivale a info_certificado).
struct CertificateInfo {
    let subject: String
    let issuer: String
    let serial: String
    let validoDesde: String?
    let validoHasta: String?
}

enum CertificateError: LocalizedError {
    case claveIncorrecta
    case p12Invalido
    case sinClavePrivada
    case noRSA
    case noConfigurado

    var errorDescription: String? {
        switch self {
        case .claveIncorrecta: return "Clave del certificado incorrecta."
        case .p12Invalido:     return "El archivo .p12 no es válido o está dañado."
        case .sinClavePrivada: return "El .p12 no contiene una clave privada."
        case .noRSA:           return "El SRI requiere certificados con clave RSA."
        case .noConfigurado:   return "No hay certificado configurado. Cárgalo en Configuración."
        }
    }
}

enum CertificateStore {
    private static let service = "TOQ.gym-systemOS.sri"
    private static let accountData = "p12.data"
    private static let accountPass = "p12.pass"

    // MARK: - Importar / guardar

    /// Importa y guarda el .p12 en Keychain. Devuelve info para la UI.
    @discardableResult
    static func importAndSave(p12: Data, password: String) throws -> CertificateInfo {
        let loaded = try load(p12: p12, password: password) // valida clave/formato
        let info = try info(from: loaded)
        try keychainSet(account: accountData, data: p12)
        try keychainSet(account: accountPass, data: Data(password.utf8))
        return info
    }

    static func hasCertificate() -> Bool { keychainGet(account: accountData) != nil }

    static func clear() {
        keychainDelete(account: accountData)
        keychainDelete(account: accountPass)
    }

    // MARK: - Cargar para firmar

    /// Carga el certificado guardado en Keychain, listo para firmar.
    static func loadStored() throws -> LoadedCertificate {
        guard let data = keychainGet(account: accountData) else { throw CertificateError.noConfigurado }
        let pass = keychainGet(account: accountPass).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return try load(p12: data, password: pass)
    }

    // MARK: - Núcleo de carga (SecPKCS12Import)

    static func load(p12: Data, password: String) throws -> LoadedCertificate {
        let opts: [String: Any] = [kSecImportExportPassphrase as String: password]
        var itemsCF: CFArray?
        let status = SecPKCS12Import(p12 as CFData, opts as CFDictionary, &itemsCF)

        if status == errSecAuthFailed { throw CertificateError.claveIncorrecta }
        guard status == errSecSuccess,
              let items = itemsCF as? [[String: Any]],
              let first = items.first else {
            throw CertificateError.p12Invalido
        }
        guard let identityAny = first[kSecImportItemIdentity as String] else {
            throw CertificateError.sinClavePrivada
        }
        guard CFGetTypeID(identityAny as CFTypeRef) == SecIdentityGetTypeID() else {
            throw CertificateError.p12Invalido
        }
        let identity = identityAny as! SecIdentity

        var pk: SecKey?
        var cert: SecCertificate?
        guard SecIdentityCopyPrivateKey(identity, &pk) == errSecSuccess, let privateKey = pk,
              SecIdentityCopyCertificate(identity, &cert) == errSecSuccess, let certificate = cert else {
            throw CertificateError.p12Invalido
        }

        // Verificar que es RSA.
        guard let attrs = SecKeyCopyAttributes(privateKey) as? [String: Any],
              (attrs[kSecAttrKeyType as String] as? String) == (kSecAttrKeyTypeRSA as String) else {
            throw CertificateError.noRSA
        }

        let certDER = SecCertificateCopyData(certificate) as Data
        guard let (issuer, serial) = X509.issuerAndSerial(fromCertificate: certDER).map({ ($0.issuer, $0.serial) }) else {
            throw CertificateError.p12Invalido
        }
        let (modulus, exponent) = try rsaModulusExponent(privateKey)

        return LoadedCertificate(privateKey: privateKey, certificate: certificate,
                                 certDER: certDER, issuerRFC4514: issuer,
                                 serialDecimal: serial, modulus: modulus, exponent: exponent)
    }

    /// Modulus y exponente (big-endian mínimo) de la clave pública RSA.
    private static func rsaModulusExponent(_ privateKey: SecKey) throws -> (Data, Data) {
        guard let pub = SecKeyCopyPublicKey(privateKey),
              let ext = SecKeyCopyExternalRepresentation(pub, nil) as Data? else {
            throw CertificateError.p12Invalido
        }
        // RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER }
        var r = DERReader([UInt8](ext))
        guard let seq = r.read(), seq.tag == 0x30 else { throw CertificateError.p12Invalido }
        var ir = DERReader(seq.bytes)
        guard let mod = ir.read(), mod.tag == 0x02,
              let exp = ir.read(), exp.tag == 0x02 else { throw CertificateError.p12Invalido }
        return (Data(stripLeadingZeros(mod.bytes)), Data(stripLeadingZeros(exp.bytes)))
    }

    private static func stripLeadingZeros(_ bytes: [UInt8]) -> [UInt8] {
        var b = bytes
        while b.count > 1 && b.first == 0 { b.removeFirst() }
        return b
    }

    static func info(from loaded: LoadedCertificate) throws -> CertificateInfo {
        let fields = X509.parse(certificate: loaded.certDER)
        let subject = (SecCertificateCopySubjectSummary(loaded.certificate) as String?) ?? "—"
        return CertificateInfo(subject: subject,
                               issuer: loaded.issuerRFC4514,
                               serial: loaded.serialDecimal,
                               validoDesde: fields?.notBefore,
                               validoHasta: fields?.notAfter)
    }

    // MARK: - Keychain (generic password)

    private static func keychainSet(account: String, data: Data) throws {
        keychainDelete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CertificateError.p12Invalido }
    }

    private static func keychainGet(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    private static func keychainDelete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
