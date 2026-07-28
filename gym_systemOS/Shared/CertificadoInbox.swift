//
//  CertificadoInbox.swift
//  gym_systemOS
//
//  Recibe un .p12 que el cliente comparte a la app desde su iPad
//  (Compartir → gym_systemOS / «Abrir en»). El archivo llega por onOpenURL;
//  aquí se guarda hasta que la pantalla de Configuración lo consuma.
//

import Foundation
import Combine

@MainActor
final class CertificadoInbox: ObservableObject {
    static let shared = CertificadoInbox()

    @Published var data: Data?
    @Published var nombre: String?

    /// Lee el archivo entrante (URL con alcance de seguridad) y lo retiene.
    func recibir(url: URL) {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        guard let d = try? Data(contentsOf: url), !d.isEmpty else { return }
        data = d
        nombre = url.lastPathComponent
    }

    /// Entrega y limpia el certificado pendiente (lo consume una sola vez).
    func consumir() -> (data: Data, nombre: String)? {
        guard let d = data, let n = nombre else { return nil }
        data = nil; nombre = nil
        return (d, n)
    }
}
