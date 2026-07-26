//
//  ClientesRepo.swift
//  gym_systemOS
//
//  Port fiel de modulos/clientes.py: CRUD de clientes con validaciones,
//  cédula no duplicada e IDs reutilizando el hueco más bajo.
//

import Foundation
import GRDB

struct ClientesRepo {
    let db: AppDatabase

    /// ID más bajo disponible (replica `_nuevo_id` del Python).
    private func nuevoID(_ dbc: Database) throws -> Int64 {
        let ids = try Int64.fetchSet(dbc, sql: "SELECT id FROM clientes")
        var nuevo: Int64 = 1
        while ids.contains(nuevo) { nuevo += 1 }
        return nuevo
    }

    // MARK: - Crear

    func agregar(nombre: String, cedula: String, telefono: String,
                 correo: String = "", fechaRegistro: String? = nil) -> OperationResult {
        let nombre = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let cedula = cedula.trimmingCharacters(in: .whitespacesAndNewlines)
        let telefono = telefono.trimmingCharacters(in: .whitespacesAndNewlines)

        if nombre.isEmpty { return .fallo("El nombre del cliente es obligatorio") }
        if cedula.isEmpty { return .fallo("La cédula es obligatoria") }
        if telefono.isEmpty { return .fallo("El teléfono es obligatorio") }

        do {
            return try db.dbWriter.write { dbc in
                let existe = try Int.fetchOne(dbc,
                    sql: "SELECT 1 FROM clientes WHERE cedula = ?", arguments: [cedula]) != nil
                if existe { return .fallo("Ya existe un cliente registrado con esa cédula") }

                var c = Cliente(id: try nuevoID(dbc),
                                nombre: nombre, cedula: cedula, telefono: telefono,
                                fechaRegistro: fechaRegistro ?? Fechas.hoyStr(),
                                correo: correo)
                try c.insert(dbc)
                return .exito("Cliente agregado correctamente")
            }
        } catch {
            return .fallo("Error de base de datos: \(error.localizedDescription)")
        }
    }

    // MARK: - Leer

    func ver() -> [Cliente] {
        (try? db.reader.read { dbc in
            try Cliente.fetchAll(dbc, sql: "SELECT * FROM clientes ORDER BY id")
        }) ?? []
    }

    /// Búsqueda parcial por cédula o nombre (LIKE NOCASE), como en el escritorio.
    func buscar(_ texto: String) -> [Cliente] {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return ver() }
        let like = "%\(t)%"
        return (try? db.reader.read { dbc in
            try Cliente.fetchAll(dbc, sql: """
                SELECT * FROM clientes
                WHERE nombre LIKE ? COLLATE NOCASE OR cedula LIKE ? COLLATE NOCASE
                ORDER BY id
            """, arguments: [like, like])
        }) ?? []
    }

    func contar() -> Int {
        (try? db.reader.read { dbc in
            try Int.fetchOne(dbc, sql: "SELECT COUNT(*) FROM clientes") ?? 0
        }) ?? 0
    }

    // MARK: - Actualizar

    func editar(id: Int64, nombre: String, cedula: String, telefono: String,
                correo: String = "", fechaRegistro: String) -> OperationResult {
        do {
            return try db.dbWriter.write { dbc in
                let dup = try Int.fetchOne(dbc,
                    sql: "SELECT 1 FROM clientes WHERE cedula = ? AND id != ?",
                    arguments: [cedula, id]) != nil
                if dup { return .fallo("Ya existe otro cliente con esa cédula") }

                try dbc.execute(sql: """
                    UPDATE clientes SET nombre=?, cedula=?, telefono=?, fecha_registro=?, correo=?
                    WHERE id=?
                """, arguments: [nombre, cedula, telefono, fechaRegistro, correo, id])
                return .exito("Cliente actualizado correctamente")
            }
        } catch {
            return .fallo("Error de base de datos: \(error.localizedDescription)")
        }
    }

    // MARK: - Eliminar

    @discardableResult
    func eliminar(id: Int64) -> Bool {
        (try? db.dbWriter.write { dbc in
            try dbc.execute(sql: "DELETE FROM clientes WHERE id = ?", arguments: [id])
        }) != nil
    }
}
