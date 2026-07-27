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
    @Published var filtro: FiltroSuscripcion = .todas
    @Published var totales = PagosRepo.Totales()
    @Published var clientes: [Cliente] = []
    @Published var planes: [Membresia] = []
    @Published var mensaje: String?
    @Published var mostrarMensaje = false

    private var base: [SuscripcionDetalle] = []

    private var pagosRepo: PagosRepo?
    private var susRepo: SuscripcionesRepo?
    private var memRepo: MembresiasRepo?
    private var cliRepo: ClientesRepo?

    func setup(db: AppDatabase) {
        guard pagosRepo == nil else { return }
        pagosRepo = PagosRepo(db: db)
        susRepo = SuscripcionesRepo(db: db)
        memRepo = MembresiasRepo(db: db)
        cliRepo = ClientesRepo(db: db)
        recargar()
    }

    func recargar() {
        guard let pagosRepo, let susRepo else { return }
        base = busqueda.isEmpty ? susRepo.verCompletas() : susRepo.buscar(busqueda)
        aplicarFiltro()
        totales = pagosRepo.totales()
        planes = memRepo?.ver() ?? []
        clientes = cliRepo?.ver() ?? []
    }

    func aplicarFiltro() { suscripciones = base.filter { filtro.incluye($0) } }

    func editarMontos(_ suscripcionId: Int64, precioTotal: Double, pagado: Double) {
        let r = susRepo?.editarMontos(id: suscripcionId, precioTotal: precioTotal, pagado: pagado)
        notificar(r?.mensaje ?? ""); recargar()
    }

    /// CSV de las suscripciones/pagos mostrados.
    func csv() -> String { CSVExport.suscripciones(suscripciones) }

    func cambiarPlan(suscripcionId: Int64, nuevoPlanId: Int64) {
        let r = pagosRepo?.cambiarPlan(suscripcionId: suscripcionId, nuevoPlanId: nuevoPlanId)
        notificar(r?.mensaje ?? ""); recargar()
    }

    func resetearPago(_ suscripcionId: Int64) {
        pagosRepo?.resetearPago(suscripcionId: suscripcionId); recargar()
    }

    func crearRapida(clienteId: Int64, membresiaId: Int64) {
        let r = susRepo?.crear(clienteId: clienteId, membresiaId: membresiaId)
        notificar(r?.mensaje ?? ""); recargar()
    }

    func eliminarSuscripcion(_ s: SuscripcionDetalle) {
        susRepo?.eliminar(id: s.id); recargar()
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

    func editarPago(_ id: Int64, nuevoMonto: Double) {
        let r = pagosRepo?.editarPago(id: id, nuevoMonto: nuevoMonto)
        notificar(r?.mensaje ?? ""); recargar()
    }

    private func notificar(_ m: String) { mensaje = m; mostrarMensaje = true }
}
