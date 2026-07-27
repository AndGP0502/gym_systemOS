//
//  DashboardRepo.swift
//  gym_systemOS
//
//  Métricas del dashboard (port de ventana_princi.actualizar_dashboard,
//  suscripciones.ingresos_por_mes y modulos/graficas.grafica_clientes).
//

import Foundation
import GRDB

struct PuntoMes: Identifiable, Hashable {
    var id: String { mes }
    let mes: String     // "01".."12"
    let valor: Double
}

struct DashboardResumen {
    var clientes = 0
    var activos = 0
    var vencidos = 0
    var planes = 0
    var ingresosMes = 0.0
    var recaudadoTotal = 0.0
    var ingresosPorMes: [PuntoMes] = []
    var clientesPorMes: [PuntoMes] = []
}

struct DashboardRepo {
    let db: AppDatabase

    func resumen() -> DashboardResumen {
        (try? db.reader.read { dbc -> DashboardResumen in
            var r = DashboardResumen()
            let hoy = Fechas.hoyStr()
            let anio = String(hoy.prefix(4))
            r.clientes = try Int.fetchOne(dbc, sql: "SELECT COUNT(*) FROM clientes") ?? 0
            r.activos = try Int.fetchOne(dbc,
                sql: "SELECT COUNT(*) FROM suscripciones WHERE fecha_vencimiento >= ?", arguments: [hoy]) ?? 0
            r.vencidos = try Int.fetchOne(dbc,
                sql: "SELECT COUNT(*) FROM suscripciones WHERE fecha_vencimiento < ?", arguments: [hoy]) ?? 0
            r.planes = try Int.fetchOne(dbc, sql: "SELECT COUNT(*) FROM membresias") ?? 0
            r.recaudadoTotal = try Double.fetchOne(dbc, sql: "SELECT COALESCE(SUM(pagado),0) FROM suscripciones") ?? 0
            r.ingresosMes = try Double.fetchOne(dbc, sql: """
                SELECT COALESCE(SUM(pagado),0) FROM suscripciones
                WHERE strftime('%Y-%m', fecha_inicio) = ?
            """, arguments: [String(hoy.prefix(7))]) ?? 0

            // Ingresos por mes del año actual (suscripciones.ingresos_por_mes)
            let ingRows = try Row.fetchAll(dbc, sql: """
                SELECT strftime('%m', fecha_inicio) AS mes, COALESCE(SUM(pagado),0) AS total
                FROM suscripciones WHERE strftime('%Y', fecha_inicio) = ?
                GROUP BY mes ORDER BY mes
            """, arguments: [anio])
            r.ingresosPorMes = ingRows.compactMap { row in
                guard let mes: String = row["mes"] else { return nil }
                return PuntoMes(mes: mes, valor: row["total"])
            }

            // Nuevos clientes por mes (grafica_clientes)
            let cliRows = try Row.fetchAll(dbc, sql: """
                SELECT strftime('%m', fecha_registro) AS mes, COUNT(*) AS total
                FROM clientes WHERE strftime('%Y', fecha_registro) = ?
                GROUP BY mes ORDER BY mes
            """, arguments: [anio])
            r.clientesPorMes = cliRows.compactMap { row in
                guard let mes: String = row["mes"] else { return nil }
                return PuntoMes(mes: mes, valor: Double(row["total"] as Int))
            }
            return r
        }) ?? DashboardResumen()
    }
}
