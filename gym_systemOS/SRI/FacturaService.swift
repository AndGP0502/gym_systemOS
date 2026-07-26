//
//  FacturaService.swift
//  gym_systemOS
//
//  Orquestador de emisión SRI — port de services/factura_service.py
//  (procesar_factura_completa): XML → firma XAdES → recepción SOAP → polling de
//  autorización (8×4s) → reintento de secuencial ante error 45 (máx 5).
//

import Foundation

struct FacturaService {
    let db: AppDatabase

    struct Resultado {
        let ok: Bool
        let estado: String
        let claveAcceso: String?
        let numeroAutorizacion: String?
        let error: String?
    }

    private static let MAX_REINTENTOS_SECUENCIAL = 5
    private static let estadosPendientes: Set<String> = ["PENDIENTE", "EN PROCESO", "PROCESANDO", "ERROR"]

    func procesar(facturaId: Int64) async -> Resultado {
        let configRepo = ConfiguracionRepo(db: db)
        let facturaRepo = FacturacionRepo(db: db)

        guard let config = configRepo.obtener() else {
            return fail("No hay configuración SRI guardada.")
        }
        let cert: LoadedCertificate
        do { cert = try CertificateStore.loadStored() }
        catch { return fail(error.localizedDescription) }

        guard let (facturaBase, detalles) = facturaRepo.cargarFactura(facturaId) else {
            return fail("La factura no existe.")
        }
        var factura = facturaBase
        let ambiente = config.ambiente ?? 1
        let dirXmls = carpetaXMLs(config: config)

        var intentoSec = 0
        while true {
            let secuencial = Int(factura.secuencial ?? "1") ?? 1

            // 1. Generar XML.
            let gen = SRIXMLGenerator.generar(config: config, factura: factura,
                                              detalles: detalles, secuencial: secuencial)
            let claveAcceso = gen.claveAcceso

            // 2. Guardar XML sin firmar.
            let rutaXml = dirXmls.appendingPathComponent("\(claveAcceso).xml")
            try? gen.xml.data(using: .utf8)?.write(to: rutaXml)

            // 3. Firmar XAdES-BES.
            let xmlFirmado: String
            do { xmlFirmado = try XAdESSigner.firmar(xml: gen.xml, certificado: cert) }
            catch { return fail("Error firmando XML: \(error.localizedDescription)") }

            // 4. Enviar (recepción).
            let recepcion = await SRISoapClient.enviarComprobante(xmlFirmado: xmlFirmado, ambiente: ambiente)

            // 5. Polling de autorización si fue RECIBIDA.
            var auth = AutorizacionResult(estado: recepcion.estado, numeroAutorizacion: "",
                fechaAutorizacion: "", xmlAutorizado: "", mensajes: recepcion.mensajes)
            if recepcion.ok {
                for _ in 0..<8 {
                    try? await Task.sleep(for: .seconds(4))
                    auth = await SRISoapClient.consultarAutorizacion(claveAcceso: claveAcceso, ambiente: ambiente)
                    if auth.ok || !Self.estadosPendientes.contains(auth.estado) { break }
                }
            }

            // 6. Autorizado → éxito.
            if auth.ok {
                var rutaXmlAuth: String? = nil
                if !auth.xmlAutorizado.isEmpty {
                    let ruta = dirXmls.appendingPathComponent("\(claveAcceso)_autorizado.xml")
                    try? auth.xmlAutorizado.data(using: .utf8)?.write(to: ruta)
                    rutaXmlAuth = ruta.path
                }
                facturaRepo.actualizarAutorizada(facturaId, claveAcceso: claveAcceso,
                    numeroAutorizacion: auth.numeroAutorizacion, fechaAutorizacion: auth.fechaAutorizacion,
                    estado: auth.estado, rutaXml: rutaXml.path, rutaXmlAutorizado: rutaXmlAuth,
                    secuencial: gen.secuencial)
                return Resultado(ok: true, estado: auth.estado, claveAcceso: claveAcceso,
                                 numeroAutorizacion: auth.numeroAutorizacion, error: nil)
            }

            // 7. ¿Error 45 (secuencial registrado)? → reservar y reintentar.
            let errorSec = esErrorSecuencial(recepcion.mensajes) || esErrorSecuencial(auth.mensajes)
            if errorSec && intentoSec < Self.MAX_REINTENTOS_SECUENCIAL {
                intentoSec += 1
                let nuevo = configRepo.reservarSiguienteSecuencial()
                factura.secuencial = String(nuevo)
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            // 8. Rechazo definitivo.
            var estadoFinal = auth.estado
            if !["NO AUTORIZADO", "RECHAZADA", "DEVUELTA"].contains(estadoFinal) { estadoFinal = "RECHAZADA" }
            facturaRepo.actualizarEstado(facturaId, estado: estadoFinal, claveAcceso: claveAcceso)
            let msgs = (auth.mensajes.isEmpty ? recepcion.mensajes : auth.mensajes)
            return Resultado(ok: false, estado: estadoFinal, claveAcceso: claveAcceso,
                             numeroAutorizacion: nil, error: "SRI rechazó: \(descripcion(msgs))")
        }
    }

    // MARK: - Helpers

    private func esErrorSecuencial(_ mensajes: [SRIMensaje]) -> Bool {
        for m in mensajes {
            if m.identificador.trimmingCharacters(in: .whitespaces) == "45" { return true }
            if m.mensaje.uppercased().contains("SECUENCIAL REGISTRADO") { return true }
        }
        return false
    }

    private func descripcion(_ mensajes: [SRIMensaje]) -> String {
        mensajes.map { "[\($0.identificador)] \($0.mensaje) \($0.informacionAdicional)".trimmingCharacters(in: .whitespaces) }
            .joined(separator: " | ")
    }

    private func carpetaXMLs(config: ConfiguracionSRI) -> URL {
        let fm = FileManager.default
        if let ruta = config.rutaXmls, !ruta.isEmpty {
            let url = URL(fileURLWithPath: ruta, isDirectory: true)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        let docs = (try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = docs.appendingPathComponent("facturas/xml", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fail(_ msg: String) -> Resultado {
        Resultado(ok: false, estado: "ERROR", claveAcceso: nil, numeroAutorizacion: nil, error: msg)
    }
}
