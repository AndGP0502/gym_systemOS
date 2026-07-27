//
//  ClientesView.swift
//  gym_systemOS
//
//  Módulo Clientes: alta/edición/baja + búsqueda por cédula o nombre.
//

import SwiftUI

struct ClientesView: View {
    @Environment(\.appDatabase) private var db
    @Environment(\.openURL) private var openURL
    @StateObject private var vm = ClientesViewModel()

    @State private var editando: Cliente?
    @State private var mostrarFormNuevo = false
    @State private var aEliminar: Cliente?
    @State private var fichaDe: Cliente?
    @State private var compartir: IdentifiableURL?

    private let cols = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: cols, spacing: 10) {
                    IndicadorCard(titulo: "Total", valor: "\(vm.resumen.total)", color: Color(hex: "3b5f86"), icono: "person.3.fill")
                    IndicadorCard(titulo: "Activos", valor: "\(vm.resumen.activos)", color: Color(hex: "13c29a"), icono: "checkmark.seal.fill")
                    IndicadorCard(titulo: "Vencidos", valor: "\(vm.resumen.vencidos)", color: Color(hex: "d64545"), icono: "xmark.seal.fill")
                    IndicadorCard(titulo: "Con deuda", valor: "\(vm.resumen.conDeuda)", color: Color(hex: "e08a1e"), icono: "exclamationmark.triangle.fill")
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }

            if vm.clientes.isEmpty {
                ContentUnavailableView("Sin clientes",
                    systemImage: "person.2",
                    description: Text("No hay clientes para el filtro actual."))
            } else {
                ForEach(vm.clientes) { c in
                    fila(c)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { aEliminar = c } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            Button { enviarCorreo(c) } label: { Label("Correo", systemImage: "envelope") }
                                .tint(.teal)
                        }
                }
            }
        }
        .navigationTitle("Clientes")
        .searchable(text: $vm.busqueda, prompt: "Buscar por cédula o nombre")
        .onChange(of: vm.busqueda) { _, _ in vm.recargar() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Filtro", selection: $vm.filtro) {
                        ForEach(FiltroCliente.allCases) { f in Label(f.rawValue, systemImage: f.icono).tag(f) }
                    }
                } label: {
                    Label(vm.filtro == .todos ? "Filtrar" : vm.filtro.rawValue,
                          systemImage: "line.3.horizontal.decrease.circle")
                }
                .onChange(of: vm.filtro) { _, _ in vm.recargar() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { exportar() } label: { Label("Exportar", systemImage: "square.and.arrow.up") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarFormNuevo = true } label: { Label("Nuevo cliente", systemImage: "plus") }
            }
        }
        .task { vm.setup(db: db) }
        .sheet(isPresented: $mostrarFormNuevo) {
            ClienteFormView(titulo: "Nuevo cliente") { nombre, cedula, tel, correo in
                vm.agregar(nombre: nombre, cedula: cedula, telefono: tel, correo: correo)
            }
        }
        .sheet(item: $editando) { c in
            ClienteFormView(titulo: "Editar cliente", cliente: c) { nombre, cedula, tel, correo in
                vm.editar(c, nombre: nombre, cedula: cedula, telefono: tel, correo: correo)
            }
        }
        .alert("Eliminar cliente",
               isPresented: Binding(get: { aEliminar != nil },
                                    set: { if !$0 { aEliminar = nil } })) {
            Button("Eliminar", role: .destructive) {
                if let c = aEliminar { vm.eliminar(c) }
                aEliminar = nil
            }
            Button("Cancelar", role: .cancel) { aEliminar = nil }
        } message: {
            Text("¿Eliminar a \(aEliminar?.nombre ?? "")? Esta acción no se puede deshacer.")
        }
        .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) {
            Button("OK", role: .cancel) {}
        }
        .sheet(item: $fichaDe) { c in FichaView(cliente: c) }
        .sheet(item: $compartir) { item in ShareSheet(items: [item.url]) }
    }

    private func enviarWhatsApp(_ c: Cliente) {
        let msg = Recordatorios.mensaje(nombre: c.nombre ?? "", diasRestantes: vm.diasRestantes(c))
        if let url = Recordatorios.whatsappURL(telefono: c.telefono ?? "", mensaje: msg) { openURL(url) }
    }

    private func enviarCorreo(_ c: Cliente) {
        let msg = Recordatorios.mensaje(nombre: c.nombre ?? "", diasRestantes: vm.diasRestantes(c))
        if let url = Recordatorios.correoURL(email: c.correo ?? "", asunto: "Recordatorio de membresía", cuerpo: msg) {
            openURL(url)
        }
    }

    private func generarPDF(_ c: Cliente) {
        guard let data = vm.fichaPDF(c) else { return }
        let nombre = "Cliente_\((c.nombre ?? "cliente").replacingOccurrences(of: " ", with: "_")).pdf"
        if let url = TempFiles.escribir(data, nombre: nombre) { compartir = IdentifiableURL(url: url) }
    }

    private func exportar() {
        if let url = CSVExport.archivo(vm.csv(), nombre: "clientes.csv") { compartir = IdentifiableURL(url: url) }
    }

    private func fila(_ c: Cliente) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill").font(.title).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.nombre ?? "—").font(.headline)
                HStack(spacing: 10) {
                    Label(c.cedula ?? "—", systemImage: "number")
                    Label(c.telefono ?? "—", systemImage: "phone")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            // Acciones visibles por cliente
            HStack(spacing: 6) {
                accion("Ficha", "doc.text.image", .indigo) { fichaDe = c }
                accion("WhatsApp", "message.fill", .green) { enviarWhatsApp(c) }
                accion("PDF", "arrow.down.doc.fill", .orange) { generarPDF(c) }
                accion("Editar", "pencil", .blue) { editando = c }
                accion("Eliminar", "trash.fill", .red) { aEliminar = c }
            }
        }
        .padding(.vertical, 4)
    }

    private func accion(_ titulo: String, _ icono: String, _ color: Color,
                        _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            VStack(spacing: 2) {
                Image(systemName: icono).font(.title3)
                Text(titulo).font(.caption2)
            }
            .frame(width: 52, height: 44)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Formulario

private struct ClienteFormView: View {
    let titulo: String
    var cliente: Cliente?
    /// Devuelve true si la operación tuvo éxito (para cerrar la hoja).
    let onGuardar: (String, String, String, String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var nombre: String
    @State private var cedula: String
    @State private var telefono: String
    @State private var correo: String

    init(titulo: String, cliente: Cliente? = nil,
         onGuardar: @escaping (String, String, String, String) -> Bool) {
        self.titulo = titulo
        self.cliente = cliente
        self.onGuardar = onGuardar
        _nombre = State(initialValue: cliente?.nombre ?? "")
        _cedula = State(initialValue: cliente?.cedula ?? "")
        _telefono = State(initialValue: cliente?.telefono ?? "")
        _correo = State(initialValue: cliente?.correo ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del cliente") {
                    CampoTexto(titulo: "Nombre completo", ejemplo: "Ej: Juan Pérez", texto: $nombre,
                               autocap: .words)
                    CampoTexto(titulo: "Cédula", ejemplo: "Ej: 0102030405", texto: $cedula,
                               keyboard: .numbersAndPunctuation)
                    CampoTexto(titulo: "Teléfono", ejemplo: "Ej: 0991234567", texto: $telefono,
                               keyboard: .phonePad)
                    CampoTexto(titulo: "Correo (opcional)", ejemplo: "Ej: juan@correo.com", texto: $correo,
                               keyboard: .emailAddress, autocap: .never)
                }
            }
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if onGuardar(nombre, cedula, telefono, correo) { dismiss() }
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
