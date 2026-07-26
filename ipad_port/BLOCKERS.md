# BLOCKERS.md — Bloqueadores técnicos y decisiones tomadas

Registro de los problemas técnicos reales encontrados, las alternativas evaluadas y la
decisión adoptada (autonomía: se eligió la más razonable y se continuó).

---

## B1 — El entorno no coincidía con el brief (RESUELTO)
- **Problema**: el brief asumía un proyecto base en `ipad_port/` con GRDB e iPadOS 17.
  La realidad: proyecto Xcode SwiftUI recién creado en la **raíz** (`gym_systemOS.xcodeproj`),
  plantilla SwiftData, sin GRDB, target iOS 26.5. El código Python vive en un repo aparte
  (`~/Desktop/A&G SOLUTIONS/gym_system`).
- **Decisión**: usar este repo como el port; adaptar el proyecto de la raíz (GRDB por SPM,
  iPad-only, deployment 17, sin SwiftData). Docs del port en `ipad_port/`. Ver AUDIT.md §0.

## B2 — Plataforma iOS no instalada (RESUELTO)
- **Problema**: `xcodebuild` solo ofrecía destino macOS; iOS 26.5 no estaba instalada
  (`simctl list runtimes` vacío). Sin la plataforma no se puede compilar para iPad.
- **Decisión**: `xcodebuild -downloadPlatform iOS` (no requirió sudo). Instaló el runtime de
  Simulador iOS 26.5. A partir de ahí, `xcodebuild build`/`test` funcionan.

## B3 — XAdES-BES en iOS sin OpenSSL ni Java  ⭐ (RESUELTO — riesgo del brief mitigado)
- **Problema**: la firma XAdES-BES del SRI exige **Canonical XML 1.0 inclusivo**, SHA1 y
  RSA-SHA1. CryptoKit **no** hace RSA ni C14N. El brief sugería OpenSSL como plan B.
- **Alternativas evaluadas**:
  1. OpenSSL-Swift-Package / XCFramework → dependencia binaria pesada de terceros.
  2. Reimplementar C14N en Swift → altísimo riesgo de no ser byte-idéntico a lxml.
  3. **libxml2 del sistema iOS** (elegida) → lxml *es* libxml2, así que
     `xmlC14NDocDumpMemory` produce **exactamente** los mismos bytes que el firmador Python.
- **Decisión**: shim en C (`SRI/C14N/c14n_shim.c`) expuesto por bridging header, enlazado con
  `-lxml2` y `HEADER_SEARCH_PATHS=$(SDKROOT)/usr/include/libxml2`. RSA-SHA1 y SHA1 con
  **Security framework** (`SecKeyCreateSignature .rsaSignatureMessagePKCS1v15SHA1`) y
  **CryptoKit** (`Insecure.SHA1`). **Sin OpenSSL, sin Java.**
- **Validación**: prueba `testFirmaXAdESAutoConsistente` — firma un comprobante con un `.p12`
  de prueba y verifica con `SecKeyVerifySignature` que (a) la firma RSA sobre `SignedInfo`
  valida contra el certificado y (b) los 3 digests (comprobante enveloped, SignedProperties,
  KeyInfo) coinciden. Es la **misma verificación matemática** que hace el SRI.

## B4 — IssuerName / serial del certificado en iOS (RESUELTO)
- **Problema**: el SRI exige `<X509IssuerName>` en formato RFC 4514 y `<X509SerialNumber>`
  decimal. iOS **no** expone el DN del emisor de un `SecCertificate` (a diferencia de macOS).
- **Decisión**: parser ASN.1/DER mínimo propio (`SRI/DER.swift`) que extrae el IssuerName y
  lo formatea idéntico a `cryptography.rfc4514_string` (orden RDN inverso, mapa OID→nombre
  corto, escapado RFC 4514) y el serial en decimal. Verificado en test contra el issuer que
  reporta OpenSSL (`CN=...,OU=...,O=...,C=EC`).

## B5 — Panel nativo del Simulador no adjuntable (PARCIAL — no bloquea)
- **Problema**: la herramienta de panel en vivo del Simulador reporta "Xcode installed but
  not selected" pese a que `xcode-select -p` apunta correctamente a `/Applications/Xcode.app`.
  Requiere `sudo xcode-select -s ...` (necesita contraseña del usuario, no ejecutable por mí).
- **Mitigación**: la verificación visual se hizo con capturas vía `xcrun simctl io screenshot`
  (sí funcionan) y la verificación funcional con `xcodebuild test` (8 pruebas). El usuario puede
  abrir la app en el Simulador manualmente.

---

## Riesgos abiertos (requieren certificado real + conectividad al SRI)
- **XAdES-BES end-to-end**: la auto-consistencia está probada, pero la aceptación final la da
  el SRI con un `.p12` **real** de una entidad acreditada (BCE, Security Data, Uanataca…) y el
  RUC de pruebas. Verificar en ambiente 1 (celcer) antes de producción.
- **SOAP SRI**: los endpoints y el parseo se implementaron según `sri_client.py`, pero no se
  pudieron golpear los WS reales desde este entorno. Confirmar el `estado`/`mensajes` con un
  envío de prueba real.
- **App Transport Security**: los WS del SRI son HTTPS válidos; no debería requerir excepciones
  ATS. Si algún endpoint fallara por TLS, añadir excepción específica en Info.plist.
