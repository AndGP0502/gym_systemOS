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

    var body: some View {
        List {
            if vm.clientes.isEmpty {
                ContentUnavailableView("Sin clientes",
                    systemImage: "person.2",
                    description: Text("Agrega tu primer cliente con el botón +."))
            } else {
                ForEach(vm.clientes) { c in
                    Button { editando = c } label: { fila(c) }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { aEliminar = c } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { fichaDe = c } label: { Label("Ficha", systemImage: "doc.text.image") }
                                .tint(.indigo)
                        }
                        .contextMenu {
                            Button { fichaDe = c } label: { Label("Ver ficha", systemImage: "doc.text.image") }
                            Button { enviarWhatsApp(c) } label: { Label("Recordatorio WhatsApp", systemImage: "message") }
                            Button { enviarCorreo(c) } label: { Label("Enviar correo", systemImage: "envelope") }
                            Button { editando = c } label: { Label("Editar", systemImage: "pencil") }
                            Button(role: .destructive) { aEliminar = c } label: { Label("Eliminar", systemImage: "trash") }
                        }
                }
            }
        }
        .navigationTitle("Clientes")
        .searchable(text: $vm.busqueda, prompt: "Buscar por cédula o nombre")
        .onChange(of: vm.busqueda) { _, _ in vm.recargar() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarFormNuevo = true } label: {
                    Label("Nuevo cliente", systemImage: "plus")
                }
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

    private func fila(_ c: Cliente) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "person.circle.fill")
                .font(.title)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.nombre ?? "—").font(.headline)
                HStack(spacing: 10) {
                    Label(c.cedula ?? "—", systemImage: "number")
                    Label(c.telefono ?? "—", systemImage: "phone")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
                    TextField("Nombre completo", text: $nombre)
                    TextField("Cédula", text: $cedula)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Teléfono", text: $telefono)
                        .keyboardType(.phonePad)
                    TextField("Correo (opcional)", text: $correo)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
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
