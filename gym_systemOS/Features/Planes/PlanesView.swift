//
//  PlanesView.swift
//  gym_systemOS
//
//  Módulo Planes (membresías) como sección propia en la barra lateral:
//  aumentar (crear), editar y quitar planes disponibles para los clientes.
//

import SwiftUI
import Combine

@MainActor
final class PlanesViewModel: ObservableObject {
    @Published var planes: [Membresia] = []
    @Published var mensaje: String?
    @Published var mostrarMensaje = false
    private var repo: MembresiasRepo?

    func setup(db: AppDatabase) { guard repo == nil else { return }; repo = MembresiasRepo(db: db); recargar() }
    func recargar() { planes = repo?.ver() ?? [] }

    func crear(nombre: String, precio: Double, dias: Int) {
        let r = repo?.crear(nombrePlan: nombre, precio: precio, duracionDias: dias)
        notificar(r?.mensaje ?? ""); if r?.ok == true { recargar() }
    }
    func editar(_ m: Membresia, nombre: String, precio: Double, dias: Int) {
        guard let id = m.id else { return }
        let r = repo?.editar(id: id, nombrePlan: nombre, precio: precio, duracionDias: dias)
        notificar(r?.mensaje ?? ""); if r?.ok == true { recargar() }
    }
    func eliminar(_ m: Membresia) { if let id = m.id { repo?.eliminar(id: id); recargar() } }

    private func notificar(_ m: String) { mensaje = m; mostrarMensaje = true }
}

struct PlanesView: View {
    @Environment(\.appDatabase) private var db
    @StateObject private var vm = PlanesViewModel()
    @State private var editando: Membresia?
    @State private var mostrarNuevo = false

    var body: some View {
        List {
            if vm.planes.isEmpty {
                ContentUnavailableView("Sin planes", systemImage: "list.bullet.rectangle",
                    description: Text("Crea el primer plan con el botón +."))
            } else {
                ForEach(vm.planes) { p in
                    Button { editando = p } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.nombrePlan ?? "—").font(.headline)
                                Text("\(p.duracionDias ?? 0) días").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text((p.precio ?? 0).comoMoneda).font(.title3).bold().foregroundStyle(.tint)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { vm.eliminar(p) } label: { Label("Quitar", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("Planes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNuevo = true } label: { Label("Nuevo plan", systemImage: "plus") }
            }
        }
        .task { vm.setup(db: db) }
        .sheet(isPresented: $mostrarNuevo) {
            PlanForm(titulo: "Nuevo plan") { n, p, d in vm.crear(nombre: n, precio: p, dias: d) }
        }
        .sheet(item: $editando) { m in
            PlanForm(titulo: "Editar plan", plan: m) { n, p, d in vm.editar(m, nombre: n, precio: p, dias: d) }
        }
        .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) { Button("OK", role: .cancel) {} }
    }
}

private struct PlanForm: View {
    let titulo: String
    var plan: Membresia?
    let onGuardar: (String, Double, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var nombre: String
    @State private var precio: String
    @State private var dias: String

    init(titulo: String, plan: Membresia? = nil, onGuardar: @escaping (String, Double, Int) -> Void) {
        self.titulo = titulo; self.plan = plan; self.onGuardar = onGuardar
        _nombre = State(initialValue: plan?.nombrePlan ?? "")
        _precio = State(initialValue: plan.map { String($0.precio ?? 0) } ?? "")
        _dias = State(initialValue: plan.map { String($0.duracionDias ?? 0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                CampoTexto(titulo: "Nombre del plan", ejemplo: "Ej: Mensual", texto: $nombre)
                CampoNumero(titulo: "Precio ($)", ejemplo: "30", texto: $precio)
                CampoNumero(titulo: "Duración (días)", ejemplo: "30", texto: $dias)
            }
            .navigationTitle(titulo).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onGuardar(nombre, Double(precio.replacingOccurrences(of: ",", with: ".")) ?? 0, Int(dias) ?? 0)
                        dismiss()
                    }.disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
