//
//  FacturacionViewModel.swift
//  gym_systemOS
//

import Foundation
import SwiftUI
import Combine

/// Una línea del comprobante en el compositor.
struct LineaFactura: Identifiable {
    let id = UUID()
    var descripcion: String = ""
    var cantidad: Double = 1
    var precioUnitario: Double = 0
    var porcentajeIva: Double = 15   // 15 o 0
}

/// Datos del comprador para el compositor.
struct DatosComprador {
    var tipoIdentificacion = "05"        // 05 cédula, 04 RUC, 06 pasaporte, 07 consumidor final
    var identificacion = ""
    var razonSocial = ""
    var correo = ""
    var telefono = ""
    var direccion = ""
    var clienteId: Int64?
}

@MainActor
final class FacturacionViewModel: ObservableObject {
    @Published var facturas: [Factura] = []
    @Published var clientes: [Cliente] = []
    @Published var emitiendo = false
    @Published var progreso = ""
    @Published var mensaje: String?
    @Published var mostrarMensaje = false

    private var db: AppDatabase?
    private var facturaRepo: FacturacionRepo?
    private var clientesRepo: ClientesRepo?
    private var configRepo: ConfiguracionRepo?

    func setup(db: AppDatabase) {
        guard self.db == nil else { return }
        self.db = db
        facturaRepo = FacturacionRepo(db: db)
        clientesRepo = ClientesRepo(db: db)
        configRepo = ConfiguracionRepo(db: db)
        recargar()
    }

    func recargar() {
        facturas = facturaRepo?.verFacturas() ?? []
        clientes = clientesRepo?.ver() ?? []
    }

    var puedeEmitir: Bool {
        (configRepo?.obtener()) != nil && CertificateStore.hasCertificate()
    }

    /// Ensambla la factura (totales + datos del emisor) y la emite.
    func crearYEmitir(comprador: DatosComprador, lineas: [LineaFactura]) async {
        guard let facturaRepo, let db, let config = configRepo?.obtener() else {
            return notificar("Configura el emisor en Configuración antes de emitir.")
        }
        guard puedeEmitir else {
            return notificar("Configura el emisor y carga el certificado .p12 en Configuración antes de emitir.")
        }
        let validas = lineas.filter { !$0.descripcion.trimmingCharacters(in: .whitespaces).isEmpty && $0.cantidad > 0 }
        guard !validas.isEmpty else { return notificar("Agrega al menos una línea con descripción y cantidad.") }

        var detalles: [FacturaDetalle] = []
        var sub0 = 0.0, sub15 = 0.0, iva15 = 0.0
        for l in validas {
            let subtotal = l.cantidad * l.precioUnitario
            let iva = l.porcentajeIva == 15 ? subtotal * 0.15 : 0
            if l.porcentajeIva == 15 { sub15 += subtotal; iva15 += iva } else { sub0 += subtotal }
            detalles.append(FacturaDetalle(facturaId: nil, descripcion: l.descripcion,
                cantidad: l.cantidad, precioUnitario: l.precioUnitario, descuento: 0,
                tieneIva: l.porcentajeIva > 0 ? 1 : 0, porcentajeIva: l.porcentajeIva,
                subtotal: subtotal, iva: iva, total: subtotal + iva))
        }
        let total = sub0 + sub15 + iva15

        var factura = Factura()
        factura.fechaEmision = Fechas.hoyStr()
        factura.ambiente = config.ambiente
        factura.tipoIdentificacion = comprador.tipoIdentificacion
        factura.identificacion = comprador.identificacion
        factura.razonSocial = comprador.razonSocial
        factura.correo = comprador.correo
        factura.telefono = comprador.telefono
        factura.direccion = comprador.direccion
        factura.clienteId = comprador.clienteId
        factura.rucEmisor = config.ruc
        factura.razonSocialEmisor = config.razonSocial
        factura.establecimiento = config.codigoEstablecimiento
        factura.puntoEmision = config.puntoEmision
        factura.subtotal0 = sub0
        factura.subtotal15 = sub15
        factura.iva15 = iva15
        factura.descuentoTotal = 0
        factura.total = total

        guard let saved = facturaRepo.guardarFactura(factura, detalles: detalles) else {
            return notificar("No se pudo guardar la factura.")
        }
        recargar()
        await emitir(facturaId: saved.id, db: db)
    }

    /// Config actual (para el compositor: RUC del emisor, etc.).
    func configuracion() -> ConfiguracionSRI? { configRepo?.obtener() }

    func emitir(facturaId: Int64) async {
        guard let db else { return }
        await emitir(facturaId: facturaId, db: db)
    }

    private func emitir(facturaId: Int64, db: AppDatabase) async {
        emitiendo = true
        progreso = "Firmando y enviando al SRI…"
        let res = await FacturaService(db: db).procesar(facturaId: facturaId)
        emitiendo = false
        recargar()
        if res.ok {
            notificar("✅ AUTORIZADA. Autorización: \(res.numeroAutorizacion ?? "")")
        } else {
            notificar("Estado: \(res.estado). \(res.error ?? "")")
        }
    }

    func eliminar(_ f: Factura) {
        guard let id = f.id else { return }
        notificar(facturaRepo?.eliminarFactura(id).mensaje ?? "")
        recargar()
    }

    private func notificar(_ m: String) { mensaje = m; mostrarMensaje = true }
}
