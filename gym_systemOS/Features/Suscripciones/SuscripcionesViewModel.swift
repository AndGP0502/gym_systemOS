//
//  SuscripcionesViewModel.swift
//  gym_systemOS
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SuscripcionesViewModel: ObservableObject {
    @Published var suscripciones: [SuscripcionDetalle] = []
    @Published var busqueda: String = ""
    @Published var filtro: FiltroSuscripcion = .todas
    @Published var clientes: [Cliente] = []
    @Published var planes: [Membresia] = []
    @Published var mensaje: String?
    @Published var mostrarMensaje = false

    private var base: [SuscripcionDetalle] = []

    private var susRepo: SuscripcionesRepo?
    private var memRepo: MembresiasRepo?
    private var cliRepo: ClientesRepo?
    private var pagosRepo: PagosRepo?

    func setup(db: AppDatabase) {
        guard susRepo == nil else { return }
        susRepo = SuscripcionesRepo(db: db)
        memRepo = MembresiasRepo(db: db)
        cliRepo = ClientesRepo(db: db)
        pagosRepo = PagosRepo(db: db)
        recargar()
    }

    func recargar() {
        guard let susRepo, let memRepo, let cliRepo else { return }
        base = busqueda.isEmpty ? susRepo.verCompletas() : susRepo.buscar(busqueda)
        aplicarFiltro()
        planes = memRepo.ver()
        clientes = cliRepo.ver()
    }

    func aplicarFiltro() { suscripciones = base.filter { filtro.incluye($0) } }

    func editarMontos(_ s: SuscripcionDetalle, precioTotal: Double, pagado: Double) {
        let r = susRepo?.editarMontos(id: s.id, precioTotal: precioTotal, pagado: pagado)
        notificar(r?.mensaje ?? ""); recargar()
    }

    /// CSV de las suscripciones mostradas (con filtro/búsqueda aplicados).
    func csv() -> String { CSVExport.suscripciones(suscripciones) }

    func asignar(clienteId: Int64, membresiaId: Int64, pagado: Double) {
        guard let susRepo, let plan = planes.first(where: { $0.id == membresiaId }) else { return }
        let r = susRepo.asignar(clienteId: clienteId, membresiaId: membresiaId,
                                precioTotal: plan.precio ?? 0, pagado: pagado)
        notificar(r.mensaje); if r.ok { recargar() }
    }

    func renovar(clienteId: Int64, dias: Int, monto: Double) {
        guard let susRepo else { return }
        let r = susRepo.renovar(clienteId: clienteId, dias: dias, monto: monto)
        notificar(r.mensaje); if r.ok { recargar() }
    }

    func eliminar(_ s: SuscripcionDetalle) {
        susRepo?.eliminar(id: s.id); recargar()
    }

    func editarFechas(_ s: SuscripcionDetalle, inicio: String, vencimiento: String) {
        guard let susRepo else { return }
        let r = susRepo.editarFechas(id: s.id, fechaInicio: inicio, fechaVencimiento: vencimiento)
        notificar(r.mensaje); if r.ok { recargar() }
    }

    /// Edición combinada: opcionalmente cambia el plan y ajusta las fechas.
    func editarSuscripcion(_ s: SuscripcionDetalle, nuevoPlanId: Int64?, inicio: String, vencimiento: String) {
        guard let susRepo else { return }
        // Si cambia el plan, primero se aplica (recalcula precio); luego se fijan las fechas elegidas.
        if let planId = nuevoPlanId {
            _ = pagosRepo?.cambiarPlan(suscripcionId: s.id, nuevoPlanId: planId)
        }
        let r = susRepo.editarFechas(id: s.id, fechaInicio: inicio, fechaVencimiento: vencimiento)
        notificar(r.ok ? "Suscripción actualizada correctamente" : r.mensaje)
        recargar()
    }

    // Planes
    func crearPlan(nombre: String, precio: Double, dias: Int) {
        guard let memRepo else { return }
        let r = memRepo.crear(nombrePlan: nombre, precio: precio, duracionDias: dias)
        notificar(r.mensaje); if r.ok { recargar() }
    }

    func editarPlan(_ m: Membresia, nombre: String, precio: Double, dias: Int) {
        guard let memRepo, let id = m.id else { return }
        let r = memRepo.editar(id: id, nombrePlan: nombre, precio: precio, duracionDias: dias)
        notificar(r.mensaje); if r.ok { recargar() }
    }

    func eliminarPlan(_ m: Membresia) {
        guard let memRepo, let id = m.id else { return }
        memRepo.eliminar(id: id); recargar()
    }

    private func notificar(_ m: String) { mensaje = m; mostrarMensaje = true }
}
