//
//  DashboardView.swift
//  gym_systemOS
//
//  Módulo Inicio: métricas del gimnasio + gráficas (ingresos y nuevos clientes
//  por mes). Adaptación de ventana_princi.actualizar_dashboard + graficas.py.
//

import SwiftUI
import Charts
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var resumen = DashboardResumen()
    private var repo: DashboardRepo?
    func setup(db: AppDatabase) { repo = DashboardRepo(db: db); recargar() }
    func recargar() { if let repo { resumen = repo.resumen() } }
}

struct DashboardView: View {
    @Environment(\.appDatabase) private var db
    @StateObject private var vm = DashboardViewModel()

    private let cols = [GridItem(.adaptive(minimum: 200), spacing: 14)]
    private static let meses = ["", "Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: cols, spacing: 14) {
                    Metrica(titulo: "Clientes", valor: "\(vm.resumen.clientes)", icono: "person.2.fill", color: Color(hex: "3b5f86"))
                    Metrica(titulo: "Activos", valor: "\(vm.resumen.activos)", icono: "checkmark.seal.fill", color: Color(hex: "13c29a"))
                    Metrica(titulo: "Vencidos", valor: "\(vm.resumen.vencidos)", icono: "exclamationmark.triangle.fill", color: Color(hex: "d64545"))
                    Metrica(titulo: "Planes", valor: "\(vm.resumen.planes)", icono: "list.bullet.rectangle.fill", color: Color(hex: "6f42c1"))
                    Metrica(titulo: "Ingresos del mes", valor: vm.resumen.ingresosMes.comoMoneda, icono: "calendar", color: Color(hex: "3d9ad6"))
                    Metrica(titulo: "Recaudado total", valor: vm.resumen.recaudadoTotal.comoMoneda, icono: "dollarsign.circle.fill", color: Color(hex: "13835f"))
                }

                grafico(titulo: "Ingresos por mes (año actual)", datos: vm.resumen.ingresosPorMes,
                        color: Color(hex: "13c29a"), moneda: true)
                grafico(titulo: "Nuevos clientes por mes", datos: vm.resumen.clientesPorMes,
                        color: Color(hex: "3d9ad6"), moneda: false)
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Inicio")
        .task { vm.setup(db: db) }
        .refreshable { vm.recargar() }
    }

    @ViewBuilder
    private func grafico(titulo: String, datos: [PuntoMes], color: Color, moneda: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo).font(.headline)
            if datos.isEmpty {
                Text("Sin datos este año.").font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(datos) { p in
                    BarMark(x: .value("Mes", Self.meses[Int(p.mes) ?? 0]),
                            y: .value("Valor", p.valor))
                    .foregroundStyle(color.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 220)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct Metrica: View {
    let titulo: String; let valor: String; let icono: String; let color: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icono).font(.title2).foregroundStyle(.white)
                .frame(width: 46, height: 46).background(color, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(valor).font(.title3).bold()
                Text(titulo).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
