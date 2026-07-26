//
//  CaducadosViewModel.swift
//  gym_systemOS
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class CaducadosViewModel: ObservableObject {
    @Published var todos: [SuscripcionDetalle] = []
    @Published var busqueda = ""
    @Published var mes = 0          // 0 = Todos
    @Published var anio = 0         // 0 = Todos

    private var repo: SuscripcionesRepo?

    func setup(db: AppDatabase) {
        guard repo == nil else { return }
        repo = SuscripcionesRepo(db: db)
        recargar()
    }

    func recargar() { todos = repo?.caducadasDetalle() ?? [] }

    /// Filtro en memoria (texto + mes/año de vencimiento), igual que el escritorio.
    var filtrados: [SuscripcionDetalle] {
        let t = busqueda.trimmingCharacters(in: .whitespaces).lowercased()
        return todos.filter { s in
            if !t.isEmpty,
               !(s.nombre.lowercased().contains(t) || s.cedula.lowercased().contains(t)) {
                return false
            }
            let v = s.fechaVencimiento ?? ""
            if anio != 0, !v.hasPrefix(String(anio)) { return false }
            if mes != 0 {
                let mm = String(format: "%02d", mes)
                if v.count >= 7, String(Array(v)[5...6]) != mm { return false }
            }
            return true
        }
    }

    /// Años presentes en los datos (para el picker).
    var aniosDisponibles: [Int] {
        let s = Set(todos.compactMap { $0.fechaVencimiento?.prefix(4) }.compactMap { Int($0) })
        return s.sorted(by: >)
    }
}
