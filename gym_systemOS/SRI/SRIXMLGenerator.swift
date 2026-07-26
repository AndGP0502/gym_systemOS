//
//  SRIXMLGenerator.swift
//  gym_systemOS
//
//  Port 1:1 de sri/xml_generator.py: comprobante `factura` v2.1.0, clave de
//  acceso de 49 dígitos con dígito verificador módulo 11.
//

import Foundation

enum SRIXMLGenerator {

    struct Resultado { let xml: String; let claveAcceso: String; let secuencial: String }

    static func generar(config: ConfiguracionSRI, factura: Factura,
                        detalles: [FacturaDetalle], secuencial: Int) -> Resultado {
        let fecha = factura.fechaEmision ?? Fechas.hoyStr()
        let secStr = String(format: "%09d", secuencial)
        let serie = (config.codigoEstablecimiento ?? "001") + (config.puntoEmision ?? "001")
        let codigoNumerico = codigo8()
        let ambiente = config.ambiente ?? 2
        let tipoEmision = config.tipoEmision ?? 1

        let claveAcceso = claveDeAcceso(fecha: fecha, tipoComprobante: "01", ruc: config.ruc,
                                        ambiente: ambiente, serie: serie, secuencial: secStr,
                                        codigoNumerico: codigoNumerico, tipoEmision: tipoEmision)
        let fechaFmt = fechaDDMMYYYY(fecha)

        let subtotal0  = detalles.filter { ($0.porcentajeIva ?? 15) == 0 }.reduce(0) { $0 + $1.subtotal }
        let subtotal15 = detalles.filter { ($0.porcentajeIva ?? 15) == 15 }.reduce(0) { $0 + $1.subtotal }
        let iva15      = detalles.filter { ($0.porcentajeIva ?? 15) == 15 }.reduce(0) { $0 + $1.iva }
        let descuento  = detalles.reduce(0.0) { $0 + ($1.descuento ?? 0) * $1.cantidad }
        let total      = subtotal0 + subtotal15 + iva15

        var totalImpuestos = ""
        if subtotal0 > 0 {
            totalImpuestos += "<totalImpuesto><codigo>2</codigo><codigoPorcentaje>0</codigoPorcentaje>"
                + "<baseImponible>\(f2(subtotal0))</baseImponible><valor>0.00</valor></totalImpuesto>"
        }
        if subtotal15 > 0 {
            totalImpuestos += "<totalImpuesto><codigo>2</codigo><codigoPorcentaje>4</codigoPorcentaje>"
                + "<baseImponible>\(f2(subtotal15))</baseImponible><tarifa>15.00</tarifa>"
                + "<valor>\(f2(iva15))</valor></totalImpuesto>"
        }

        var detallesXML = ""
        for d in detalles {
            let pct = d.porcentajeIva ?? 15
            let codIva = pct == 15 ? "4" : "0"
            detallesXML += "<detalle>"
                + "<codigoPrincipal>SRV</codigoPrincipal>"
                + "<descripcion>\(txt(d.descripcion))</descripcion>"
                + "<cantidad>\(f2(d.cantidad))</cantidad>"
                + "<precioUnitario>\(f2(d.precioUnitario))</precioUnitario>"
                + "<descuento>\(f2((d.descuento ?? 0) * d.cantidad))</descuento>"
                + "<precioTotalSinImpuesto>\(f2(d.subtotal))</precioTotalSinImpuesto>"
                + "<impuestos><impuesto>"
                + "<codigo>2</codigo><codigoPorcentaje>\(codIva)</codigoPorcentaje>"
                + "<tarifa>\(f2(pct))</tarifa><baseImponible>\(f2(d.subtotal))</baseImponible>"
                + "<valor>\(f2(d.iva))</valor>"
                + "</impuesto></impuestos>"
                + "</detalle>"
        }

        let nombreComercial = (config.nombreComercial?.isEmpty == false ? config.nombreComercial! : config.razonSocial)
        let dirEstab = (config.direccionSucursal?.isEmpty == false ? config.direccionSucursal! : (config.direccionMatriz ?? "N/A"))

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>\
        <factura id="comprobante" version="2.1.0">\
        <infoTributaria>\
        <ambiente>\(ambiente)</ambiente>\
        <tipoEmision>\(tipoEmision)</tipoEmision>\
        <razonSocial>\(txt(config.razonSocial))</razonSocial>\
        <nombreComercial>\(txt(nombreComercial))</nombreComercial>\
        <ruc>\(config.ruc)</ruc>\
        <claveAcceso>\(claveAcceso)</claveAcceso>\
        <codDoc>01</codDoc>\
        <estab>\(config.codigoEstablecimiento ?? "001")</estab>\
        <ptoEmi>\(config.puntoEmision ?? "001")</ptoEmi>\
        <secuencial>\(secStr)</secuencial>\
        <dirMatriz>\(txt(config.direccionMatriz ?? ""))</dirMatriz>\
        </infoTributaria>\
        <infoFactura>\
        <fechaEmision>\(fechaFmt)</fechaEmision>\
        <dirEstablecimiento>\(txt(dirEstab))</dirEstablecimiento>\
        <obligadoContabilidad>NO</obligadoContabilidad>\
        <tipoIdentificacionComprador>\(factura.tipoIdentificacion ?? "05")</tipoIdentificacionComprador>\
        <razonSocialComprador>\(txt(factura.razonSocial ?? ""))</razonSocialComprador>\
        <identificacionComprador>\(factura.identificacion ?? "")</identificacionComprador>\
        <direccionComprador>\(txt(factura.direccion ?? "N/A"))</direccionComprador>\
        <totalSinImpuestos>\(f2(subtotal0 + subtotal15))</totalSinImpuestos>\
        <totalDescuento>\(f2(descuento))</totalDescuento>\
        <totalConImpuestos>\(totalImpuestos)</totalConImpuestos>\
        <propina>0.00</propina>\
        <importeTotal>\(f2(total))</importeTotal>\
        <moneda>DOLAR</moneda>\
        <pagos><pago><formaPago>01</formaPago><total>\(f2(total))</total><plazo>0</plazo><unidadTiempo>dias</unidadTiempo></pago></pagos>\
        </infoFactura>\
        <detalles>\(detallesXML)</detalles>\
        <infoAdicional>\
        <campoAdicional nombre="Telefono">\(txt(factura.telefono ?? "N/A"))</campoAdicional>\
        <campoAdicional nombre="Email">\(txt(factura.correo ?? "N/A"))</campoAdicional>\
        </infoAdicional>\
        </factura>
        """
        return Resultado(xml: xml, claveAcceso: claveAcceso, secuencial: secStr)
    }

    // MARK: - Clave de acceso + módulo 11

    static func claveDeAcceso(fecha: String, tipoComprobante: String, ruc: String,
                              ambiente: Int, serie: String, secuencial: String,
                              codigoNumerico: String, tipoEmision: Int) -> String {
        let fechaFmt = fechaDDMMYYYY_num(fecha)   // ddMMyyyy
        let clave = "\(fechaFmt)\(tipoComprobante)\(ruc)\(ambiente)\(serie)\(secuencial)\(codigoNumerico)\(tipoEmision)"
        return clave + String(modulo11(clave))
    }

    static func modulo11(_ clave: String) -> Int {
        let factores = [2, 3, 4, 5, 6, 7]
        var suma = 0
        var idx = 0
        for ch in clave.reversed() {
            guard let d = ch.wholeNumberValue else { continue }
            suma += d * factores[idx % 6]
            idx += 1
        }
        let residuo = suma % 11
        if residuo == 0 { return 0 }
        if residuo == 1 { return 1 }
        return 11 - residuo
    }

    // MARK: - Helpers

    private static func f2(_ v: Double) -> String { String(format: "%.2f", v) }

    private static func codigo8() -> String {
        var s = ""
        for _ in 0..<8 { s += String(Int.random(in: 0...9)) }
        return s
    }

    /// Escapa &, <, > (equivale a xml.sax.saxutils.escape) y hace strip.
    private static func txt(_ v: String?) -> String {
        guard let v else { return "" }
        return v.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// `yyyy-MM-dd` → `dd/MM/yyyy`.
    private static func fechaDDMMYYYY(_ s: String) -> String {
        let p = s.split(separator: "-")
        guard p.count == 3 else { return s }
        return "\(p[2])/\(p[1])/\(p[0])"
    }

    /// `yyyy-MM-dd` → `ddMMyyyy`.
    private static func fechaDDMMYYYY_num(_ s: String) -> String {
        let p = s.split(separator: "-")
        guard p.count == 3 else { return s }
        return "\(p[2])\(p[1])\(p[0])"
    }
}
