//
//  RidePDF.swift
//  gym_systemOS
//
//  Generación del RIDE (Representación Impresa del Documento Electrónico) en PDF.
//  Adaptación nativa (PDFKit/UIKit) del generar_pdf_factura de facturacion_ui.py.
//

import Foundation
import UIKit

enum RidePDF {

    /// Genera el PDF del RIDE. Devuelve los bytes del PDF.
    static func generar(factura f: Factura, detalles: [FacturaDetalle], config: ConfiguracionSRI?) -> Data {
        let pageW: CGFloat = 595   // A4 @72dpi
        let pageH: CGFloat = 842
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            func draw(_ s: String, x: CGFloat, y yy: CGFloat, size: CGFloat = 10,
                      bold: Bool = false, color: UIColor = .black, width: CGFloat? = nil) {
                let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let rect = CGRect(x: x, y: yy, width: width ?? (pageW - x - margin), height: size + 6)
                (s as NSString).draw(in: rect, withAttributes: attrs)
            }

            // Encabezado emisor
            draw(config?.razonSocial ?? f.razonSocialEmisor ?? "EMISOR", x: margin, y: y, size: 16, bold: true)
            y += 22
            if let nc = config?.nombreComercial, !nc.isEmpty { draw(nc, x: margin, y: y, size: 11); y += 16 }
            draw("RUC: \(config?.ruc ?? f.rucEmisor ?? "")", x: margin, y: y); y += 14
            if let dir = config?.direccionMatriz, !dir.isEmpty { draw("Dir: \(dir)", x: margin, y: y); y += 14 }

            // Caja de comprobante (derecha)
            let boxX: CGFloat = pageW - margin - 230
            var by: CGFloat = margin
            UIColor.systemGray4.setStroke()
            let box = UIBezierPath(rect: CGRect(x: boxX, y: by, width: 230, height: 96)); box.lineWidth = 1; box.stroke()
            draw("FACTURA", x: boxX + 10, y: by + 6, size: 12, bold: true); by += 24
            let numero = "\(f.establecimiento ?? "001")-\(f.puntoEmision ?? "001")-\(leftPad(f.secuencial ?? "", 9))"
            draw("No. \(numero)", x: boxX + 10, y: by + 6, size: 11, bold: true); by += 20
            draw("Ambiente: \(f.ambiente == 2 ? "PRODUCCIÓN" : "PRUEBAS")", x: boxX + 10, y: by + 6, size: 9); by += 14
            draw("Fecha: \(f.fechaEmision ?? "")", x: boxX + 10, y: by + 6, size: 9); by += 14
            draw("Estado: \(f.estado ?? "BORRADOR")", x: boxX + 10, y: by + 6, size: 9,
                 color: (f.estado ?? "") == "AUTORIZADO" ? .systemGreen : .systemOrange)

            y = max(y, margin + 110)

            // Clave de acceso / autorización
            if let ac = f.claveAcceso, !ac.isEmpty {
                draw("Clave de acceso:", x: margin, y: y, size: 9, bold: true); y += 12
                draw(ac, x: margin, y: y, size: 8); y += 16
            }
            if let na = f.numeroAutorizacion, !na.isEmpty {
                draw("No. Autorización: \(na)", x: margin, y: y, size: 9); y += 14
            }
            y += 6

            // Comprador
            UIColor.systemGray6.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y, width: pageW - 2*margin, height: 44)).fill()
            draw("Cliente: \(f.razonSocial ?? "")", x: margin + 8, y: y + 6, size: 10, bold: true)
            draw("Identificación: \(f.identificacion ?? "")", x: margin + 8, y: y + 24, size: 9)
            y += 54

            // Tabla de detalles
            UIColor.systemGray5.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y, width: pageW - 2*margin, height: 20)).fill()
            draw("Descripción", x: margin + 6, y: y + 4, size: 9, bold: true, width: 250)
            draw("Cant.", x: margin + 270, y: y + 4, size: 9, bold: true, width: 50)
            draw("P.Unit", x: margin + 340, y: y + 4, size: 9, bold: true, width: 70)
            draw("Total", x: margin + 430, y: y + 4, size: 9, bold: true, width: 80)
            y += 22
            for d in detalles {
                draw(d.descripcion, x: margin + 6, y: y, size: 9, width: 250)
                draw(String(format: "%.2f", d.cantidad), x: margin + 270, y: y, size: 9, width: 50)
                draw(String(format: "%.2f", d.precioUnitario), x: margin + 340, y: y, size: 9, width: 70)
                draw(String(format: "%.2f", d.total), x: margin + 430, y: y, size: 9, width: 80)
                y += 16
                if y > pageH - 160 { ctx.beginPage(); y = margin }
            }
            y += 10

            // Totales
            let tx: CGFloat = pageW - margin - 200
            func tot(_ label: String, _ val: Double, bold: Bool = false) {
                draw(label, x: tx, y: y, size: 10, bold: bold, width: 120)
                draw(String(format: "$%.2f", val), x: tx + 120, y: y, size: 10, bold: bold, width: 80)
                y += 16
            }
            tot("Subtotal 0%", f.subtotal0 ?? 0)
            tot("Subtotal 15%", f.subtotal15 ?? 0)
            tot("IVA 15%", f.iva15 ?? 0)
            tot("VALOR TOTAL", f.total ?? 0, bold: true)

            // Pie
            draw("Documento generado por gym_systemOS · \(Fechas.displayStr())",
                 x: margin, y: pageH - margin, size: 8, color: .systemGray)
        }
    }

    private static func leftPad(_ s: String, _ n: Int) -> String {
        s.count >= n ? s : String(repeating: "0", count: n - s.count) + s
    }
}
