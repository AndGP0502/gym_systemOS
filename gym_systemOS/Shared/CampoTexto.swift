//
//  CampoTexto.swift
//  gym_systemOS
//
//  Campo de formulario con ETIQUETA visible y legible + ejemplo de ayuda.
//  Evita depender solo del placeholder (que se ve muy tenue).
//

import SwiftUI

struct CampoTexto: View {
    let titulo: String
    var ejemplo: String = ""
    @Binding var texto: String
    var keyboard: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            TextField(ejemplo, text: $texto)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}

/// Campo numérico con etiqueta visible.
struct CampoNumero: View {
    let titulo: String
    var ejemplo: String = "0"
    @Binding var texto: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.footnote.weight(.semibold)).foregroundStyle(.primary)
            TextField(ejemplo, text: $texto).keyboardType(.decimalPad).font(.body)
        }
        .padding(.vertical, 2)
    }
}
