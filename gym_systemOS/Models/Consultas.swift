//
//  Consultas.swift
//  gym_systemOS
//
//  Modelos de solo lectura (JOINs) que replican las consultas de detalle
//  del sistema Python (suscripciones/pagos/caducados).
//

import Foundation
import GRDB

/// Detalle de una suscripción con cliente + plan. Reutilizado por los módulos
/// Suscripciones, Pagos y Clientes Caducados.
struct SuscripcionDetalle: Decodable, FetchableRecord, Identifiable, Hashable {
    var id: Int64            // id de la suscripción
    var clienteId: Int64
    var nombre: String
    var cedula: String
    var telefono: String
    var plan: String
    var fechaInicio: String?
    var fechaVencimiento: String?
    var precioTotal: Double
    var pagado: Double
    var pendiente: Double

    enum CodingKeys: String, CodingKey {
        case id
        case clienteId = "cliente_id"
        case nombre, cedula, telefono, plan
        case fechaInicio = "fecha_inicio"
        case fechaVencimiento = "fecha_vencimiento"
        case precioTotal = "precio_total"
        case pagado, pendiente
    }

    /// SELECT estándar con los JOINs; se le añade WHERE/ORDER según el módulo.
    static let selectBase = """
        SELECT s.id AS id, c.id AS cliente_id, c.nombre AS nombre,
               COALESCE(c.cedula,'') AS cedula, COALESCE(c.telefono,'') AS telefono,
               m.nombre_plan AS plan,
               s.fecha_inicio AS fecha_inicio, s.fecha_vencimiento AS fecha_vencimiento,
               COALESCE(s.precio_total,0) AS precio_total,
               COALESCE(s.pagado,0) AS pagado, COALESCE(s.pendiente,0) AS pendiente
        FROM suscripciones s
        JOIN clientes   c ON s.cliente_id   = c.id
        JOIN membresias m ON s.membresia_id = m.id
        """

    // MARK: - Estado / color (replica el color-coding del escritorio)

    var estaVencida: Bool {
        guard let v = Fechas.parse(fechaVencimiento) else { return false }
        return Fechas.dias(desde: Date(), hasta: v) < 0
    }

    /// Días restantes (negativo si ya venció).
    var diasRestantes: Int? {
        guard let v = Fechas.parse(fechaVencimiento) else { return nil }
        return Fechas.dias(desde: Date(), hasta: v)
    }

    /// Días transcurridos desde el vencimiento (para caducados).
    var diasVencido: Int? {
        guard let v = Fechas.parse(fechaVencimiento) else { return nil }
        return Fechas.dias(desde: v, hasta: Date())
    }
}
