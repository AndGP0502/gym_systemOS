//
//  PagosRepo.swift
//  gym_systemOS
//
//  Port fiel de modulos/pagos.py: registro/eliminación de pagos con histórico,
//  totales para las tarjetas resumen y consultas de caducados.
//

import Foundation
import GRDB

struct PagosRepo {
    let db: AppDatabase

    /// Registra un pago (regla idéntica al escritorio, incl. precio_total == 0).
    func registrar(suscripcionId: Int64, monto: Double) -> OperationResult {
        if monto <= 0 { return .fallo("Monto inválido") }
        do {
            return try db.dbWriter.write { dbc in
                guard let row = try Row.fetchOne(dbc, sql: """
                    SELECT COALESCE(precio_total,0) AS pt, COALESCE(pagado,0) AS pg
                    FROM suscripciones WHERE id = ?
                """, arguments: [suscripcionId]) else {
                    return .fallo("La suscripción no existe")
                }
                let precioTotal: Double = row["pt"]
                let pagadoActual: Double = row["pg"]

                if precioTotal > 0 && pagadoActual >= precioTotal {
                    return .fallo("La suscripción ya está pagada completamente")
                }

                var nuevoPagado = pagadoActual + monto
                let nuevoPrecio: Double
                let nuevoPendiente: Double
                if precioTotal == 0 {
                    nuevoPrecio = nuevoPagado
                    nuevoPendiente = 0
                } else {
                    nuevoPrecio = precioTotal
                    nuevoPagado = min(nuevoPagado, precioTotal)
                    nuevoPendiente = max(0, nuevoPrecio - nuevoPagado)
                }

                try dbc.execute(sql: """
                    UPDATE suscripciones SET pagado=?, pendiente=?, precio_total=? WHERE id=?
                """, arguments: [nuevoPagado, nuevoPendiente, nuevoPrecio, suscripcionId])
                try dbc.execute(sql: """
                    INSERT INTO pagos(suscripcion_id, monto, fecha_pago) VALUES (?,?,?)
                """, arguments: [suscripcionId, monto, Fechas.hoyStr()])
                return .exito("Pago registrado correctamente")
            }
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }

    func historial(suscripcionId: Int64) -> [Pago] {
        (try? db.reader.read { dbc in
            try Pago.fetchAll(dbc, sql: """
                SELECT * FROM pagos WHERE suscripcion_id = ? ORDER BY fecha_pago
            """, arguments: [suscripcionId])
        }) ?? []
    }

    /// Elimina un pago y revierte el monto en la suscripción.
    @discardableResult
    func eliminarPago(id: Int64) -> Bool {
        do {
            try db.dbWriter.write { dbc in
                guard let row = try Row.fetchOne(dbc,
                    sql: "SELECT suscripcion_id, monto FROM pagos WHERE id = ?", arguments: [id]) else {
                    return
                }
                let susId: Int64 = row["suscripcion_id"]
                let monto: Double = row["monto"]
                try dbc.execute(sql: "DELETE FROM pagos WHERE id = ?", arguments: [id])
                try dbc.execute(sql: """
                    UPDATE suscripciones
                    SET pagado = pagado - ?,
                        pendiente = MAX(0, precio_total - (pagado - ?))
                    WHERE id = ?
                """, arguments: [monto, monto, susId])
            }
            return true
        } catch { return false }
    }

    /// Cambia el plan de una suscripción: nuevo precio_total, recalcula el
    /// vencimiento (inicio + duración del nuevo plan) y el pendiente. (cambiar_plan)
    func cambiarPlan(suscripcionId: Int64, nuevoPlanId: Int64) -> OperationResult {
        do {
            return try db.dbWriter.write { dbc in
                guard let plan = try Row.fetchOne(dbc,
                        sql: "SELECT precio, duracion_dias FROM membresias WHERE id = ?", arguments: [nuevoPlanId]) else {
                    return .fallo("El plan no existe")
                }
                guard let sus = try Row.fetchOne(dbc,
                        sql: "SELECT fecha_inicio, COALESCE(pagado,0) AS pg FROM suscripciones WHERE id = ?",
                        arguments: [suscripcionId]) else {
                    return .fallo("La suscripción no existe")
                }
                let precio: Double = plan["precio"] ?? 0
                let dur: Int = plan["duracion_dias"] ?? 0
                let inicio: String = sus["fecha_inicio"] ?? Fechas.hoyStr()
                let pagado: Double = sus["pg"]
                let venc = Fechas.sumarDias(inicio, dur) ?? inicio
                let pendiente = max(0, precio - pagado)
                try dbc.execute(sql: """
                    UPDATE suscripciones SET membresia_id=?, precio_total=?, fecha_vencimiento=?, pendiente=?
                    WHERE id=?
                """, arguments: [nuevoPlanId, precio, venc, pendiente, suscripcionId])
                return .exito("Plan cambiado correctamente")
            }
        } catch { return .fallo("Error de base de datos: \(error.localizedDescription)") }
    }

    /// Resetea el pago de una suscripción: pagado=0, pendiente=precio_total y
    /// borra el histórico de pagos de esa suscripción. (resetear_pago)
    @discardableResult
    func resetearPago(suscripcionId: Int64) -> Bool {
        do {
            try db.dbWriter.write { dbc in
                try dbc.execute(sql: "DELETE FROM pagos WHERE suscripcion_id = ?", arguments: [suscripcionId])
                try dbc.execute(sql: """
                    UPDATE suscripciones SET pagado = 0, pendiente = COALESCE(precio_total,0) WHERE id = ?
                """, arguments: [suscripcionId])
            }
            return true
        } catch { return false }
    }

    /// Totales para las tarjetas resumen del módulo Pagos.
    struct Totales { var total = 0; var pagadas = 0; var pendientes = 0; var recaudado = 0.0 }

    func totales() -> Totales {
        (try? db.reader.read { dbc -> Totales in
            var t = Totales()
            t.total = try Int.fetchOne(dbc, sql: "SELECT COUNT(*) FROM suscripciones") ?? 0
            t.pagadas = try Int.fetchOne(dbc,
                sql: "SELECT COUNT(*) FROM suscripciones WHERE COALESCE(pendiente,0) <= 0 AND COALESCE(pagado,0) > 0") ?? 0
            t.pendientes = try Int.fetchOne(dbc,
                sql: "SELECT COUNT(*) FROM suscripciones WHERE COALESCE(pendiente,0) > 0") ?? 0
            t.recaudado = try Double.fetchOne(dbc,
                sql: "SELECT COALESCE(SUM(pagado),0) FROM suscripciones") ?? 0
            return t
        }) ?? Totales()
    }
}
