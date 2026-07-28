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
    @Published var p12Data: Data?          // archivo .p12 ya seleccionado (pendiente de cargar)
    @Published var p12Nombre: String?      // nombre del archivo seleccionado
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

    /// Guarda el archivo .p12 elegido (aún sin importar; falta la clave).
    func archivoSeleccionado(data: Data, nombre: String) {
        p12Data = data
        p12Nombre = nombre
    }

    /// Importa el .p12 seleccionado con la clave y lo guarda en Keychain (runtime).
    func cargarCertificado() {
        guard let data = p12Data else {
            return notificar("Primero selecciona el archivo .p12.")
        }
        do {
            let info = try CertificateStore.importAndSave(p12: data, password: clave)
            certInfo = info
            tieneCertificado = true
            config.rutaCertificado = "keychain"   // marcador; el .p12 vive en Keychain
            clave = ""; p12Data = nil; p12Nombre = nil
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
