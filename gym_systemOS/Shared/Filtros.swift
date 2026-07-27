//
//  Filtros.swift
//  gym_systemOS
//
//  Filtros por condición usados en Suscripciones, Pagos y Clientes.
//

import Foundation

/// Filtro para listas de suscripciones (Suscripciones y Pagos).
enum FiltroSuscripcion: String, CaseIterable, Identifiable {
    case todas     = "Todas"
    case activas   = "Activas"
    case porVencer = "Por vencer"   // 0–5 días restantes
    case vencidas  = "Vencidas"
    case pagadas   = "Pagadas"
    case porPagar  = "Por pagar"    // pago parcial
    case deuda     = "Deuda"        // nada pagado

    var id: String { rawValue }
    var icono: String {
        switch self {
        case .todas: return "line.3.horizontal.decrease.circle"
        case .activas: return "checkmark.seal"
        case .porVencer: return "clock.badge.exclamationmark"
        case .vencidas: return "xmark.seal"
        case .pagadas: return "dollarsign.circle"
        case .porPagar: return "hourglass"
        case .deuda: return "exclamationmark.triangle"
        }
    }

    func incluye(_ s: SuscripcionDetalle) -> Bool {
        switch self {
        case .todas:     return true
        case .activas:   return !s.estaVencida
        case .porVencer: if let d = s.diasRestantes { return d >= 0 && d <= 5 }; return false
        case .vencidas:  return s.estaVencida
        case .pagadas:   return s.pendiente <= 0 && s.pagado > 0
        case .porPagar:  return s.pagado > 0 && s.pendiente > 0
        case .deuda:     return s.pagado <= 0
        }
    }
}

/// Filtro para la lista de clientes (según el estado de su suscripción).
enum FiltroCliente: String, CaseIterable, Identifiable {
    case todos    = "Todos"
    case activos  = "Activos"
    case vencidos = "Vencidos"
    case conDeuda = "Con deuda"

    var id: String { rawValue }
    var icono: String {
        switch self {
        case .todos: return "person.3"
        case .activos: return "checkmark.seal"
        case .vencidos: return "xmark.seal"
        case .conDeuda: return "exclamationmark.triangle"
        }
    }
}
