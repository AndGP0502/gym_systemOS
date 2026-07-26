//
//  RootView.swift
//  gym_systemOS
//
//  Navegación principal estilo iPad (NavigationSplitView): barra lateral de
//  módulos + detalle. Cada módulo se implementa en su fase (ipad_port/RESUMEN.md).
//

import SwiftUI

enum Modulo: String, CaseIterable, Identifiable {
    case clientes      = "Clientes"
    case suscripciones = "Suscripciones"
    case pagos         = "Pagos"
    case caducados     = "Clientes Caducados"
    case facturacion   = "Facturación SRI"
    case configuracion = "Configuración"

    var id: String { rawValue }

    var icono: String {
        switch self {
        case .clientes:      return "person.2.fill"
        case .suscripciones: return "creditcard.fill"
        case .pagos:         return "dollarsign.circle.fill"
        case .caducados:     return "person.crop.circle.badge.exclamationmark"
        case .facturacion:   return "doc.text.fill"
        case .configuracion: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    @Environment(\.appDatabase) private var db
    @State private var seleccion: Modulo? = .clientes

    var body: some View {
        NavigationSplitView {
            List(Modulo.allCases, selection: $seleccion) { modulo in
                Label(modulo.rawValue, systemImage: modulo.icono)
                    .tag(modulo)
            }
            .navigationTitle("Gym System")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                detalle(for: seleccion)
            }
        }
    }

    @ViewBuilder
    private func detalle(for modulo: Modulo?) -> some View {
        switch modulo {
        case .clientes:
            ClientesView()
        case .suscripciones:
            SuscripcionesView()
        case .pagos:
            PagosView()
        case .caducados:
            CaducadosView()
        case .facturacion:
            PlaceholderModuloView(modulo: .facturacion)
        case .configuracion:
            PlaceholderModuloView(modulo: .configuracion)
        case .none:
            ContentUnavailableView("Selecciona un módulo",
                                   systemImage: "sidebar.left")
        }
    }
}

/// Placeholder temporal para módulos aún no implementados en esta fase.
struct PlaceholderModuloView: View {
    let modulo: Modulo
    var body: some View {
        ContentUnavailableView {
            Label(modulo.rawValue, systemImage: modulo.icono)
        } description: {
            Text("Módulo en construcción.")
        }
        .navigationTitle(modulo.rawValue)
    }
}
