//
//  SRISoapClient.swift
//  gym_systemOS
//
//  Cliente SOAP del SRI — reemplaza `zeep` con URLSession + sobres SOAP a mano
//  + XMLParser. Port de sri/sri_client.py (recepción y autorización offline).
//

import Foundation

struct SRIMensaje: Hashable {
    let identificador: String
    let mensaje: String
    let tipo: String
    let informacionAdicional: String
}

struct RecepcionResult {
    let estado: String
    let mensajes: [SRIMensaje]
    var ok: Bool { estado == "RECIBIDA" }
}

struct AutorizacionResult {
    let estado: String
    let numeroAutorizacion: String
    let fechaAutorizacion: String
    let xmlAutorizado: String
    let mensajes: [SRIMensaje]
    var ok: Bool { estado == "AUTORIZADO" }
}

enum SRISoapClient {

    // Endpoints (sin ?wsdl). Ambiente 1 = pruebas (celcer), 2 = producción (cel).
    private static func recepcionURL(_ ambiente: Int) -> URL {
        let host = ambiente == 2 ? "cel.sri.gob.ec" : "celcer.sri.gob.ec"
        return URL(string: "https://\(host)/comprobantes-electronicos-ws/RecepcionComprobantesOffline")!
    }
    private static func autorizacionURL(_ ambiente: Int) -> URL {
        let host = ambiente == 2 ? "cel.sri.gob.ec" : "celcer.sri.gob.ec"
        return URL(string: "https://\(host)/comprobantes-electronicos-ws/AutorizacionComprobantesOffline")!
    }

    // MARK: - Recepción (validarComprobante)

    static func enviarComprobante(xmlFirmado: String, ambiente: Int) async -> RecepcionResult {
        let xmlB64 = Data(xmlFirmado.utf8).base64EncodedString()
        let sobre = """
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ec="http://ec.gob.sri.ws.recepcion">
        <soapenv:Header/>
        <soapenv:Body>
        <ec:validarComprobante>
        <xml>\(xmlB64)</xml>
        </ec:validarComprobante>
        </soapenv:Body>
        </soapenv:Envelope>
        """
        do {
            let data = try await post(url: recepcionURL(ambiente), soap: sobre)
            let p = SoapParser(data: data)
            p.parse()
            let estado = p.estado ?? "DEVUELTA"
            return RecepcionResult(estado: estado, mensajes: p.mensajes)
        } catch {
            return RecepcionResult(estado: "ERROR",
                mensajes: [SRIMensaje(identificador: "", mensaje: error.localizedDescription, tipo: "ERROR", informacionAdicional: "")])
        }
    }

    // MARK: - Autorización (autorizacionComprobante)

    static func consultarAutorizacion(claveAcceso: String, ambiente: Int) async -> AutorizacionResult {
        let sobre = """
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ec="http://ec.gob.sri.ws.autorizacion">
        <soapenv:Header/>
        <soapenv:Body>
        <ec:autorizacionComprobante>
        <claveAccesoComprobante>\(claveAcceso)</claveAccesoComprobante>
        </ec:autorizacionComprobante>
        </soapenv:Body>
        </soapenv:Envelope>
        """
        do {
            let data = try await post(url: autorizacionURL(ambiente), soap: sobre)
            let p = SoapParser(data: data)
            p.parse()
            guard let estado = p.estado else {
                return AutorizacionResult(estado: "PENDIENTE", numeroAutorizacion: "",
                    fechaAutorizacion: "", xmlAutorizado: "", mensajes: p.mensajes)
            }
            return AutorizacionResult(estado: estado,
                numeroAutorizacion: p.numeroAutorizacion ?? "",
                fechaAutorizacion: p.fechaAutorizacion ?? "",
                xmlAutorizado: p.comprobanteAutorizado ?? "",
                mensajes: p.mensajes)
        } catch {
            return AutorizacionResult(estado: "ERROR", numeroAutorizacion: "", fechaAutorizacion: "",
                xmlAutorizado: "",
                mensajes: [SRIMensaje(identificador: "", mensaje: error.localizedDescription, tipo: "ERROR", informacionAdicional: "")])
        }
    }

    // MARK: - HTTP

    private static func post(url: URL, soap: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("", forHTTPHeaderField: "SOAPAction")
        req.httpBody = Data(soap.utf8)
        req.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}

// MARK: - Parser SOAP

private final class SoapParser: NSObject, XMLParserDelegate {
    private let data: Data
    init(data: Data) { self.data = data }

    var estado: String?
    var numeroAutorizacion: String?
    var fechaAutorizacion: String?
    var comprobanteAutorizado: String?
    var mensajes: [SRIMensaje] = []

    private var stack: [String] = []
    private var text = ""
    // Acumulador del mensaje actual.
    private var mIdent = "", mMsg = "", mTipo = "", mInfo = ""
    private var enMensaje = false

    func parse() {
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = self
        p.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        let parent = stack.last
        if elementName == "mensaje", parent == "mensajes" {
            enMensaje = true
            mIdent = ""; mMsg = ""; mTipo = ""; mInfo = ""
        }
        stack.append(elementName)
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        stack.removeLast()
        let parent = stack.last

        switch elementName {
        case "estado":
            if estado == nil { estado = value }
        case "numeroAutorizacion":
            if numeroAutorizacion == nil { numeroAutorizacion = value }
        case "fechaAutorizacion":
            if fechaAutorizacion == nil { fechaAutorizacion = value }
        case "comprobante":
            if parent == "autorizacion", comprobanteAutorizado == nil { comprobanteAutorizado = value }
        case "identificador":
            if enMensaje { mIdent = value }
        case "tipo":
            if enMensaje { mTipo = value }
        case "informacionAdicional":
            if enMensaje { mInfo = value }
        case "mensaje":
            if parent == "mensaje" {
                // Leaf <mensaje> con el texto del mensaje.
                mMsg = value
            } else if parent == "mensajes" {
                // Fin del contenedor <mensaje>.
                mensajes.append(SRIMensaje(identificador: mIdent, mensaje: mMsg, tipo: mTipo, informacionAdicional: mInfo))
                enMensaje = false
            }
        default:
            break
        }
        text = ""
    }
}
