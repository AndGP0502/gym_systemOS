//
//  Support.swift
//  gym_systemOS
//
//  Utilidades compartidas: formato de fechas y resultado de operaciones,
//  replicando el comportamiento del sistema de escritorio (Python).
//

import Foundation

/// Resultado de una operación de negocio (equivale a los strings de retorno
/// de las funciones Python como `agregar_cliente`).
struct OperationResult {
    let ok: Bool
    let mensaje: String

    static func exito(_ m: String) -> OperationResult { .init(ok: true, mensaje: m) }
    static func fallo(_ m: String) -> OperationResult { .init(ok: false, mensaje: m) }
}

/// Formatos de fecha usados en la BD (todas las fechas se guardan como TEXT
/// `yyyy-MM-dd`, igual que el sistema Python).
enum Fechas {
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Guayaquil") // Ecuador UTC-5
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Hoy en formato `yyyy-MM-dd` (hora de Ecuador).
    static func hoyStr() -> String { iso.string(from: Date()) }

    /// Parsea `yyyy-MM-dd`. Devuelve nil si no coincide.
    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return iso.date(from: s)
    }

    /// Días entre `desde` y `hasta` (redondeo por días de calendario).
    static func dias(desde: Date, hasta: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let d0 = cal.startOfDay(for: desde)
        let d1 = cal.startOfDay(for: hasta)
        return cal.dateComponents([.day], from: d0, to: d1).day ?? 0
    }

    /// Suma días a una fecha en formato `yyyy-MM-dd`, devuelve string.
    static func sumarDias(_ fechaStr: String, _ dias: Int) -> String? {
        guard let d = parse(fechaStr) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        guard let nueva = cal.date(byAdding: .day, value: dias, to: d) else { return nil }
        return iso.string(from: nueva)
    }
}

/// Formato de moneda tipo `$0.00` (como en las tablas del escritorio).
extension Double {
    var comoMoneda: String { String(format: "$%.2f", self) }
}
