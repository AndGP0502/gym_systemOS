//
//  SuscripcionesRepo.swift
//  gym_systemOS
//
//  Port de modulos/suscripciones.py: asignación de membresías, listados de
//  activos/caducados, contadores y renovación. IDs con hueco más bajo.
//

import Foundation
import GRDB

struct SuscripcionesRepo {
    let db: AppDatabase

    private func nuevoID(_ dbc: Database) throws -> Int64 {
        let ids = try Int64.fetchSet(dbc, sql: "SELECT id FROM suscripciones")
        var nuevo: Int64 = 1
        while ids.contains(nuevo) { nuevo += 1 }
        return nuevo
    }

    // MARK: - Crear / asignar

    /// Asigna una membresía a un cliente (replica `asignar_membresia`).
    /// `fechaInicio` en `yyyy-MM-dd`; si nil, usa hoy.
    func asignar(clienteId: Int64, membresiaId: Int64, precioTotal: Double,
                 pagado: Double, fechaInicio: String? = nil) -> OperationResult {
        do {
            return try db.dbWriter.write { dbc in
                guard try Int.fetchOne(dbc, sql: "SELECT 1 FROM clientes WHERE id = ?",
                                       arguments: [clienteId]) != nil else {
                    return .fallo("El cliente no existe")
                }
                guard let dur = try Int.fetchOne(dbc,
                        sql: "SELECT duracion_dias FROM membresias WHERE id = ?",
                        arguments: [membresiaId]) else {
                    return .fallo("La membresía no existe")
                }
                let inicio = fechaInicio ?? Fechas.hoyStr()
                guard let venc = Fechas.sumarDias(inicio, dur) else {
                    return .fallo("Fecha de inicio inválida: '\(inicio)'")
                }
                let pendiente = max(0, precioTotal - pagado)
                let nuevo = try nuevoID(dbc)
                try dbc.execute(sql: """
                    INSERT INTO suscripciones(
                        id, cliente_id, membresia_id, fecha_inicio, fecha_vencimiento,
                        precio_total, pagado, pendiente
                    ) VALUES (?,?,?,?,?,?,?,?)
                """, arguments: [nuevo, clienteId, membresiaId, inicio, venc,
                                 precioTotal, pagado, pendiente])
                return .exito("Membresía asignada correctamente")
            }
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }

    /// Crea una suscripción tomando precio/duración del plan, pagado = 0.
    func crear(clienteId: Int64, membresiaId: Int64) -> OperationResult {
        do {
            return try db.reader.read { dbc -> (Double, Int)? in
                try Row.fetchOne(dbc, sql: "SELECT precio, duracion_dias FROM membresias WHERE id = ?",
                                 arguments: [membresiaId]).map { ($0["precio"] ?? 0, $0["duracion_dias"] ?? 0) }
            }.map { (precio, _) in
                asignar(clienteId: clienteId, membresiaId: membresiaId,
                        precioTotal: precio, pagado: 0)
            } ?? .fallo("La membresía no existe")
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }

    // MARK: - Consultas

    func verCompletas() -> [SuscripcionDetalle] {
        (try? db.reader.read { dbc in
            try SuscripcionDetalle.fetchAll(dbc,
                sql: SuscripcionDetalle.selectBase + " ORDER BY s.id")
        }) ?? []
    }

    func buscar(_ texto: String) -> [SuscripcionDetalle] {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return verCompletas() }
        let like = "%\(t)%"
        return (try? db.reader.read { dbc in
            try SuscripcionDetalle.fetchAll(dbc, sql: SuscripcionDetalle.selectBase + """
                 WHERE c.nombre LIKE ? COLLATE NOCASE OR c.cedula LIKE ? COLLATE NOCASE
                 ORDER BY s.id
            """, arguments: [like, like])
        }) ?? []
    }

    /// Suscripciones activas (fecha_vencimiento >= hoy).
    func activasDetalle() -> [SuscripcionDetalle] {
        (try? db.reader.read { dbc in
            try SuscripcionDetalle.fetchAll(dbc, sql: SuscripcionDetalle.selectBase + """
                 WHERE s.fecha_vencimiento >= ? ORDER BY s.fecha_vencimiento ASC
            """, arguments: [Fechas.hoyStr()])
        }) ?? []
    }

    /// Suscripciones caducadas (fecha_vencimiento < hoy).
    func caducadasDetalle() -> [SuscripcionDetalle] {
        (try? db.reader.read { dbc in
            try SuscripcionDetalle.fetchAll(dbc, sql: SuscripcionDetalle.selectBase + """
                 WHERE s.fecha_vencimiento < ? ORDER BY s.fecha_vencimiento DESC
            """, arguments: [Fechas.hoyStr()])
        }) ?? []
    }

    func contarActivos() -> Int {
        (try? db.reader.read { dbc in
            try Int.fetchOne(dbc, sql: "SELECT COUNT(*) FROM suscripciones WHERE fecha_vencimiento >= ?",
                             arguments: [Fechas.hoyStr()]) ?? 0
        }) ?? 0
    }

    func contarVencidas() -> Int {
        (try? db.reader.read { dbc in
            try Int.fetchOne(dbc, sql: "SELECT COUNT(*) FROM suscripciones WHERE fecha_vencimiento < ?",
                             arguments: [Fechas.hoyStr()]) ?? 0
        }) ?? 0
    }

    // MARK: - Renovar (replica renovar_suscripcion_cliente)

    /// Extiende `dias` la suscripción más reciente del cliente. Si `monto>0`,
    /// acumula precio_total y pagado del nuevo periodo y registra el pago.
    @discardableResult
    func renovar(clienteId: Int64, dias: Int = 30, monto: Double = 0) -> OperationResult {
        do {
            return try db.dbWriter.write { dbc in
                guard let row = try Row.fetchOne(dbc, sql: """
                    SELECT id, fecha_vencimiento, COALESCE(precio_total,0) AS pt,
                           COALESCE(pagado,0) AS pg
                    FROM suscripciones WHERE cliente_id = ?
                    ORDER BY fecha_vencimiento DESC LIMIT 1
                """, arguments: [clienteId]) else {
                    return .fallo("El cliente no tiene suscripción")
                }
                let susId: Int64 = row["id"]
                let vencStr: String? = row["fecha_vencimiento"]
                let precioTotal: Double = row["pt"]
                let pagadoActual: Double = row["pg"]
                guard let nueva = vencStr.flatMap({ Fechas.sumarDias($0, dias) }) else {
                    return .fallo("Fecha de vencimiento inválida")
                }
                try dbc.execute(sql: "UPDATE suscripciones SET fecha_vencimiento = ? WHERE id = ?",
                                arguments: [nueva, susId])
                if monto > 0 {
                    let nuevoPrecio = precioTotal + monto
                    let nuevoPagado = pagadoActual + monto
                    let nuevoPend = max(0, nuevoPrecio - nuevoPagado)
                    try dbc.execute(sql: """
                        UPDATE suscripciones SET pagado=?, pendiente=?, precio_total=? WHERE id=?
                    """, arguments: [nuevoPagado, nuevoPend, nuevoPrecio, susId])
                    try dbc.execute(sql: """
                        INSERT INTO pagos(suscripcion_id, monto, fecha_pago) VALUES (?,?,?)
                    """, arguments: [susId, monto, Fechas.hoyStr()])
                }
                return .exito("Suscripción renovada correctamente")
            }
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }

    /// Edita las fechas de una suscripción (inicio y/o vencimiento). (editar_fechas)
    func editarFechas(id: Int64, fechaInicio: String, fechaVencimiento: String) -> OperationResult {
        guard Fechas.parse(fechaInicio) != nil, Fechas.parse(fechaVencimiento) != nil else {
            return .fallo("Formato de fecha inválido (use yyyy-MM-dd)")
        }
        do {
            try db.dbWriter.write { dbc in
                try dbc.execute(sql: "UPDATE suscripciones SET fecha_inicio=?, fecha_vencimiento=? WHERE id=?",
                                arguments: [fechaInicio, fechaVencimiento, id])
            }
            return .exito("Fechas actualizadas correctamente")
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }

    // MARK: - Eliminar

    @discardableResult
    func eliminar(id: Int64) -> Bool {
        do {
            try db.dbWriter.write { dbc in
                try dbc.execute(sql: "DELETE FROM pagos WHERE suscripcion_id = ?", arguments: [id])
                try dbc.execute(sql: "DELETE FROM suscripciones WHERE id = ?", arguments: [id])
            }
            return true
        } catch { return false }
    }
}
