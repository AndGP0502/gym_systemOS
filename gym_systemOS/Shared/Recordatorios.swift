//
//  Recordatorios.swift
//  gym_systemOS
//
//  Port de modulos/alertas.py: arma el enlace de WhatsApp (wa.me) y el mailto
//  con el mensaje de recordatorio de vencimiento. En iPad se abre con la app
//  correspondiente vía openURL (no automatiza el navegador).
//

import Foundation

enum Recordatorios {

    /// Normaliza el teléfono a formato internacional Ecuador (593…) como en el escritorio.
    static func telefonoEcuador(_ numero: String) -> String {
        var n = numero.replacingOccurrences(of: " ", with: "")
                      .replacingOccurrences(of: "-", with: "")
        while n.hasPrefix("+") { n.removeFirst() }
        if n.hasPrefix("593") { return n }
        if n.hasPrefix("0") { return "593" + n.dropFirst() }
        return "593" + n
    }

    /// Mensaje de recordatorio según días restantes (nil = sin suscripción).
    static func mensaje(nombre: String, diasRestantes: Int?) -> String {
        let estado: String
        if let d = diasRestantes {
            if d <= 0 { estado = "tu suscripción venció hace \(abs(d)) día(s)" }
            else if d == 1 { estado = "tu suscripción vence MAÑANA" }
            else { estado = "tu suscripción vence en \(d) día(s)" }
        } else {
            estado = "no encontramos una suscripción activa a tu nombre"
        }
        return """
        Hola \(nombre) 👋

        Te recordamos que \(estado).

        Renueva tu suscripción para seguir entrenando con nosotros 💪

        ¡Te esperamos!
        """
    }

    /// URL de WhatsApp (wa.me) con el mensaje pre-cargado.
    static func whatsappURL(telefono: String, mensaje: String) -> URL? {
        let tel = telefonoEcuador(telefono)
        let texto = mensaje.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(tel)?text=\(texto)")
    }

    /// URL mailto con asunto y cuerpo.
    static func correoURL(email: String, asunto: String, cuerpo: String) -> URL? {
        let a = asunto.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let c = cuerpo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(email)?subject=\(a)&body=\(c)")
    }
}
