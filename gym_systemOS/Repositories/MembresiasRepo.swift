//
//  MembresiasRepo.swift
//  gym_systemOS
//
//  Port de modulos/membresias.py: CRUD de planes.
//

import Foundation
import GRDB

struct MembresiasRepo {
    let db: AppDatabase

    func crear(nombrePlan: String, precio: Double, duracionDias: Int) -> OperationResult {
        let nombre = nombrePlan.trimmingCharacters(in: .whitespacesAndNewlines)
        if nombre.isEmpty { return .fallo("El nombre del plan no puede estar vacío") }
        if precio <= 0 { return .fallo("El precio debe ser mayor a 0") }
        if duracionDias <= 0 { return .fallo("La duración debe ser mayor a 0") }
        do {
            return try db.dbWriter.write { dbc in
                let existe = try Int.fetchOne(dbc,
                    sql: "SELECT 1 FROM membresias WHERE nombre_plan = ?", arguments: [nombre]) != nil
                if existe { return .fallo("Ya existe una membresía con ese nombre") }
                try dbc.execute(sql: """
                    INSERT INTO membresias(nombre_plan, precio, duracion_dias) VALUES (?,?,?)
                """, arguments: [nombre, precio, duracionDias])
                return .exito("Membresía creada correctamente")
            }
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }

    func editar(id: Int64, nombrePlan: String, precio: Double, duracionDias: Int) -> OperationResult {
        let nombre = nombrePlan.trimmingCharacters(in: .whitespacesAndNewlines)
        if nombre.isEmpty { return .fallo("El nombre del plan no puede estar vacío") }
        if precio <= 0 { return .fallo("El precio debe ser mayor a 0") }
        if duracionDias <= 0 { return .fallo("La duración debe ser mayor a 0") }
        do {
            try db.dbWriter.write { dbc in
                try dbc.execute(sql: """
                    UPDATE membresias SET nombre_plan=?, precio=?, duracion_dias=? WHERE id=?
                """, arguments: [nombre, precio, duracionDias, id])
            }
            return .exito("Membresía actualizada correctamente")
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }

    func ver() -> [Membresia] {
        (try? db.reader.read { dbc in
            try Membresia.fetchAll(dbc, sql: "SELECT * FROM membresias ORDER BY id")
        }) ?? []
    }

    /// Elimina un plan solo si NINGUNA suscripción lo usa (coherencia de datos).
    @discardableResult
    func eliminar(id: Int64) -> OperationResult {
        do {
            return try db.dbWriter.write { dbc in
                let enUso = try Int.fetchOne(dbc,
                    sql: "SELECT COUNT(*) FROM suscripciones WHERE membresia_id = ?", arguments: [id]) ?? 0
                if enUso > 0 {
                    return .fallo("No se puede eliminar: \(enUso) suscripción(es) usan este plan. Cámbialas o elimínalas primero.")
                }
                try dbc.execute(sql: "DELETE FROM membresias WHERE id = ?", arguments: [id])
                return .exito("Plan eliminado")
            }
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }
}
