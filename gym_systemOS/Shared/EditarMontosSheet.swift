//
//  EditarMontosSheet.swift
//  gym_systemOS
//
//  Hoja reutilizable para editar directamente los montos de una suscripción:
//  precio total y pagado. El pendiente se muestra recalculado en vivo.
//

import SwiftUI

struct EditarMontosSheet: View {
    let titulo: String
    let onGuardar: (Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var precioText: String
    @State private var pagadoText: String

    init(titulo: String, precioTotal: Double, pagado: Double,
         onGuardar: @escaping (Double, Double) -> Void) {
        self.titulo = titulo
        self.onGuardar = onGuardar
        _precioText = State(initialValue: String(format: "%.2f", precioTotal))
        _pagadoText = State(initialValue: String(format: "%.2f", pagado))
    }

    private var precio: Double { Double(precioText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var pagado: Double { Double(pagadoText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var pendiente: Double { max(0, precio - pagado) }

    var body: some View {
        NavigationStack {
            Form {
                Section(titulo) {
                    CampoNumero(titulo: "Precio total ($)", ejemplo: "30", texto: $precioText)
                    CampoNumero(titulo: "Pagado ($)", ejemplo: "0", texto: $pagadoText)
                    LabeledContent("Restante (pendiente)", value: pendiente.comoMoneda)
                        .foregroundStyle(pendiente > 0 ? .red : .green)
                }
            }
            .navigationTitle("Editar montos").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { onGuardar(precio, pagado); dismiss() }
                }
            }
        }
    }
}
