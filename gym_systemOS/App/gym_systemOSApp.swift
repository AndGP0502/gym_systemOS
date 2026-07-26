//
//  gym_systemOSApp.swift
//  gym_systemOS
//
//  App nativa iPadOS — réplica local de gym_system (Python/tkinter).
//  Persistencia local con GRDB (SQLite embebido). Sin backend remoto.
//

import SwiftUI

@main
struct gym_systemOSApp: App {
    var body: some Scene {
        WindowGroup {
            // La apertura de la BD se resuelve una sola vez. Si falla, se muestra
            // el error en vez de un crash silencioso en el iPad del cliente.
            switch AppDatabase.bootstrapResult {
            case .success(let db):
                RootView()
                    .environment(\.appDatabase, db)
            case .failure(let error):
                StartupErrorView(message: error.localizedDescription)
            }
        }
    }
}

private struct StartupErrorView: View {
    let message: String
    var body: some View {
        ContentUnavailableView {
            Label("No se pudo abrir la base de datos", systemImage: "externaldrive.badge.xmark")
        } description: {
            Text(message)
        }
        .padding()
    }
}
