//
//  ConfiguracionViewModel.swift
//  gym_systemOS
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ConfiguracionViewModel: ObservableObject {
    @Published var config = ConfiguracionSRI.nueva()
    @Published var certInfo: CertificateInfo?
    @Published var tieneCertificado = false
    @Published var clave = ""
    @Published var mensaje: String?
    @Published var mostrarMensaje = false

    private var repo: ConfiguracionRepo?

    func setup(db: AppDatabase) {
        guard repo == nil else { return }
        repo = ConfiguracionRepo(db: db)
        if let existente = repo?.obtener() { config = existente }
        tieneCertificado = CertificateStore.hasCertificate()
        if tieneCertificado { certInfo = try? CertificateStore.info(from: CertificateStore.loadStored()) }
    }

    func guardar() {
        guard let repo else { return }
        if config.ruc.trimmingCharacters(in: .whitespaces).isEmpty {
            return notificar("El RUC es obligatorio")
        }
        if config.razonSocial.trimmingCharacters(in: .whitespaces).isEmpty {
            return notificar("La razón social es obligatoria")
        }
        notificar(repo.guardar(config).mensaje)
    }

    /// Importa el .p12 y lo guarda en Keychain (config en runtime).
    func cargarCertificado(data: Data) {
        do {
            let info = try CertificateStore.importAndSave(p12: data, password: clave)
            certInfo = info
            tieneCertificado = true
            config.rutaCertificado = "keychain"   // marcador; el .p12 vive en Keychain
            clave = ""
            notificar("Certificado cargado: \(info.subject)")
        } catch {
            notificar(error.localizedDescription)
        }
    }

    func quitarCertificado() {
        CertificateStore.clear()
        tieneCertificado = false
        certInfo = nil
        config.rutaCertificado = nil
    }

    private func notificar(_ m: String) { mensaje = m; mostrarMensaje = true }
}
