//
//  Bindings.swift
//  gym_systemOS
//

import SwiftUI

extension Binding where Value == String? {
    /// Convierte un Binding<String?> en Binding<String> (nil → "").
    func orEmpty() -> Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
