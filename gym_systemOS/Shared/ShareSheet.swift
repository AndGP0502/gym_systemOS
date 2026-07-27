//
//  ShareSheet.swift
//  gym_systemOS
//
//  Envoltorio de UIActivityViewController para compartir/imprimir archivos
//  (RIDE PDF, exportación de la base de datos).
//

import SwiftUI
import UIKit

/// URL identificable para presentar hojas con `.sheet(item:)`.
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

enum TempFiles {
    /// Escribe datos a un archivo temporal con el nombre dado y devuelve su URL.
    static func escribir(_ data: Data, nombre: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        do { try data.write(to: url); return url } catch { return nil }
    }
}
