//
//  ClientesViewModel.swift
//  gym_systemOS
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ClientesViewModel: ObservableObject {
    @Published var clientes: [Cliente] = []
    @Published var busqueda: String = ""
    @Published var filtro: FiltroCliente = .todos
    @Published var resumen = ClientesRepo.ResumenClientes()
    @Published var mensaje: String?
    @Published var mostrarMensaje = false

    private var repo: ClientesRepo?
    private var fichaRepo: FichaRepo?
    private var estadosCache = ClientesRepo.EstadosClientes()

    func setup(db: AppDatabase) {
        guard repo == nil else { return }
        repo = ClientesRepo(db: db)
        fichaRepo = FichaRepo(db: db)
        recargar()
    }

    /// Genera el PDF con la información del cliente (datos + ficha + medidas).
    func fichaPDF(_ c: Cliente) -> Data? {
        guard let fichaRepo, let id = c.id else { return nil }
        return FichaPDF.generar(cliente: c,
                                ficha: fichaRepo.obtener(clienteId: id),
                                historial: fichaRepo.historial(clienteId: id),
                                foto: fichaRepo.fotoData(clienteId: id))
    }

    func recargar() {
        guard let repo else { return }
        estadosCache = repo.estados()
        resumen = ClientesRepo.ResumenClientes(total: repo.contar(),
            activos: estadosCache.activos.count, vencidos: estadosCache.vencidos.count,
            conDeuda: estadosCache.conDeuda.count)
        let base = busqueda.isEmpty ? repo.ver() : repo.buscar(busqueda)
        clientes = aplicarFiltro(base)
    }

    private func aplicarFiltro(_ base: [Cliente]) -> [Cliente] {
        switch filtro {
        case .todos:    return base
        case .activos:  return base.filter { $0.id.map(estadosCache.activos.contains) ?? false }
        case .vencidos: return base.filter { $0.id.map(estadosCache.vencidos.contains) ?? false }
        case .conDeuda: return base.filter { $0.id.map(estadosCache.conDeuda.contains) ?? false }
        }
    }

    /// CSV de los clientes actualmente mostrados (con filtro/búsqueda aplicados).
    func csv() -> String { CSVExport.clientes(clientes) }

    func agregar(nombre: String, cedula: String, telefono: String, correo: String) -> Bool {
        guard let repo else { return false }
        let r = repo.agregar(nombre: nombre, cedula: cedula, telefono: telefono, correo: correo)
        notificar(r.mensaje)
        if r.ok { recargar() }
        return r.ok
    }

    func editar(_ c: Cliente, nombre: String, cedula: String, telefono: String, correo: String) -> Bool {
        guard let repo, let id = c.id else { return false }
        let r = repo.editar(id: id, nombre: nombre, cedula: cedula, telefono: telefono,
                            correo: correo, fechaRegistro: c.fechaRegistro ?? Fechas.hoyStr())
        notificar(r.mensaje)
        if r.ok { recargar() }
        return r.ok
    }

    func eliminar(_ c: Cliente) {
        guard let repo, let id = c.id else { return }
        repo.eliminar(id: id)
        recargar()
    }

    func diasRestantes(_ c: Cliente) -> Int? {
        guard let repo, let id = c.id else { return nil }
        return repo.diasRestantes(clienteId: id)
    }

    private func notificar(_ m: String) {
        mensaje = m
        mostrarMensaje = true
    }
}
