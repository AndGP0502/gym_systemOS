//
//  PagosViewModel.swift
//  gym_systemOS
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PagosViewModel: ObservableObject {
    @Published var suscripciones: [SuscripcionDetalle] = []
    @Published var busqueda: String = ""
    @Published var totales = PagosRepo.Totales()
    @Published var mensaje: String?
    @Published var mostrarMensaje = false

    private var pagosRepo: PagosRepo?
    private var susRepo: SuscripcionesRepo?

    func setup(db: AppDatabase) {
        guard pagosRepo == nil else { return }
        pagosRepo = PagosRepo(db: db)
        susRepo = SuscripcionesRepo(db: db)
        recargar()
    }

    func recargar() {
        guard let pagosRepo, let susRepo else { return }
        suscripciones = busqueda.isEmpty ? susRepo.verCompletas() : susRepo.buscar(busqueda)
        totales = pagosRepo.totales()
    }

    func registrar(suscripcionId: Int64, monto: Double) {
        guard let pagosRepo else { return }
        let r = pagosRepo.registrar(suscripcionId: suscripcionId, monto: monto)
        notificar(r.mensaje); if r.ok { recargar() }
    }

    func historial(_ suscripcionId: Int64) -> [Pago] {
        pagosRepo?.historial(suscripcionId: suscripcionId) ?? []
    }

    func eliminarPago(_ id: Int64) {
        pagosRepo?.eliminarPago(id: id); recargar()
    }

    private func notificar(_ m: String) { mensaje = m; mostrarMensaje = true }
}
