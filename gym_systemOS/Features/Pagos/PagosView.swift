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
                    }
                }
            }
        }
        .navigationTitle("Pagos")
        .searchable(text: $vm.busqueda, prompt: "Buscar por cédula o nombre")
        .onChange(of: vm.busqueda) { _, _ in vm.recargar() }
        .task { vm.setup(db: db) }
        .sheet(item: $pagar) { s in
            RegistrarPagoSheet(s: s, vm: vm)
        }
        .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) { Button("OK", role: .cancel) {} }
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Suscripción") {
                    LabeledContent("Cliente", value: s.nombre)
                    LabeledContent("Plan", value: s.plan)
                    LabeledContent("Precio", value: s.precioTotal.comoMoneda)
                    LabeledContent("Pagado", value: s.pagado.comoMoneda)
                    LabeledContent("Pendiente", value: s.pendiente.comoMoneda)
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
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    if let id = p.id { vm.eliminarPago(id); historial = vm.historial(s.id) }
                                } label: { Label("Eliminar", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .onAppear { historial = vm.historial(s.id) }
        }
    }
}
