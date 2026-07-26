//
//  Canonicalizer.swift
//  gym_systemOS
//
//  Wrapper Swift del shim C de libxml2. Canonicaliza XML 1.0 inclusivo,
//  bit-idéntico a `etree.tostring(method="c14n")` del firmador Python.
//

import Foundation

enum Canonicalizer {
    /// Devuelve la forma canónica (C14N 1.0) de `xml` como bytes UTF-8.
    /// - Note: `xml` debe ser un documento/elemento bien formado (con sus
    ///   declaraciones de namespace si es un fragmento).
    static func c14n(_ xml: String) -> Data? {
        let utf8 = Array(xml.utf8)
        return utf8.withUnsafeBufferPointer { buf -> Data? in
            var outLen: Int32 = 0
            guard let base = buf.baseAddress else { return nil }
            return base.withMemoryRebound(to: CChar.self, capacity: buf.count) { cptr -> Data? in
                var len32: Int32 = 0
                guard let ptr = gym_xml_c14n(cptr, Int32(buf.count), &len32) else { return nil }
                defer { gym_xml_free(ptr) }
                outLen = len32
                return Data(bytes: ptr, count: Int(outLen))
            }
        }
    }
}
