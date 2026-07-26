//
//  FacturaModels.swift
//  gym_systemOS
//
//  Registros GRDB de facturación SRI (ipad_port/AUDIT.md §1.2).
//

import Foundation
import GRDB

// MARK: - ConfiguracionSRI (fila única id=1)

struct ConfiguracionSRI: Codable, FetchableRecord, PersistableRecord, Hashable {
    var id: Int64 = 1
    var ruc: String
    var razonSocial: String
    var nombreComercial: String?
    var direccionMatriz: String?
    var direccionSucursal: String?
    var codigoEstablecimiento: String?
    var puntoEmision: String?
    var ambiente: Int?
    var tipoEmision: Int?
    var rutaCertificado: String?
    var claveCertificado: String?
    var siguienteSecuencial: Int?
    var correoRemitente: String?
    var smtpHost: String?
    var smtpPort: Int?
    var smtpUsuario: String?
    var smtpClave: String?
    var rutaXmls: String?
    var rutaRides: String?
    var claveSri: String?
    var apellidoPaterno: String?
    var apellidoMaterno: String?
    var primerNombre: String?
    var segundoNombre: String?
    var correoElectronico: String?
    var telefonoConv: String?
    var telefonoCelular: String?
    var direccionDomicilio: String?

    static let databaseTableName = "configuracion_sri"

    enum CodingKeys: String, CodingKey {
        case id, ruc
        case razonSocial = "razon_social"
        case nombreComercial = "nombre_comercial"
        case direccionMatriz = "direccion_matriz"
        case direccionSucursal = "direccion_sucursal"
        case codigoEstablecimiento = "codigo_establecimiento"
        case puntoEmision = "punto_emision"
        case ambiente
        case tipoEmision = "tipo_emision"
        case rutaCertificado = "ruta_certificado"
        case claveCertificado = "clave_certificado"
        case siguienteSecuencial = "siguiente_secuencial"
        case correoRemitente = "correo_remitente"
        case smtpHost = "smtp_host"
        case smtpPort = "smtp_port"
        case smtpUsuario = "smtp_usuario"
        case smtpClave = "smtp_clave"
        case rutaXmls = "ruta_xmls"
        case rutaRides = "ruta_rides"
        case claveSri = "clave_sri"
        case apellidoPaterno = "apellido_paterno"
        case apellidoMaterno = "apellido_materno"
        case primerNombre = "primer_nombre"
        case segundoNombre = "segundo_nombre"
        case correoElectronico = "correo_electronico"
        case telefonoConv = "telefono_conv"
        case telefonoCelular = "telefono_celular"
        case direccionDomicilio = "direccion_domicilio"
    }

    /// Constructor por defecto para la pantalla de configuración inicial.
    static func nueva() -> ConfiguracionSRI {
        ConfiguracionSRI(
            id: 1, ruc: "", razonSocial: "",
            codigoEstablecimiento: "001", puntoEmision: "001",
            ambiente: 1, tipoEmision: 1, siguienteSecuencial: 1, smtpPort: 587
        )
    }
}

// MARK: - Factura

struct Factura: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64? = nil
    var claveAcceso: String? = nil
    var numeroAutorizacion: String? = nil
    var estado: String? = nil
    var ambiente: Int? = nil
    var fechaEmision: String? = nil
    var fechaAutorizacion: String? = nil
    var rucEmisor: String? = nil
    var razonSocialEmisor: String? = nil
    var tipoIdentificacion: String? = nil
    var identificacion: String? = nil
    var razonSocial: String? = nil
    var correo: String? = nil
    var telefono: String? = nil
    var direccion: String? = nil
    var subtotal0: Double? = nil
    var subtotal15: Double? = nil
    var subtotalNoIva: Double? = nil
    var descuentoTotal: Double? = nil
    var iva15: Double? = nil
    var total: Double? = nil
    var establecimiento: String? = nil
    var puntoEmision: String? = nil
    var secuencial: String? = nil
    var rutaXml: String? = nil
    var rutaXmlAutorizado: String? = nil
    var rutaRide: String? = nil
    var clienteId: Int64? = nil
    var observacion: String? = nil

    static let databaseTableName = "facturas"

    enum CodingKeys: String, CodingKey {
        case id
        case claveAcceso = "clave_acceso"
        case numeroAutorizacion = "numero_autorizacion"
        case estado, ambiente
        case fechaEmision = "fecha_emision"
        case fechaAutorizacion = "fecha_autorizacion"
        case rucEmisor = "ruc_emisor"
        case razonSocialEmisor = "razon_social_emisor"
        case tipoIdentificacion = "tipo_identificacion"
        case identificacion
        case razonSocial = "razon_social"
        case correo, telefono, direccion
        case subtotal0 = "subtotal_0"
        case subtotal15 = "subtotal_15"
        case subtotalNoIva = "subtotal_no_iva"
        case descuentoTotal = "descuento_total"
        case iva15 = "iva_15"
        case total, establecimiento
        case puntoEmision = "punto_emision"
        case secuencial
        case rutaXml = "ruta_xml"
        case rutaXmlAutorizado = "ruta_xml_autorizado"
        case rutaRide = "ruta_ride"
        case clienteId = "cliente_id"
        case observacion
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

// MARK: - FacturaDetalle

struct FacturaDetalle: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable {
    var id: Int64?
    var facturaId: Int64?
    var descripcion: String
    var cantidad: Double
    var precioUnitario: Double
    var descuento: Double?
    var tieneIva: Int?
    var porcentajeIva: Double?
    var subtotal: Double
    var iva: Double
    var total: Double

    static let databaseTableName = "factura_detalle"

    enum CodingKeys: String, CodingKey {
        case id
        case facturaId = "factura_id"
        case descripcion, cantidad
        case precioUnitario = "precio_unitario"
        case descuento
        case tieneIva = "tiene_iva"
        case porcentajeIva = "porcentaje_iva"
        case subtotal, iva, total
    }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
