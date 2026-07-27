//
//  AppSettings.swift
//  gym_systemOS
//
//  PIN de protección para operaciones destructivas (port de la "clave" que el
//  escritorio pedía para borrar todo / editar fechas). El PIN se guarda hasheado
//  (SHA-256) en UserDefaults; nunca en texto plano.
//

import Foundation
import CryptoKit

enum AppSettings {
    private static let pinKey = "gym.pin.sha256"

    /// ¿Hay un PIN configurado?
    static var pinConfigurado: Bool {
        UserDefaults.standard.string(forKey: pinKey) != nil
    }

    private static func hash(_ pin: String) -> String {
        let d = SHA256.hash(data: Data(pin.utf8))
        return d.map { String(format: "%02x", $0) }.joined()
    }

    /// Fija (o cambia) el PIN.
    static func setPIN(_ pin: String) {
        UserDefaults.standard.set(hash(pin), forKey: pinKey)
    }

    static func borrarPIN() {
        UserDefaults.standard.removeObject(forKey: pinKey)
    }

    /// Verifica el PIN. Si no hay PIN configurado, devuelve true (sin protección).
    static func verificar(_ pin: String) -> Bool {
        guard let guardado = UserDefaults.standard.string(forKey: pinKey) else { return true }
        return guardado == hash(pin)
    }
}
