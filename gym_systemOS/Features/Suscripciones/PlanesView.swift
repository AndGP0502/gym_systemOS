//
//  PlanesView.swift
//  gym_systemOS
//
//  Gestión de planes (membresías): CRUD. Se abre como hoja desde Suscripciones.
//

import SwiftUI

struct PlanesView: View {
    @ObservedObject var vm: SuscripcionesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editando: Membresia?
    @State private var mostrarNuevo = false

    var body: some View {
        NavigationStack {
            List {
                if vm.planes.isEmpty {
                    ContentUnavailableView("Sin planes", systemImage: "list.bullet.rectangle",
                        description: Text("Crea tu primer plan con el botón +."))
                } else {
                    ForEach(vm.planes) { p in
                        Button { editando = p } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.nombrePlan ?? "—").font(.headline)
                                    Text("\(p.duracionDias ?? 0) días").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text((p.precio ?? 0).comoMoneda).font(.headline).foregroundStyle(.tint)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) { vm.eliminarPlan(p) } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Planes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button { mostrarNuevo = true } label: { Label("Nuevo", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $mostrarNuevo) {
                PlanFormView(titulo: "Nuevo plan") { nombre, precio, dias in
                    vm.crearPlan(nombre: nombre, precio: precio, dias: dias)
                }
            }
            .sheet(item: $editando) { p in
                PlanFormView(titulo: "Editar plan", plan: p) { nombre, precio, dias in
                    vm.editarPlan(p, nombre: nombre, precio: precio, dias: dias)
                }
            }
        }
    }
}

private struct PlanFormView: View {
    let titulo: String
    var plan: Membresia?
    let onGuardar: (String, Double, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nombre: String
    @State private var precioText: String
    @State private var diasText: String

    init(titulo: String, plan: Membresia? = nil, onGuardar: @escaping (String, Double, Int) -> Void) {
        self.titulo = titulo
        self.plan = plan
        self.onGuardar = onGuardar
        _nombre = State(initialValue: plan?.nombrePlan ?? "")
        _precioText = State(initialValue: plan.map { String($0.precio ?? 0) } ?? "")
        _diasText = State(initialValue: plan.map { String($0.duracionDias ?? 0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre del plan", text: $nombre)
                TextField("Precio", text: $precioText).keyboardType(.decimalPad)
                TextField("Duración (días)", text: $diasText).keyboardType(.numberPad)
            }
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onGuardar(nombre,
                                  Double(precioText.replacingOccurrences(of: ",", with: ".")) ?? 0,
                                  Int(diasText) ?? 0)
                        dismiss()
                    }.disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
