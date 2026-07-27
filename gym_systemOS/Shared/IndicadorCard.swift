//
//  IndicadorCard.swift
//  gym_systemOS
//
//  Tarjeta indicadora reutilizable (contadores de módulos).
//

import SwiftUI

struct IndicadorCard: View {
    let titulo: String
    let valor: String
    let color: Color
    var icono: String = "circle.fill"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icono).font(.title3).foregroundStyle(.white)
                .frame(width: 38, height: 38).background(color, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(valor).font(.title3).bold()
                Text(titulo).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
