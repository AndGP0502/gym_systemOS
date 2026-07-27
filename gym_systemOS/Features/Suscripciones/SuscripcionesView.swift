//
//  SuscripcionesView.swift
//  gym_systemOS
//
//  Módulo Suscripciones: listado con estado, alta (asignar plan), renovación,
//  búsqueda por cédula/nombre y gestión de planes (membresías).
//

import SwiftUI

struct SuscripcionesView: View {
    @Environment(\.appDatabase) private var db
    @StateObject private var vm = SuscripcionesViewModel()

    @State private var mostrarNueva = false
    @State private var mostrarPlanes = false
    @State private var renovar: SuscripcionDetalle?
    @State private var editarFechas: SuscripcionDetalle?
    @State private var aEliminar: SuscripcionDetalle?

    var body: some View {
        List {
            if vm.suscripciones.isEmpty {
                ContentUnavailableView("Sin suscripciones",
                    systemImage: "creditcard",
                    description: Text("Asigna un plan a un cliente con el botón +."))
            } else {
                ForEach(vm.suscripciones) { s in
                    SuscripcionFila(s: s)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { aEliminar = s } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            Button { renovar = s } label: {
                                Label("Renovar", systemImage: "arrow.clockwise")
                            }.tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            Button { editarFechas = s } label: {
                                Label("Fechas", systemImage: "calendar")
                            }.tint(.indigo)
                        }
                }
            }
        }
        .navigationTitle("Suscripciones")
        .searchable(text: $vm.busqueda, prompt: "Buscar por cédula o nombre")
        .onChange(of: vm.busqueda) { _, _ in vm.recargar() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNueva = true } label: { Label("Nueva", systemImage: "plus") }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { mostrarPlanes = true } label: { Label("Planes", systemImage: "list.bullet.rectangle") }
            }
        }
        .task { vm.setup(db: db) }
        .sheet(isPresented: $mostrarNueva) {
            NuevaSuscripcionSheet(clientes: vm.clientes, planes: vm.planes) { cid, mid, pagado in
                vm.asignar(clienteId: cid, membresiaId: mid, pagado: pagado)
            }
        }
        .sheet(isPresented: $mostrarPlanes) {
            PlanesView(vm: vm)
        }
        .sheet(item: $renovar) { s in
            RenovarSheet(nombre: s.nombre) { dias, monto in
                vm.renovar(clienteId: s.clienteId, dias: dias, monto: monto)
            }
        }
        .sheet(item: $editarFechas) { s in
            EditarFechasSheet(s: s) { inicio, venc in
                vm.editarFechas(s, inicio: inicio, vencimiento: venc)
            }
        }
        .alert("Eliminar suscripción",
               isPresented: Binding(get: { aEliminar != nil }, set: { if !$0 { aEliminar = nil } })) {
            Button("Eliminar", role: .destructive) { if let s = aEliminar { vm.eliminar(s) }; aEliminar = nil }
            Button("Cancelar", role: .cancel) { aEliminar = nil }
        } message: { Text("¿Eliminar la suscripción de \(aEliminar?.nombre ?? "")?") }
        .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) { Button("OK", role: .cancel) {} }
    }
}

// MARK: - Fila

private struct SuscripcionFila: View {
    let s: SuscripcionDetalle
    var body: some View {
        let estilo = EstadoPago.estilo(pagado: s.pagado, pendiente: s.pendiente, vencida: s.estaVencida)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(s.nombre).font(.headline)
                Text(s.plan).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label(s.fechaVencimiento ?? "—", systemImage: "calendar")
                    Text(estadoVigencia).fontWeight(.semibold)
                }
                .font(.caption)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(estilo.etiqueta)
                    .font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(estilo.fondo, in: Capsule())
                    .foregroundStyle(estilo.texto)
                Text("Pag: \(s.pagado.comoMoneda)").font(.caption2)
                if s.pendiente > 0 {
                    Text("Pend: \(s.pendiente.comoMoneda)").font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var estadoVigencia: String {
        guard let d = s.diasRestantes else { return "" }
        return d < 0 ? "VENCIDO" : "\(d) días"
    }
}

// MARK: - Nueva suscripción

private struct NuevaSuscripcionSheet: View {
    let clientes: [Cliente]
    let planes: [Membresia]
    let onGuardar: (Int64, Int64, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var clienteId: Int64?
    @State private var planId: Int64?
    @State private var pagadoText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Cliente") {
                    Picker("Cliente", selection: $clienteId) {
                        Text("Selecciona…").tag(Int64?.none)
                        ForEach(clientes) { c in
                            Text(c.nombre ?? "—").tag(Int64?.some(c.id ?? -1))
                        }
                    }
                }
                Section("Plan") {
                    Picker("Plan", selection: $planId) {
                        Text("Selecciona…").tag(Int64?.none)
                        ForEach(planes) { p in
                            Text("\(p.nombrePlan ?? "—") · \((p.precio ?? 0).comoMoneda)").tag(Int64?.some(p.id ?? -1))
                        }
                    }
                }
                Section("Pago inicial (opcional)") {
                    TextField("Monto pagado", text: $pagadoText).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Nueva suscripción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Asignar") {
                        if let cid = clienteId, let pid = planId {
                            onGuardar(cid, pid, Double(pagadoText.replacingOccurrences(of: ",", with: ".")) ?? 0)
                            dismiss()
                        }
                    }.disabled(clienteId == nil || planId == nil)
                }
            }
        }
    }
}

// MARK: - Renovar

private struct EditarFechasSheet: View {
    let s: SuscripcionDetalle
    let onGuardar: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inicio: Date
    @State private var vencimiento: Date

    init(s: SuscripcionDetalle, onGuardar: @escaping (String, String) -> Void) {
        self.s = s
        self.onGuardar = onGuardar
        _inicio = State(initialValue: Fechas.parse(s.fechaInicio) ?? Date())
        _vencimiento = State(initialValue: Fechas.parse(s.fechaVencimiento) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fechas de \(s.nombre)") {
                    DatePicker("Inicio", selection: $inicio, displayedComponents: .date)
                    DatePicker("Vencimiento", selection: $vencimiento, displayedComponents: .date)
                }
            }
            .navigationTitle("Editar fechas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onGuardar(Fechas.iso.string(from: inicio), Fechas.iso.string(from: vencimiento))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RenovarSheet: View {
    let nombre: String
    let onRenovar: (Int, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var diasText = "30"
    @State private var montoText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Renovar suscripción de \(nombre)") {
                    TextField("Días a extender", text: $diasText).keyboardType(.numberPad)
                    TextField("Monto del pago (opcional)", text: $montoText).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Renovar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Renovar") {
                        onRenovar(Int(diasText) ?? 30,
                                  Double(montoText.replacingOccurrences(of: ",", with: ".")) ?? 0)
                        dismiss()
                    }
                }
            }
        }
    }
}
