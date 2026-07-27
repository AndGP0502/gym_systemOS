//
//  FichaRepo.swift
//  gym_systemOS
//
//  Port de modulos/ficha_cliente.py: ficha del cliente (upsert), historial de
//  medidas con IMC y foto (guardada en el contenedor de la app).
//

import Foundation
import GRDB

struct FichaRepo {
    let db: AppDatabase

    // MARK: - Ficha

    func obtener(clienteId: Int64) -> FichaCliente? {
        try? db.reader.read { dbc in
            try FichaCliente.fetchOne(dbc,
                sql: "SELECT * FROM ficha_cliente WHERE cliente_id = ?", arguments: [clienteId])
        }
    }

    /// Guarda (upsert por cliente_id). Conserva la foto previa si no se envía una nueva.
    func guardar(_ ficha: FichaCliente) -> OperationResult {
        do {
            try db.dbWriter.write { dbc in
                var f = ficha
                if f.fotoRuta == nil,
                   let previa = try FichaCliente.fetchOne(dbc,
                        sql: "SELECT * FROM ficha_cliente WHERE cliente_id = ?", arguments: [f.clienteId]) {
                    f.fotoRuta = previa.fotoRuta
                    f.id = previa.id
                }
                // Upsert manual por cliente_id (UNIQUE)
                if let existente = try Int64.fetchOne(dbc,
                        sql: "SELECT id FROM ficha_cliente WHERE cliente_id = ?", arguments: [f.clienteId]) {
                    f.id = existente
                    try f.update(dbc)
                } else {
                    try f.insert(dbc)
                }
            }
            return .exito("Ficha guardada correctamente")
        } catch { return .fallo("Error al guardar ficha: \(error.localizedDescription)") }
    }

    // MARK: - Foto (en el contenedor de la app)

    private static var fotosDir: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL.temporaryDirectory
        let dir = base.appendingPathComponent("GymSystem/fotos_clientes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Guarda los bytes de la foto y devuelve la ruta absoluta.
    func guardarFoto(clienteId: Int64, data: Data, ext: String = "jpg") -> String? {
        let url = Self.fotosDir.appendingPathComponent("cliente_\(clienteId).\(ext)")
        do { try data.write(to: url); return url.path } catch { return nil }
    }

    func fotoData(clienteId: Int64) -> Data? {
        guard let ruta = obtener(clienteId: clienteId)?.fotoRuta else { return nil }
        return FileManager.default.contents(atPath: ruta)
    }

    // MARK: - Historial de medidas (IMC)

    /// Agrega una medida y calcula el IMC = peso / (altura_m)^2. Devuelve el IMC.
    @discardableResult
    func agregarMedida(clienteId: Int64, pesoKg: Double, alturaCm: Double, notas: String = "") -> Double {
        let imc = alturaCm > 0 ? (pesoKg / pow(alturaCm / 100, 2) * 100).rounded() / 100 : 0
        let fecha = Fechas.iso.string(from: Date()) // yyyy-MM-dd (el escritorio usa dd/MM/YYYY; aquí ISO)
        try? db.dbWriter.write { dbc in
            try dbc.execute(sql: """
                INSERT INTO historial_medidas(cliente_id, fecha, peso_kg, altura_cm, imc, notas)
                VALUES (?,?,?,?,?,?)
            """, arguments: [clienteId, fecha, pesoKg, alturaCm, imc, notas])
        }
        return imc
    }

    func historial(clienteId: Int64) -> [HistorialMedida] {
        (try? db.reader.read { dbc in
            try HistorialMedida.fetchAll(dbc, sql: """
                SELECT * FROM historial_medidas WHERE cliente_id = ? ORDER BY id DESC
            """, arguments: [clienteId])
        }) ?? []
    }

    @discardableResult
    func eliminarMedida(id: Int64) -> Bool {
        (try? db.dbWriter.write { dbc in
            try dbc.execute(sql: "DELETE FROM historial_medidas WHERE id = ?", arguments: [id])
        }) != nil
    }
}
