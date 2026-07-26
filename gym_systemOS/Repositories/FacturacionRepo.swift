//
//  FacturacionRepo.swift
//  gym_systemOS
//
//  Persistencia de facturas y detalles. Port de guardar_factura / carga /
//  actualización de estado / eliminación de factura_service.py.
//

import Foundation
import GRDB

struct FacturacionRepo {
    let db: AppDatabase

    private static let estadosNoValidos = ["BORRADOR", "RECHAZADA", "ERROR", "NO AUTORIZADO", "PENDIENTE"]

    /// Inserta factura + detalles y reserva el secuencial actual (incrementa el
    /// contador). Devuelve (facturaId, secuencial reservado).
    func guardarFactura(_ factura: Factura, detalles: [FacturaDetalle]) -> (id: Int64, secuencial: Int)? {
        try? db.dbWriter.write { dbc -> (Int64, Int) in
            let sec = try Int.fetchOne(dbc,
                sql: "SELECT siguiente_secuencial FROM configuracion_sri WHERE id = 1") ?? 1

            var f = factura
            f.estado = "BORRADOR"
            f.secuencial = String(sec)
            try f.insert(dbc)
            let fid = dbc.lastInsertedRowID

            for d in detalles {
                var det = d
                det.facturaId = fid
                det.tieneIva = (d.porcentajeIva ?? 0) > 0 ? 1 : 0
                try det.insert(dbc)
            }

            try dbc.execute(sql: """
                UPDATE configuracion_sri SET siguiente_secuencial = siguiente_secuencial + 1 WHERE id = 1
            """)
            return (fid, sec)
        }
    }

    func cargarFactura(_ id: Int64) -> (factura: Factura, detalles: [FacturaDetalle])? {
        try? db.reader.read { dbc in
            guard let f = try Factura.fetchOne(dbc, sql: "SELECT * FROM facturas WHERE id = ?", arguments: [id]) else {
                return nil
            }
            let dets = try FacturaDetalle.fetchAll(dbc,
                sql: "SELECT * FROM factura_detalle WHERE factura_id = ?", arguments: [id])
            return (f, dets)
        } ?? nil
    }

    func actualizarEstado(_ id: Int64, estado: String, claveAcceso: String?) {
        try? db.dbWriter.write { dbc in
            try dbc.execute(sql: "UPDATE facturas SET estado=?, clave_acceso=? WHERE id=?",
                            arguments: [estado, claveAcceso, id])
        }
    }

    func actualizarAutorizada(_ id: Int64, claveAcceso: String, numeroAutorizacion: String,
                              fechaAutorizacion: String, estado: String,
                              rutaXml: String?, rutaXmlAutorizado: String?, secuencial: String) {
        try? db.dbWriter.write { dbc in
            try dbc.execute(sql: """
                UPDATE facturas SET clave_acceso=?, numero_autorizacion=?, fecha_autorizacion=?,
                    estado=?, ruta_xml=?, ruta_xml_autorizado=?, secuencial=? WHERE id=?
            """, arguments: [claveAcceso, numeroAutorizacion, fechaAutorizacion, estado,
                             rutaXml, rutaXmlAutorizado, secuencial, id])
        }
    }

    func verFacturas() -> [Factura] {
        (try? db.reader.read { dbc in
            try Factura.fetchAll(dbc, sql: "SELECT * FROM facturas ORDER BY id DESC")
        }) ?? []
    }

    func detalles(_ facturaId: Int64) -> [FacturaDetalle] {
        (try? db.reader.read { dbc in
            try FacturaDetalle.fetchAll(dbc,
                sql: "SELECT * FROM factura_detalle WHERE factura_id = ?", arguments: [facturaId])
        }) ?? []
    }

    /// No permite borrar facturas AUTORIZADAS (validez fiscal).
    func eliminarFactura(_ id: Int64, permitirAutorizada: Bool = false) -> OperationResult {
        do {
            return try db.dbWriter.write { dbc in
                guard let estado = try String.fetchOne(dbc,
                    sql: "SELECT estado FROM facturas WHERE id = ?", arguments: [id]) else {
                    return .fallo("La factura no existe.")
                }
                if estado.uppercased() == "AUTORIZADO" && !permitirAutorizada {
                    return .fallo("No se puede eliminar una factura AUTORIZADA. Es un comprobante válido ante el SRI; usa el proceso de anulación del SRI.")
                }
                try dbc.execute(sql: "DELETE FROM factura_detalle WHERE factura_id = ?", arguments: [id])
                try dbc.execute(sql: "DELETE FROM facturas WHERE id = ?", arguments: [id])
                return .exito("Factura eliminada.")
            }
        } catch { return .fallo("Error: \(error.localizedDescription)") }
    }
}
