//
//  RootView.swift
//  gym_systemOS
//
//  Navegación principal estilo iPad (NavigationSplitView): barra lateral de
//  módulos + detalle. Ancho de la barra ajustado para una estética equilibrada.
//

import SwiftUI

enum Modulo: String, CaseIterable, Identifiable {
    case inicio        = "Inicio"
    case clientes      = "Clientes"
    case asistencia    = "Asistencia"
    case planes        = "Planes"
    case suscripciones = "Suscripciones"
    case pagos         = "Pagos"
    case caducados     = "Clientes Caducados"
    case facturacion   = "Facturación SRI"
    case configuracion = "Configuración"

    var id: String { rawValue }

    var icono: String {
        switch self {
        case .inicio:        return "house.fill"
        case .clientes:      return "person.2.fill"
        case .asistencia:    return "figure.walk.circle.fill"
        case .planes:        return "list.bullet.rectangle.fill"
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
    @State private var seleccion: Modulo? = .inicio
    @State private var columnas: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnas) {
            List(Modulo.allCases, selection: $seleccion) { modulo in
                Label(modulo.rawValue, systemImage: modulo.icono)
                    .font(.body)
                    .padding(.vertical, 2)
                    .tag(modulo)
            }
            .navigationTitle("Gym System")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 240, ideal: 275, max: 320)
        } detail: {
            NavigationStack {
                detalle(for: seleccion)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func detalle(for modulo: Modulo?) -> some View {
        switch modulo {
        case .inicio:        DashboardView()
        case .clientes:      ClientesView()
        case .asistencia:    AsistenciaView()
        case .planes:        PlanesView()
        case .suscripciones: SuscripcionesView()
        case .pagos:         PagosView()
        case .caducados:     CaducadosView()
        case .facturacion:   FacturacionView()
        case .configuracion: ConfiguracionView()
        case .none:
            ContentUnavailableView("Selecciona un módulo", systemImage: "sidebar.left")
        }
    }
}
