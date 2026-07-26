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
    @Published var mensaje: String?
    @Published var mostrarMensaje = false

    private var repo: ClientesRepo?

    func setup(db: AppDatabase) {
        guard repo == nil else { return }
        repo = ClientesRepo(db: db)
        recargar()
    }

    func recargar() {
        guard let repo else { return }
        clientes = busqueda.isEmpty ? repo.ver() : repo.buscar(busqueda)
    }

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

    private func notificar(_ m: String) {
        mensaje = m
        mostrarMensaje = true
    }
}
