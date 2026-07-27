//
//  FichaPDF.swift
//  gym_systemOS
//
//  PDF con la información completa de un cliente: datos, ficha física/médica y
//  el historial de medidas (IMC). Port de generar_pdf_ficha_cliente.
//

import Foundation
import UIKit

enum FichaPDF {

    static func generar(cliente: Cliente, ficha: FichaCliente?, historial: [HistorialMedida],
                        foto: Data?) -> Data {
        let pageW: CGFloat = 595, pageH: CGFloat = 842, margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            func draw(_ s: String, x: CGFloat, size: CGFloat = 11, bold: Bool = false,
                      color: UIColor = .black, w: CGFloat? = nil) {
                let f = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                (s as NSString).draw(in: CGRect(x: x, y: y, width: w ?? (pageW - x - margin), height: size + 8),
                                     withAttributes: [.font: f, .foregroundColor: color])
            }
            func salto(_ h: CGFloat = 18) { y += h; if y > pageH - 60 { ctx.beginPage(); y = margin } }

            // Título + foto
            draw("Ficha del cliente", x: margin, size: 20, bold: true)
            if let foto, let img = UIImage(data: foto) {
                let side: CGFloat = 90
                img.draw(in: CGRect(x: pageW - margin - side, y: margin, width: side, height: side))
            }
            salto(30)
            draw(cliente.nombre ?? "—", x: margin, size: 15, bold: true); salto(20)
            draw("Cédula: \(cliente.cedula ?? "—")    Teléfono: \(cliente.telefono ?? "—")", x: margin); salto()
            draw("Correo: \(cliente.correo ?? "—")", x: margin); salto(24)

            // Ficha física/médica
            draw("Datos físicos y objetivos", x: margin, size: 13, bold: true, color: .systemBlue); salto(20)
            if let f = ficha {
                let pares: [(String, String?)] = [
                    ("Objetivo", f.objetivo), ("Objetivo secundario", f.objetivo2),
                    ("Estado físico", f.estadoFisico), ("Status físico", f.statusFisico),
                    ("Peso (kg)", f.pesoKg.map { String($0) }), ("Altura (m)", f.alturaM.map { String($0) }),
                    ("Cir. abdominal (cm)", f.cirAbdominal.map { String($0) }), ("Peso ideal (kg)", f.pesoIdeal.map { String($0) }),
                    ("Condiciones", f.condiciones), ("Lesión", f.lesion),
                    ("Cardiovascular", f.cardiovascular), ("Asfixia", f.asfixia),
                    ("Asmático", f.asmatico), ("Medicación", f.medicacion),
                    ("Mareos", f.mareos), ("Notas", f.notas),
                ]
                for (k, v) in pares where !(v ?? "").isEmpty {
                    draw("\(k):", x: margin, bold: true, w: 150)
                    draw(v ?? "", x: margin + 155)
                    salto(16)
                }
            } else {
                draw("Sin ficha registrada.", x: margin, color: .systemGray); salto()
            }
            salto(10)

            // Historial de medidas
            draw("Historial de medidas (IMC)", x: margin, size: 13, bold: true, color: .systemBlue); salto(20)
            if historial.isEmpty {
                draw("Sin medidas registradas.", x: margin, color: .systemGray); salto()
            } else {
                draw("Fecha", x: margin, bold: true, w: 110)
                draw("Peso", x: margin + 120, bold: true, w: 70)
                draw("Altura", x: margin + 200, bold: true, w: 70)
                draw("IMC", x: margin + 280, bold: true, w: 70)
                salto(16)
                for m in historial {
                    draw(m.fecha ?? "—", x: margin, w: 110)
                    draw(String(format: "%.1f kg", m.pesoKg ?? 0), x: margin + 120, w: 70)
                    draw(String(format: "%.0f cm", m.alturaCm ?? 0), x: margin + 200, w: 70)
                    draw(String(format: "%.1f", m.imc ?? 0), x: margin + 280, w: 70)
                    salto(15)
                }
            }

            draw("Generado por gym_systemOS · \(Fechas.displayStr())", x: margin,
                 size: 8, color: .systemGray)
        }
    }
}
