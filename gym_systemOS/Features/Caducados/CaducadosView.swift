//
//  CaducadosView.swift
//  gym_systemOS
//
//  Módulo Clientes Caducados: filtros por mes/año de vencimiento + color-coding
//  por antigüedad (reciente ≤7 / vencido 8–30 / antiguo >30 días).
//

import SwiftUI

struct CaducadosView: View {
    @Environment(\.appDatabase) private var db
    @StateObject private var vm = CaducadosViewModel()

    private let meses = ["Todos", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                         "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]

    var body: some View {
        VStack(spacing: 0) {
            filtros
            let datos = vm.filtrados
            List {
                if datos.isEmpty {
                    ContentUnavailableView("Sin clientes caducados",
                        systemImage: "checkmark.seal",
                        description: Text("No hay membresías vencidas con estos filtros."))
                } else {
                    ForEach(datos) { s in CaducadoFila(s: s) }
                }
            }
        }
        .navigationTitle("Clientes Caducados")
        .searchable(text: $vm.busqueda, prompt: "Buscar por cédula o nombre")
        .task { vm.setup(db: db) }
        .safeAreaInset(edge: .bottom) {
            Text("Mostrando \(vm.filtrados.count) de \(vm.todos.count) clientes caducados")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(8)
                .background(.bar)
        }
    }

    private var filtros: some View {
        HStack {
            Picker("Mes venc.", selection: $vm.mes) {
                ForEach(0..<meses.count, id: \.self) { i in Text(meses[i]).tag(i) }
            }
            Picker("Año", selection: $vm.anio) {
                Text("Todos").tag(0)
                ForEach(vm.aniosDisponibles, id: \.self) { a in Text(String(a)).tag(a) }
            }
            Spacer()
            Button {
                vm.mes = 0; vm.anio = 0; vm.busqueda = ""
            } label: { Label("Limpiar", systemImage: "xmark.circle") }
        }
        .padding(.horizontal).padding(.vertical, 8)
    }
}

private struct CaducadoFila: View {
    let s: SuscripcionDetalle
    var body: some View {
        let estilo = EstadoCaducado.estilo(diasVencido: s.diasVencido)
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(estilo.fondo).frame(width: 6, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.nombre).font(.headline)
                HStack(spacing: 8) {
                    Label(s.cedula.isEmpty ? "—" : s.cedula, systemImage: "number")
                    Label(s.telefono.isEmpty ? "—" : s.telefono, systemImage: "phone")
                }.font(.caption).foregroundStyle(.secondary)
                Text("\(s.plan) · venció \(s.fechaVencimiento ?? "—")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let d = s.diasVencido {
                    Text("\(d) días").font(.caption2).bold()
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(estilo.fondo, in: Capsule()).foregroundStyle(estilo.texto)
                }
                if s.pendiente > 0 {
                    Text("Pend: \(s.pendiente.comoMoneda)").font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
