//
//  CoreModels.swift
//  gym_systemOS
//
//  Registros GRDB del núcleo de gimnasio. Mapean camelCase ↔ columnas snake_case
//  del esquema auditado (ipad_port/AUDIT.md §1.1).
//

import Foundation
import GRDB

// MARK: - Cliente

struct Cliente: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64?
    var nombre: String?
    var cedula: String?
    var telefono: String?
    var fechaRegistro: String?
    var correo: String?
    var edad: Double?
    var fechaNacimiento: String?
    var sexo: String?

    static let databaseTableName = "clientes"

    enum CodingKeys: String, CodingKey {
        case id, nombre, cedula, telefono
        case fechaRegistro = "fecha_registro"
        case correo, edad
        case fechaNacimiento = "fecha_nacimiento"
        case sexo
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

// MARK: - Membresia

struct Membresia: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64?
    var nombrePlan: String?
    var precio: Double?
    var duracionDias: Int?

    static let databaseTableName = "membresias"

    enum CodingKeys: String, CodingKey {
        case id
        case nombrePlan = "nombre_plan"
        case precio
        case duracionDias = "duracion_dias"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

// MARK: - Suscripcion

struct Suscripcion: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64?
    var clienteId: Int64?
    var membresiaId: Int64?
    var fechaInicio: String?
    var fechaVencimiento: String?
    var precioTotal: Double?
    var pagado: Double?
    var pendiente: Double?

    static let databaseTableName = "suscripciones"

    enum CodingKeys: String, CodingKey {
        case id
        case clienteId = "cliente_id"
        case membresiaId = "membresia_id"
        case fechaInicio = "fecha_inicio"
        case fechaVencimiento = "fecha_vencimiento"
        case precioTotal = "precio_total"
        case pagado, pendiente
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

// MARK: - Pago

struct Pago: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64?
    var suscripcionId: Int64?
    var monto: Double?
    var fechaPago: String?

    static let databaseTableName = "pagos"

    enum CodingKeys: String, CodingKey {
        case id
        case suscripcionId = "suscripcion_id"
        case monto
        case fechaPago = "fecha_pago"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
