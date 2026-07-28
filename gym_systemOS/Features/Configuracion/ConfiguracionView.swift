//
//  ConfiguracionView.swift
//  gym_systemOS
//
//  Configuración del emisor y carga del certificado .p12 (en runtime, Keychain).
//

import SwiftUI
import UniformTypeIdentifiers

/// Qué archivo se está eligiendo (un solo fileImporter para evitar que dos
/// modificadores en la misma vista se anulen entre sí).
private enum TipoImportacion: Identifiable, Hashable {
    case certificado, baseDatos
    var id: Int { hashValue }
}

struct ConfiguracionView: View {
    @Environment(\.appDatabase) private var db
    @EnvironmentObject private var inbox: CertificadoInbox
    @StateObject private var vm = ConfiguracionViewModel()
    @State private var importando: TipoImportacion?

    /// Tipos aceptados al elegir el certificado: el UTI canónico de PKCS#12
    /// (`com.rsa.pkcs-12`, cubre .p12 y .pfx) + datos genéricos como respaldo,
    /// para que el archivo nunca aparezca deshabilitado en el selector.
    private static let tiposP12: [UTType] =
        [UTType("com.rsa.pkcs-12"), UTType("com.apple.pkcs12"), .data, .item].compactMap { $0 }
    @State private var pin1 = ""
    @State private var pin2 = ""
    @State private var compartir: ShareItems?
    @State private var pinConfigurado = AppSettings.pinConfigurado
    @State private var dropTargeted = false

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
                    Text("1) Trae tu .p12 (arrástralo aquí o usa «Seleccionar»).  2) Escribe su clave.  3) «Cargar certificado».")
                        .font(.caption).foregroundStyle(.secondary)
                    zonaArrastre
                    Button { importando = .certificado } label: {
                        Label(vm.p12Nombre == nil ? "…o Seleccionar archivo .p12" : "Archivo: \(vm.p12Nombre!)",
                              systemImage: vm.p12Nombre == nil ? "doc.badge.plus" : "checkmark.circle.fill")
                    }
                    SecureField("Clave del certificado", text: $vm.clave)
                    Button { vm.cargarCertificado() } label: {
                        Label("Cargar certificado", systemImage: "key.fill")
                    }
                    .disabled(vm.p12Data == nil)
                    Text("El certificado se guarda cifrado en el Keychain del dispositivo. Nunca se incluye en la app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Seguridad (PIN)") {
                Text(pinConfigurado
                     ? "Hay un PIN configurado. Protege operaciones destructivas."
                     : "Sin PIN. Puedes fijar uno para proteger operaciones destructivas.")
                    .font(.caption).foregroundStyle(.secondary)
                SecureField("Nuevo PIN", text: $pin1).keyboardType(.numberPad)
                SecureField("Repetir PIN", text: $pin2).keyboardType(.numberPad)
                Button(pinConfigurado ? "Cambiar PIN" : "Fijar PIN") {
                    guard !pin1.isEmpty, pin1 == pin2 else {
                        vm.mensaje = "Los PIN no coinciden o están vacíos."; vm.mostrarMensaje = true; return
                    }
                    AppSettings.setPIN(pin1); pin1 = ""; pin2 = ""; pinConfigurado = true
                    vm.mensaje = "PIN guardado."; vm.mostrarMensaje = true
                }
                if pinConfigurado {
                    Button("Quitar PIN", role: .destructive) {
                        AppSettings.borrarPIN(); pinConfigurado = false
                        vm.mensaje = "PIN eliminado."; vm.mostrarMensaje = true
                    }
                }
            }

            Section("Respaldo de datos") {
                Button { exportarBD() } label: { Label("Exportar base de datos (.db)", systemImage: "square.and.arrow.up") }
                Button { exportarCSV() } label: { Label("Exportar a Excel (CSV)", systemImage: "tablecells") }
                Button { importando = .baseDatos } label: { Label("Importar base de datos", systemImage: "square.and.arrow.down") }
                Text("‘Excel (CSV)’ genera clientes.csv y suscripciones.csv (se abren en Excel/Numbers). La base .db conserva todo con el mismo esquema del escritorio. Tras importar, reinicia la app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Configuración")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { vm.guardar() }
            }
        }
        .task { vm.setup(db: db); consumirInbox() }
        .onChange(of: inbox.nombre) { _, _ in consumirInbox() }
        // UN SOLO fileImporter (dos en la misma vista se anulan entre sí).
        .fileImporter(isPresented: Binding(get: { importando != nil },
                                           set: { if !$0 { importando = nil } }),
                      allowedContentTypes: importando == .baseDatos ? [.database, .data] : Self.tiposP12,
                      allowsMultipleSelection: false) { result in
            switch importando {
            case .baseDatos:   importarBD(result)
            default:           manejarImport(result)
            }
            importando = nil
        }
        .sheet(item: $compartir) { item in ShareSheet(items: item.urls) }
        .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) { Button("OK", role: .cancel) {} }
    }

    private func exportarBD() {
        do {
            let url = try db.exportarCopia()
            compartir = ShareItems(urls: [url])
        } catch {
            vm.mensaje = "No se pudo exportar: \(error.localizedDescription)"; vm.mostrarMensaje = true
        }
    }

    private func exportarCSV() {
        let cli = CSVExport.clientes(ClientesRepo(db: db).ver())
        let sus = CSVExport.suscripciones(SuscripcionesRepo(db: db).verCompletas())
        var urls: [URL] = []
        if let u = CSVExport.archivo(cli, nombre: "clientes.csv") { urls.append(u) }
        if let u = CSVExport.archivo(sus, nombre: "suscripciones.csv") { urls.append(u) }
        if !urls.isEmpty { compartir = ShareItems(urls: urls) }
    }

    private func importarBD(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                  data.starts(with: Array("SQLite format 3".utf8)) else {
                vm.mensaje = "El archivo no es una base de datos SQLite válida."; vm.mostrarMensaje = true; return
            }
            do {
                try data.write(to: AppDatabase.onDiskURL)
                vm.mensaje = "Base de datos importada. Reinicia la app para cargar los datos."; vm.mostrarMensaje = true
            } catch {
                vm.mensaje = "No se pudo importar: \(error.localizedDescription)"; vm.mostrarMensaje = true
            }
        case .failure(let error):
            vm.mensaje = error.localizedDescription; vm.mostrarMensaje = true
        }
    }

    /// Zona para arrastrar el .p12 directamente sobre la app (evita que iOS lo
    /// intercepte como perfil de certificado / abra Safari al soltarlo).
    private var zonaArrastre: some View {
        let borde: Color = dropTargeted ? .accentColor : .secondary
        let texto = vm.p12Nombre.map { "✓ \($0)" } ?? "Arrastra aquí tu archivo .p12"
        let colorTexto: Color = vm.p12Nombre == nil ? .secondary : .green
        return RoundedRectangle(cornerRadius: 10)
            .strokeBorder(borde, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            .frame(height: 64)
            .overlay {
                Label(texto, systemImage: "square.and.arrow.down")
                    .font(.callout)
                    .foregroundStyle(colorTexto)
            }
            .dropDestination(for: Data.self) { items, _ in
                guard let d = items.first, !d.isEmpty else { return false }
                vm.archivoSeleccionado(data: d, nombre: "certificado.p12")
                return true
            } isTargeted: { dropTargeted = $0 }
    }

    private func campo(_ titulo: String, text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        TextField(titulo, text: text)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
    }

    /// Toma el .p12 que el cliente compartió a la app (Compartir → gym_systemOS).
    private func consumirInbox() {
        if let recibido = inbox.consumir() {
            vm.archivoSeleccionado(data: recibido.data, nombre: recibido.nombre)
            vm.mensaje = "Certificado recibido: \(recibido.nombre). Escribe su clave y toca «Cargar certificado»."
            vm.mostrarMensaje = true
        }
    }

    private func manejarImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                vm.archivoSeleccionado(data: data, nombre: url.lastPathComponent)
            } else {
                vm.mensaje = "No se pudo leer el archivo."; vm.mostrarMensaje = true
            }
        case .failure(let error):
            vm.mensaje = error.localizedDescription; vm.mostrarMensaje = true
        }
    }
}
