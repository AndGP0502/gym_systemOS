//
//  PagosView.swift
//  gym_systemOS
//
//  Módulo Pagos: tarjetas resumen + lista con color-coding (pagado/parcial/
//  deuda/vencido) + registro de pagos e historial.
//

import SwiftUI

struct PagosView: View {
    @Environment(\.appDatabase) private var db
    @StateObject private var vm = PagosViewModel()
    @State private var pagar: SuscripcionDetalle?
    @State private var cambiarPlan: SuscripcionDetalle?
    @State private var crearRapida = false
    @State private var compartir: IdentifiableURL?
    @State private var aEliminar: SuscripcionDetalle?

    private let cols = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: cols, spacing: 12) {
                    Tarjeta(titulo: "Total Suscripciones", valor: "\(vm.totales.total)", color: Color(hex: "3b5f86"))
                    Tarjeta(titulo: "Pagadas", valor: "\(vm.totales.pagadas)", color: Color(hex: "13c29a"))
                    Tarjeta(titulo: "Pendientes", valor: "\(vm.totales.pendientes)", color: Color(hex: "3d9ad6"))
                    Tarjeta(titulo: "Total Recaudado", valor: vm.totales.recaudado.comoMoneda, color: Color(hex: "6f42c1"))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Suscripciones") {
                if vm.suscripciones.isEmpty {
                    Text("No hay suscripciones registradas.").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.suscripciones) { s in
                        Button { pagar = s } label: { PagoFila(s: s) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { pagar = s } label: { Label("Registrar pago", systemImage: "dollarsign.circle") }
                                Button { cambiarPlan = s } label: { Label("Cambiar plan", systemImage: "arrow.left.arrow.right") }
                                Button { vm.resetearPago(s.id) } label: {
                                    Label("Resetear pago", systemImage: "arrow.counterclockwise")
                                }
                                Button(role: .destructive) { aEliminar = s } label: {
                                    Label("Eliminar suscripción", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { aEliminar = s } label: { Label("Eliminar", systemImage: "trash") }
                            }
                    }
                }
            }
        }
        .navigationTitle("Pagos")
        .searchable(text: $vm.busqueda, prompt: "Buscar por cédula o nombre")
        .onChange(of: vm.busqueda) { _, _ in vm.recargar() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Filtro", selection: $vm.filtro) {
                        ForEach(FiltroSuscripcion.allCases) { f in Label(f.rawValue, systemImage: f.icono).tag(f) }
                    }
                } label: {
                    Label(vm.filtro == .todas ? "Filtrar" : vm.filtro.rawValue,
                          systemImage: "line.3.horizontal.decrease.circle")
                }
                .onChange(of: vm.filtro) { _, _ in vm.aplicarFiltro() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { exportar() } label: { Label("Exportar", systemImage: "square.and.arrow.up") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { crearRapida = true } label: { Label("Suscripción rápida", systemImage: "plus") }
            }
        }
        .task { vm.setup(db: db) }
        .sheet(item: $pagar) { s in
            RegistrarPagoSheet(s: s, vm: vm)
        }
        .sheet(item: $cambiarPlan) { s in
            CambiarPlanSheet(s: s, planes: vm.planes) { nuevoId in vm.cambiarPlan(suscripcionId: s.id, nuevoPlanId: nuevoId) }
        }
        .sheet(isPresented: $crearRapida) {
            CrearRapidaSheet(clientes: vm.clientes, planes: vm.planes) { cid, mid in vm.crearRapida(clienteId: cid, membresiaId: mid) }
        }
        .sheet(item: $compartir) { item in ShareSheet(items: [item.url]) }
        .alert("Eliminar suscripción",
               isPresented: Binding(get: { aEliminar != nil }, set: { if !$0 { aEliminar = nil } })) {
            Button("Eliminar", role: .destructive) { if let s = aEliminar { vm.eliminarSuscripcion(s) }; aEliminar = nil }
            Button("Cancelar", role: .cancel) { aEliminar = nil }
        } message: { Text("¿Eliminar la suscripción de \(aEliminar?.nombre ?? "") y sus pagos?") }
        .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) { Button("OK", role: .cancel) {} }
    }

    private func exportar() {
        if let url = CSVExport.archivo(vm.csv(), nombre: "pagos.csv") { compartir = IdentifiableURL(url: url) }
    }
}

private struct CambiarPlanSheet: View {
    let s: SuscripcionDetalle
    let planes: [Membresia]
    let onGuardar: (Int64) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var planId: Int64?
    var body: some View {
        NavigationStack {
            Form {
                Section("Suscripción de \(s.nombre)") { LabeledContent("Plan actual", value: s.plan) }
                Section("Nuevo plan") {
                    Picker("Plan", selection: $planId) {
                        Text("Selecciona…").tag(Int64?.none)
                        ForEach(planes) { p in Text("\(p.nombrePlan ?? "—") · \((p.precio ?? 0).comoMoneda)").tag(Int64?.some(p.id ?? -1)) }
                    }
                }
            }
            .navigationTitle("Cambiar plan").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { if let id = planId { onGuardar(id); dismiss() } }.disabled(planId == nil)
                }
            }
        }
    }
}

private struct CrearRapidaSheet: View {
    let clientes: [Cliente]
    let planes: [Membresia]
    let onCrear: (Int64, Int64) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var clienteId: Int64?
    @State private var planId: Int64?
    var body: some View {
        NavigationStack {
            Form {
                Picker("Cliente", selection: $clienteId) {
                    Text("Selecciona…").tag(Int64?.none)
                    ForEach(clientes) { c in Text(c.nombre ?? "—").tag(Int64?.some(c.id ?? -1)) }
                }
                Picker("Plan", selection: $planId) {
                    Text("Selecciona…").tag(Int64?.none)
                    ForEach(planes) { p in Text(p.nombrePlan ?? "—").tag(Int64?.some(p.id ?? -1)) }
                }
            }
            .navigationTitle("Suscripción rápida").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") { if let c = clienteId, let p = planId { onCrear(c, p); dismiss() } }
                        .disabled(clienteId == nil || planId == nil)
                }
            }
        }
    }
}

private struct Tarjeta: View {
    let titulo: String; let valor: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.caption).foregroundStyle(.white.opacity(0.9))
            Text(valor).font(.title2).bold().foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PagoFila: View {
    let s: SuscripcionDetalle
    var body: some View {
        let estilo = EstadoPago.estilo(pagado: s.pagado, pendiente: s.pendiente, vencida: s.estaVencida)
        HStack {
            RoundedRectangle(cornerRadius: 3).fill(estilo.fondo).frame(width: 6, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.nombre).font(.headline)
                Text("\(s.plan) · vence \(s.fechaVencimiento ?? "—")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(estilo.etiqueta).font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(estilo.fondo, in: Capsule()).foregroundStyle(estilo.texto)
                Text("\(s.pagado.comoMoneda) / \(s.precioTotal.comoMoneda)").font(.caption2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Registrar pago + historial

private struct RegistrarPagoSheet: View {
    let s: SuscripcionDetalle
    @ObservedObject var vm: PagosViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var montoText = ""
    @State private var historial: [Pago] = []
    @State private var editandoPago: Pago?
    @State private var montoEdit = ""
    @State private var mostrarMontos = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Suscripción") {
                    LabeledContent("Cliente", value: s.nombre)
                    LabeledContent("Plan", value: s.plan)
                    LabeledContent("Precio", value: s.precioTotal.comoMoneda)
                    LabeledContent("Pagado", value: s.pagado.comoMoneda)
                    LabeledContent("Pendiente", value: s.pendiente.comoMoneda)
                        .foregroundStyle(s.pendiente > 0 ? .red : .green)
                    Button { mostrarMontos = true } label: {
                        Label("Editar montos (precio / pagado)", systemImage: "dollarsign.circle")
                    }
                }
                Section("Registrar pago") {
                    TextField("Monto", text: $montoText).keyboardType(.decimalPad)
                    Button("Registrar pago") {
                        let m = Double(montoText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        vm.registrar(suscripcionId: s.id, monto: m)
                        dismiss()
                    }
                    .disabled((Double(montoText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
                }
                Section("Historial de pagos") {
                    if historial.isEmpty {
                        Text("Sin pagos registrados.").foregroundStyle(.secondary)
                    } else {
                        ForEach(historial) { p in
                            HStack {
                                Text(p.fechaPago ?? "—")
                                Spacer()
                                Text((p.monto ?? 0).comoMoneda).bold()
                                Image(systemName: "pencil").font(.caption).foregroundStyle(.blue)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { editandoPago = p; montoEdit = String(p.monto ?? 0) }
                            .swipeActions {
                                Button(role: .destructive) {
                                    if let id = p.id { vm.eliminarPago(id); historial = vm.historial(s.id) }
                                } label: { Label("Eliminar", systemImage: "trash") }
                                Button {
                                    editandoPago = p; montoEdit = String(p.monto ?? 0)
                                } label: { Label("Editar", systemImage: "pencil") }.tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .onAppear { historial = vm.historial(s.id) }
            .alert("Editar pago", isPresented: Binding(get: { editandoPago != nil },
                                                       set: { if !$0 { editandoPago = nil } })) {
                TextField("Nuevo monto", text: $montoEdit).keyboardType(.decimalPad)
                Button("Guardar") {
                    if let id = editandoPago?.id {
                        vm.editarPago(id, nuevoMonto: Double(montoEdit.replacingOccurrences(of: ",", with: ".")) ?? 0)
                        historial = vm.historial(s.id)
                    }
                    editandoPago = nil
                }
                Button("Cancelar", role: .cancel) { editandoPago = nil }
            } message: { Text("Ajusta el monto de este pago. La suscripción se recalcula automáticamente.") }
            .sheet(isPresented: $mostrarMontos) {
                EditarMontosSheet(titulo: "Suscripción de \(s.nombre)", precioTotal: s.precioTotal, pagado: s.pagado) { precio, pagado in
                    vm.editarMontos(s.id, precioTotal: precio, pagado: pagado)
                    dismiss()
                }
            }
        }
    }
}
