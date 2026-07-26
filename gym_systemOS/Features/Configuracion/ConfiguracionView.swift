//
//  ConfiguracionView.swift
//  gym_systemOS
//
//  Configuración del emisor y carga del certificado .p12 (en runtime, Keychain).
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfiguracionView: View {
    @Environment(\.appDatabase) private var db
    @StateObject private var vm = ConfiguracionViewModel()
    @State private var mostrarPicker = false

    var body: some View {
        Form {
            Section("Datos del emisor") {
                campo("RUC", text: $vm.config.ruc, keyboard: .numberPad)
                campo("Razón social", text: $vm.config.razonSocial)
                campo("Nombre comercial", text: $vm.config.nombreComercial.orEmpty())
                campo("Dirección matriz", text: $vm.config.direccionMatriz.orEmpty())
                campo("Dirección sucursal", text: $vm.config.direccionSucursal.orEmpty())
            }

            Section("Punto de emisión") {
                campo("Establecimiento", text: $vm.config.codigoEstablecimiento.orEmpty(), keyboard: .numberPad)
                campo("Punto de emisión", text: $vm.config.puntoEmision.orEmpty(), keyboard: .numberPad)
                Picker("Ambiente", selection: Binding(
                    get: { vm.config.ambiente ?? 1 },
                    set: { vm.config.ambiente = $0 })) {
                    Text("Pruebas").tag(1)
                    Text("Producción").tag(2)
                }
                Stepper("Siguiente secuencial: \(vm.config.siguienteSecuencial ?? 1)",
                        value: Binding(get: { vm.config.siguienteSecuencial ?? 1 },
                                       set: { vm.config.siguienteSecuencial = $0 }), in: 1...999999999)
            }

            Section("Certificado de firma (.p12)") {
                if vm.tieneCertificado, let info = vm.certInfo {
                    LabeledContent("Sujeto", value: info.subject)
                    LabeledContent("Emisor", value: info.issuer)
                    LabeledContent("Serial", value: info.serial)
                    if let d = info.validoDesde { LabeledContent("Válido desde", value: d) }
                    if let h = info.validoHasta { LabeledContent("Válido hasta", value: h) }
                    Button("Quitar certificado", role: .destructive) { vm.quitarCertificado() }
                } else {
                    SecureField("Clave del certificado", text: $vm.clave)
                    Button {
                        mostrarPicker = true
                    } label: { Label("Seleccionar archivo .p12", systemImage: "doc.badge.plus") }
                    Text("El certificado se guarda cifrado en el Keychain del dispositivo. Nunca se incluye en la app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Configuración")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { vm.guardar() }
            }
        }
        .task { vm.setup(db: db) }
        .fileImporter(isPresented: $mostrarPicker,
                      allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data,
                                            UTType(filenameExtension: "pfx") ?? .data],
                      allowsMultipleSelection: false) { result in
            manejarImport(result)
        }
        .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) { Button("OK", role: .cancel) {} }
    }

    private func campo(_ titulo: String, text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        TextField(titulo, text: text)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
    }

    private func manejarImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                vm.cargarCertificado(data: data)
            } else {
                vm.mensaje = "No se pudo leer el archivo."; vm.mostrarMensaje = true
            }
        case .failure(let error):
            vm.mensaje = error.localizedDescription; vm.mostrarMensaje = true
        }
    }
}
