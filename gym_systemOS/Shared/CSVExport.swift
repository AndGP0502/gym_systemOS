//
//  CSVExport.swift
//  gym_systemOS
//
//  Exportación de datos a CSV (abre en Excel/Numbers). Incluye BOM UTF-8 para
//  que los acentos se muestren bien en Excel.
//

import Foundation

enum CSVExport {
    private static let bom = "\u{FEFF}"

    private static func campo(_ v: String) -> String {
        // Entrecomilla si contiene coma, comilla o salto de línea.
        if v.contains(",") || v.contains("\"") || v.contains("\n") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }

    private static func fila(_ cols: [String]) -> String {
        cols.map(campo).joined(separator: ",") + "\n"
    }

    private static func doc(_ header: [String], _ filas: [[String]]) -> String {
        var s = bom + fila(header)
        for f in filas { s += fila(f) }
        return s
    }

    // MARK: - Documentos por entidad

    static func clientes(_ cs: [Cliente]) -> String {
        doc(["ID", "Nombre", "Cédula", "Teléfono", "Correo", "Fecha registro"],
            cs.map { [str($0.id), $0.nombre ?? "", $0.cedula ?? "", $0.telefono ?? "",
                      $0.correo ?? "", $0.fechaRegistro ?? ""] })
    }

    static func suscripciones(_ ds: [SuscripcionDetalle]) -> String {
        doc(["ID", "Cliente", "Cédula", "Plan", "Inicio", "Vencimiento",
             "Precio total", "Pagado", "Pendiente", "Estado"],
            ds.map { [String($0.id), $0.nombre, $0.cedula, $0.plan,
                      $0.fechaInicio ?? "", $0.fechaVencimiento ?? "",
                      money($0.precioTotal), money($0.pagado), money($0.pendiente),
                      $0.estaVencida ? "VENCIDA" : "ACTIVA"] })
    }

    private static func str(_ v: Int64?) -> String { v.map(String.init) ?? "" }
    private static func money(_ v: Double) -> String { String(format: "%.2f", v) }

    /// Escribe un CSV a un archivo temporal y devuelve su URL.
    static func archivo(_ contenido: String, nombre: String) -> URL? {
        TempFiles.escribir(Data(contenido.utf8), nombre: nombre)
    }
}
