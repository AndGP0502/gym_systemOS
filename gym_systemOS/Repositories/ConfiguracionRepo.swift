//
//  ConfiguracionRepo.swift
//  gym_systemOS
//
//  Acceso a configuracion_sri (fila única id=1) + reserva atómica de secuencial.
//

import Foundation
import GRDB

struct ConfiguracionRepo {
    let db: AppDatabase

    func obtener() -> ConfiguracionSRI? {
        try? db.reader.read { dbc in
            try ConfiguracionSRI.fetchOne(dbc, sql: "SELECT * FROM configuracion_sri WHERE id = 1")
        }
    }

    func guardar(_ config: ConfiguracionSRI) -> OperationResult {
        do {
            try db.dbWriter.write { dbc in
                var c = config
                c.id = 1
                try c.save(dbc)   // upsert por PK
            }
            return .exito("Configuración guardada correctamente")
        } catch {
            return .fallo("Error al guardar configuración: \(error.localizedDescription)")
        }
    }

    /// Reserva el siguiente secuencial e incrementa el contador de forma atómica.
    /// Port de _reservar_siguiente_secuencial (usado en el reintento por error 45).
    func reservarSiguienteSecuencial() -> Int {
        (try? db.dbWriter.write { dbc -> Int in
            let actual = try Int.fetchOne(dbc,
                sql: "SELECT siguiente_secuencial FROM configuracion_sri WHERE id = 1") ?? 1
            try dbc.execute(sql: "UPDATE configuracion_sri SET siguiente_secuencial = ? WHERE id = 1",
                            arguments: [actual + 1])
            return actual
        }) ?? 1
    }
}
