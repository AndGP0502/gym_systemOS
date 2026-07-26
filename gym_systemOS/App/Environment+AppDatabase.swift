//
//  Environment+AppDatabase.swift
//  gym_systemOS
//
//  Inyección de la base de datos en el Environment de SwiftUI.
//

import SwiftUI

private struct AppDatabaseKey: EnvironmentKey {
    static let defaultValue: AppDatabase = .empty()
}

extension EnvironmentValues {
    var appDatabase: AppDatabase {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}
