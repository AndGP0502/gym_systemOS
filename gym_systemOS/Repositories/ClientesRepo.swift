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
        // Solo el nombre es obligatorio. Cédula y teléfono son OPCIONALES;
        // la cédula solo se valida que no se repita si la escriben.

        do {
            return try db.dbWriter.write { dbc in
                if !cedula.isEmpty {
                    let existe = try Int.fetchOne(dbc,
                        sql: "SELECT 1 FROM clientes WHERE cedula = ?", arguments: [cedula]) != nil
                    if existe { return .fallo("Ya existe un cliente registrado con esa cédula") }
                }

                var c = Cliente(id: try nuevoID(dbc),
                                nombre: nombre,
                                cedula: cedula.isEmpty ? nil : cedula,
                                telefono: telefono.isEmpty ? nil : telefono,
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

    struct ResumenClientes { var total = 0; var activos = 0; var vencidos = 0; var conDeuda = 0 }

    /// Conjuntos de IDs de cliente por estado de suscripción (para tarjetas y filtros).
    struct EstadosClientes {
        var activos: Set<Int64> = []   // con suscripción vigente
        var conSub: Set<Int64> = []    // con alguna suscripción
        var conDeuda: Set<Int64> = []  // con pendiente > 0
        var vencidos: Set<Int64> { conSub.subtracting(activos) }
    }

    func estados() -> EstadosClientes {
        (try? db.reader.read { dbc -> EstadosClientes in
            let hoy = Fechas.hoyStr()
            var e = EstadosClientes()
            e.activos = try Int64.fetchSet(dbc,
                sql: "SELECT DISTINCT cliente_id FROM suscripciones WHERE fecha_vencimiento >= ?", arguments: [hoy])
            e.conSub = try Int64.fetchSet(dbc, sql: "SELECT DISTINCT cliente_id FROM suscripciones")
            e.conDeuda = try Int64.fetchSet(dbc,
                sql: "SELECT DISTINCT cliente_id FROM suscripciones WHERE COALESCE(pendiente,0) > 0")
            return e
        }) ?? EstadosClientes()
    }

    func resumen() -> ResumenClientes {
        let e = estados()
        return ResumenClientes(total: contar(), activos: e.activos.count,
                               vencidos: e.vencidos.count, conDeuda: e.conDeuda.count)
    }

    /// Días restantes de la suscripción más reciente del cliente (nil si no tiene).
    /// Port de alertas.dias_restantes.
    func diasRestantes(clienteId: Int64) -> Int? {
        let venc = try? db.reader.read { dbc in
            try String.fetchOne(dbc, sql: """
                SELECT fecha_vencimiento FROM suscripciones
                WHERE cliente_id = ? ORDER BY fecha_vencimiento DESC LIMIT 1
            """, arguments: [clienteId])
        }
        guard let venc = venc ?? nil, let f = Fechas.parse(venc) else { return nil }
        return Fechas.dias(desde: Date(), hasta: f)
    }

    // MARK: - Actualizar

    func editar(id: Int64, nombre: String, cedula: String, telefono: String,
                correo: String = "", fechaRegistro: String) -> OperationResult {
        let cedula = cedula.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            return try db.dbWriter.write { dbc in
                // La cédula es opcional; solo se valida duplicado si la escriben.
                if !cedula.isEmpty {
                    let dup = try Int.fetchOne(dbc,
                        sql: "SELECT 1 FROM clientes WHERE cedula = ? AND id != ?",
                        arguments: [cedula, id]) != nil
                    if dup { return .fallo("Ya existe otro cliente con esa cédula") }
                }

                try dbc.execute(sql: """
                    UPDATE clientes SET nombre=?, cedula=?, telefono=?, fecha_registro=?, correo=?
                    WHERE id=?
                """, arguments: [nombre, cedula.isEmpty ? nil : cedula,
                                 telefono.isEmpty ? nil : telefono, fechaRegistro, correo, id])
                return .exito("Cliente actualizado correctamente")
            }
        } catch {
            return .fallo("Error de base de datos: \(error.localizedDescription)")
        }
    }

    // MARK: - Eliminar

    /// Elimina un cliente EN CASCADA: sus suscripciones, pagos, ficha, medidas y
    /// asistencias, para que no queden datos huérfanos en ningún módulo
    /// (Caducados, Pagos, Dashboard). Todo en una sola transacción.
    @discardableResult
    func eliminar(id: Int64) -> Bool {
        do {
            try db.dbWriter.write { dbc in
                try dbc.execute(sql: """
                    DELETE FROM pagos WHERE suscripcion_id IN
                        (SELECT id FROM suscripciones WHERE cliente_id = ?)
                """, arguments: [id])
                try dbc.execute(sql: "DELETE FROM suscripciones WHERE cliente_id = ?", arguments: [id])
                try dbc.execute(sql: "DELETE FROM ficha_cliente WHERE cliente_id = ?", arguments: [id])
                try dbc.execute(sql: "DELETE FROM historial_medidas WHERE cliente_id = ?", arguments: [id])
                try dbc.execute(sql: "DELETE FROM asistencia WHERE cliente_id = ?", arguments: [id])
                // Las facturas son comprobantes fiscales: NO se borran, solo se
                // desvinculan del cliente (evita violar la llave foránea).
                try dbc.execute(sql: "UPDATE facturas SET cliente_id = NULL WHERE cliente_id = ?", arguments: [id])
                try dbc.execute(sql: "DELETE FROM clientes WHERE id = ?", arguments: [id])
            }
            return true
        } catch { return false }
    }
}
