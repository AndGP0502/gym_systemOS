//
//  AsistenciaRepo.swift
//  gym_systemOS
//
//  Port de ui/asistencia_ui.py: registro de asistencia por cédula con cálculo
//  de estado de membresía (ACTIVO / POR VENCER / VENCIDO / SIN MEMBRESÍA).
//

import Foundation
import GRDB

struct ResultadoAsistencia {
    var ok: Bool
    var error: String?
    var nombre: String = ""
    var cedula: String = ""
    var plan: String = "—"
    var estado: String = ""
    var vencimiento: String = "—"
    var hora: String = ""
    var fecha: String = ""
    var alerta: String = ""
    var pendiente: Double = 0
}

struct AsistenciaRepo {
    let db: AppDatabase

    /// Busca el cliente por cédula, evalúa su membresía y registra la asistencia.
    func registrar(cedula: String) -> ResultadoAsistencia {
        let ced = cedula.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            return try db.dbWriter.write { dbc in
                guard let cli = try Row.fetchOne(dbc,
                        sql: "SELECT id, nombre FROM clientes WHERE cedula = ?", arguments: [ced]) else {
                    return ResultadoAsistencia(ok: false, error: "Cliente no encontrado con esa cédula.")
                }
                let clienteId: Int64 = cli["id"]
                let nombre: String = cli["nombre"] ?? "—"

                let sus = try Row.fetchOne(dbc, sql: """
                    SELECT s.fecha_vencimiento AS venc, m.nombre_plan AS plan,
                           COALESCE(s.pagado,0) AS pagado, COALESCE(s.pendiente,0) AS pendiente
                    FROM suscripciones s
                    JOIN membresias m ON s.membresia_id = m.id
                    WHERE s.cliente_id = ?
                    ORDER BY s.fecha_vencimiento DESC LIMIT 1
                """, arguments: [clienteId])

                let ahora = Date()
                let hora = Fechas.horaStr(ahora)
                let fechaDisp = Fechas.displayStr(ahora)
                var r = ResultadoAsistencia(ok: true, nombre: nombre, cedula: ced, hora: hora, fecha: fechaDisp)

                if let sus {
                    let venc: String? = sus["venc"]
                    r.plan = sus["plan"] ?? "—"
                    r.vencimiento = venc ?? "—"
                    r.pendiente = sus["pendiente"]
                    let dias = venc.flatMap { Fechas.parse($0) }.map { Fechas.dias(desde: ahora, hasta: $0) } ?? -1
                    if dias < 0 {
                        r.estado = "VENCIDO"; r.alerta = "❌ Membresía VENCIDA hace \(abs(dias)) días."
                    } else if dias <= 5 {
                        r.estado = "POR VENCER"; r.alerta = "⚠️ Membresía vence en \(dias) días."
                    } else {
                        r.estado = "ACTIVO"; r.alerta = "✅ Activo — \(dias) días restantes."
                    }
                    if r.pendiente > 0 { r.alerta += "\n💳 Pago pendiente de \(r.pendiente.comoMoneda)" }
                } else {
                    r.estado = "SIN MEMBRESÍA"; r.alerta = "⚠️ No tiene membresía registrada."
                }

                try dbc.execute(sql: """
                    INSERT INTO asistencia(cliente_id, cedula, nombre, fecha, hora, estado, vencimiento)
                    VALUES (?,?,?,?,?,?,?)
                """, arguments: [clienteId, ced, nombre, Fechas.hoyStr(), hora, r.estado,
                                 r.vencimiento == "—" ? nil : r.vencimiento])
                return r
            }
        } catch {
            return ResultadoAsistencia(ok: false, error: "Error de base de datos: \(error.localizedDescription)")
        }
    }

    /// Historial de asistencias (hoy primero).
    func historial(limite: Int = 200) -> [Asistencia] {
        (try? db.reader.read { dbc in
            try Asistencia.fetchAll(dbc,
                sql: "SELECT * FROM asistencia ORDER BY id DESC LIMIT ?", arguments: [limite])
        }) ?? []
    }

    func historialDe(clienteId: Int64) -> [Asistencia] {
        (try? db.reader.read { dbc in
            try Asistencia.fetchAll(dbc,
                sql: "SELECT * FROM asistencia WHERE cliente_id = ? ORDER BY id DESC", arguments: [clienteId])
        }) ?? []
    }
}
