//
//  OtrosModels.swift
//  gym_systemOS
//
//  Registros GRDB de Ficha del cliente, Historial de medidas y Asistencia
//  (ipad_port/AUDIT.md §1.1). Port de modulos/ficha_cliente.py y ui/asistencia_ui.py.
//

import Foundation
import GRDB

// MARK: - FichaCliente

struct FichaCliente: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64? = nil
    var clienteId: Int64? = nil
    var objetivo: String? = nil
    var estadoFisico: String? = nil
    var condiciones: String? = nil
    var notas: String? = nil
    var fotoRuta: String? = nil
    var pesoKg: Double? = nil
    var alturaM: Double? = nil
    var cirAbdominal: Double? = nil
    var statusFisico: String? = nil
    var objetivo2: String? = nil
    var pesoIdeal: Double? = nil
    var lesion: String? = nil
    var cardiovascular: String? = nil
    var asfixia: String? = nil
    var asmatico: String? = nil
    var medicacion: String? = nil
    var mareos: String? = nil

    static let databaseTableName = "ficha_cliente"

    enum CodingKeys: String, CodingKey {
        case id
        case clienteId = "cliente_id"
        case objetivo
        case estadoFisico = "estado_fisico"
        case condiciones, notas
        case fotoRuta = "foto_ruta"
        case pesoKg = "peso_kg"
        case alturaM = "altura_m"
        case cirAbdominal = "cir_abdominal"
        case statusFisico = "status_fisico"
        case objetivo2 = "objetivo_2"
        case pesoIdeal = "peso_ideal"
        case lesion, cardiovascular, asfixia, asmatico, medicacion, mareos
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

// MARK: - HistorialMedida

struct HistorialMedida: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64? = nil
    var clienteId: Int64? = nil
    var fecha: String? = nil
    var pesoKg: Double? = nil
    var alturaCm: Double? = nil
    var imc: Double? = nil
    var notas: String? = nil

    static let databaseTableName = "historial_medidas"

    enum CodingKeys: String, CodingKey {
        case id
        case clienteId = "cliente_id"
        case fecha
        case pesoKg = "peso_kg"
        case alturaCm = "altura_cm"
        case imc, notas
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

// MARK: - Asistencia

struct Asistencia: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64? = nil
    var clienteId: Int64? = nil
    var cedula: String? = nil
    var nombre: String? = nil
    var fecha: String? = nil
    var hora: String? = nil
    var estado: String? = nil
    var vencimiento: String? = nil

    static let databaseTableName = "asistencia"

    enum CodingKeys: String, CodingKey {
        case id
        case clienteId = "cliente_id"
        case cedula, nombre, fecha, hora, estado, vencimiento
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
