//
//  EstadoColor.swift
//  gym_systemOS
//
//  Paleta de color-coding replicando EXACTAMENTE la del escritorio
//  (ui/pagos_ui.py y modulos/caducados.py). Ver ipad_port/AUDIT.md §2.5–2.6.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8) / 255
        let b = Double(v & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

/// Estilo (fondo + texto) de una fila, equivalente a un `tag` del Treeview tkinter.
struct EstiloFila {
    let fondo: Color
    let texto: Color
    let etiqueta: String
}

/// Color-coding de PAGOS (prioridad: vencido > estado de pago).
enum EstadoPago {
    /// - Parameters: pendiente y si la suscripción está vencida.
    static func estilo(pagado: Double, pendiente: Double, vencida: Bool) -> EstiloFila {
        if vencida {
            return EstiloFila(fondo: Color(hex: "f5b7b1"), texto: Color(hex: "641e16"), etiqueta: "Vencido")
        }
        if pendiente <= 0 && pagado > 0 {
            return EstiloFila(fondo: Color(hex: "b6f2c6"), texto: Color(hex: "0f5132"), etiqueta: "Pagado")
        }
        if pagado <= 0 {
            return EstiloFila(fondo: Color(hex: "f8d7da"), texto: Color(hex: "842029"), etiqueta: "Deuda")
        }
        return EstiloFila(fondo: Color(hex: "fff3cd"), texto: Color(hex: "664d03"), etiqueta: "Parcial")
    }
}

/// Color-coding de CLIENTES CADUCADOS según antigüedad del vencimiento.
enum EstadoCaducado {
    static func estilo(diasVencido: Int?) -> EstiloFila {
        guard let d = diasVencido else {
            return EstiloFila(fondo: Color(hex: "f8d7da"), texto: Color(hex: "842029"), etiqueta: "Vencido")
        }
        if d <= 7 {
            return EstiloFila(fondo: Color(hex: "fff3cd"), texto: Color(hex: "664d03"), etiqueta: "Reciente (≤7 días)")
        } else if d <= 30 {
            return EstiloFila(fondo: Color(hex: "f8d7da"), texto: Color(hex: "842029"), etiqueta: "Vencido (8–30 días)")
        } else {
            return EstiloFila(fondo: Color(hex: "f5b7b1"), texto: Color(hex: "641e16"), etiqueta: "Antiguo (>30 días)")
        }
    }
}
