//
//  AsistenciaView.swift
//  gym_systemOS
//
//  Módulo Asistencia: registro de entrada por cédula con evaluación de la
//  membresía (ACTIVO / POR VENCER / VENCIDO / SIN MEMBRESÍA) + historial.
//  Port de ui/asistencia_ui.py.
//

import SwiftUI
import Combine

@MainActor
final class AsistenciaViewModel: ObservableObject {
    @Published var cedula = ""
    @Published var ultimo: ResultadoAsistencia?
    @Published var historial: [Asistencia] = []
    private var repo: AsistenciaRepo?

    func setup(db: AppDatabase) { guard repo == nil else { return }; repo = AsistenciaRepo(db: db); recargar() }
    func recargar() { historial = repo?.historial() ?? [] }

    func registrar() {
        guard let repo, !cedula.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        ultimo = repo.registrar(cedula: cedula)
        cedula = ""
        recargar()
    }
}

struct AsistenciaView: View {
    @Environment(\.appDatabase) private var db
    @StateObject private var vm = AsistenciaViewModel()
    @FocusState private var focoCedula: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Zona de check-in
            VStack(spacing: 14) {
                HStack {
                    TextField("Cédula del cliente", text: $vm.cedula)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.title3)
                        .focused($focoCedula)
                        .onSubmit { vm.registrar() }
                    Button {
                        vm.registrar(); focoCedula = true
                    } label: {
                        Label("Registrar", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.cedula.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let r = vm.ultimo {
                    ResultadoCard(r: r)
                }
            }
            .padding()
            .frame(maxWidth: 700)

            Divider()

            // Historial
            List {
                Section("Historial de asistencias") {
                    if vm.historial.isEmpty {
                        Text("Sin asistencias registradas.").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.historial) { a in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.nombre ?? "—").font(.subheadline).bold()
                                    Text("\(a.cedula ?? "") · \(a.fecha ?? "") \(a.hora ?? "")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                EstadoBadge(estado: a.estado ?? "")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Asistencia")
        .task { vm.setup(db: db); focoCedula = true }
    }
}

private struct ResultadoCard: View {
    let r: ResultadoAsistencia
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if r.ok {
                HStack {
                    Text(r.nombre).font(.title2).bold()
                    Spacer()
                    EstadoBadge(estado: r.estado)
                }
                Text("Plan: \(r.plan) · Vence: \(r.vencimiento)").font(.callout).foregroundStyle(.secondary)
                Text(r.alerta).font(.callout)
                Text("Registrado \(r.fecha) \(r.hora)").font(.caption).foregroundStyle(.tertiary)
            } else {
                Label(r.error ?? "Error", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.4)))
    }
    private var color: Color {
        switch r.estado {
        case "ACTIVO": return .green
        case "POR VENCER": return .orange
        case "VENCIDO": return .red
        default: return .gray
        }
    }
}

private struct EstadoBadge: View {
    let estado: String
    var body: some View {
        Text(estado).font(.caption).bold()
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule()).foregroundStyle(color)
    }
    private var color: Color {
        switch estado {
        case "ACTIVO": return .green
        case "POR VENCER": return .orange
        case "VENCIDO": return .red
        default: return .gray
        }
    }
}
