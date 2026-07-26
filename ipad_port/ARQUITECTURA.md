# ARQUITECTURA.md — App iPadOS nativa (Fase 1)

Objetivo: réplica **100% local** de `gym_system` en SwiftUI, sin backend remoto obligatorio,
análoga al `.exe` de Windows. Facturación electrónica SRI incluida.

## 1. Plataforma y UI
- **SwiftUI**, target **iPadOS 17+** (se baja el deployment de 26.5 → 17.0 para cubrir iPads
  reales del cliente). Device family **iPad** (`TARGETED_DEVICE_FAMILY = 2`); se recorta
  `SUPPORTED_PLATFORMS` a `iphoneos iphonesimulator` (se descartan macOS/visionOS del brief).
- Navegación **`NavigationSplitView`** (sidebar de módulos + detalle), idiomática de iPad,
  no un reflow del escritorio.
- Signing: **`Automatic`**, sin `DEVELOPMENT_TEAM` hardcodeado (listo para TestFlight).

## 2. Persistencia — GRDB.swift (SQLite embebido)
- Dependencia vía **SPM**: `https://github.com/groue/GRDB.swift`.
- La BD se crea en `Application Support/gym.db` mediante **migraciones** (`DatabaseMigrator`)
  que replican **exactamente** el esquema auditado (10 tablas). Esto permite en el futuro
  importar el `gym.db` del escritorio o sincronizar.
- Capa: `AppDatabase` (singleton con `DatabaseQueue`) + tipos `Codable`/`FetchableRecord`/
  `PersistableRecord` por tabla + repositorios por módulo (mismas reglas de negocio del Python).
- **Fallback documentado** (BLOCKERS.md): si GRDB por SPM no resolviera en este entorno, se
  sustituye por un wrapper delgado sobre `libsqlite3` del sistema — misma BD, misma API de repos.

## 3. Facturación SRI — sin Java, sin OpenSSL, sin backend
Réplica fiel del pipeline `factura_service.procesar_factura_completa`:

1. **Generación XML** (`SRIXMLGenerator`): comprobante `factura v2.1.0`, clave de acceso de
   49 dígitos con **dígito verificador módulo 11**, IVA 15%/0%, `id="comprobante"`. Port
   1:1 de `sri/xml_generator.py`.
2. **Firma XAdES-BES** (`XAdESSigner`) — decisión técnica clave:
   - **Canonicalización C14N 1.0 inclusiva** con **libxml2** del sistema iOS
     (`xmlC14NDocDumpMemory`, mode 0). lxml *es* libxml2 → salida byte-idéntica a la del
     firmador Python. Se expone vía un target C (`CLibxml2Shim`) o `HEADER_SEARCH_PATHS` al
     `usr/include/libxml2` del SDK + `-lxml2`.
   - **SHA1** de digests con `CryptoKit.Insecure.SHA1`.
   - **RSA-SHA1 PKCS#1 v1.5** con **Security framework**: `SecPKCS12Import` (carga el `.p12`
     con su clave, resuelve identidad↔cadena CA), `SecIdentityCopyPrivateKey`,
     `SecKeyCreateSignature(key, .rsaSignatureDigestPKCS1v15SHA1, digest)`.
   - Estructura idéntica: 3 referencias (SignedProperties, KeyInfo, `#comprobante` enveloped),
     inyección de `xmlns:ds`/`xmlns:etsi` heredados antes de hashear SignedProperties/KeyInfo,
     `SigningTime` en UTC-5.
   - > CryptoKit **no** hace RSA; por eso RSA va por Security framework. Decisión: **no** se
     usa OpenSSL (evita XCFramework y binarios de terceros). Ver BLOCKERS.md.
3. **Cliente SOAP** (`SRISoapClient`): reemplaza `zeep` por **URLSession + sobres SOAP a mano**
   (`validarComprobante`, `autorizacionComprobante`) y parseo con `XMLParser`. Endpoints
   celcer (pruebas, amb 1) / cel (producción, amb 2).
4. **Orquestador** (`FacturaService`): mismo flujo — enviar → **polling** autorización
   (8 intentos × 4 s) → **reintento de secuencial** ante error 45 (máx 5) → persistir estado.
5. **Certificado**: el `.p12` se importa en tiempo de ejecución (file picker) y se guarda en
   el **Keychain de iOS**; la clave nunca se hardcodea ni viaja en el bundle. La ruta/clave de
   `configuracion_sri` pasan a ser referencias al item de Keychain.

## 4. Estructura de carpetas Swift (`gym_systemOS/`)
```
gym_systemOS/
  App/            gym_systemOSApp.swift, RootView (NavigationSplitView), Theme
  Database/       AppDatabase.swift (migraciones), DBError
  Models/         Cliente, Membresia, Suscripcion, Pago, ConfiguracionSRI,
                  Factura, FacturaDetalle, FichaCliente, HistorialMedida, Asistencia
  Repositories/   ClientesRepo, MembresiasRepo, SuscripcionesRepo, PagosRepo,
                  CaducadosRepo, FacturacionRepo, ConfiguracionRepo
  Features/
    Clientes/     ClientesView + ViewModel
    Suscripciones/
    Pagos/        (color-coding pagado/parcial/deuda/vencido)
    Caducados/    (filtros mes/año + color-coding reciente/vencido/antiguo)
    Facturacion/  FacturaComposer, ListaFacturasView
    Configuracion/ ConfiguracionView (carga .p12, datos emisor)
  SRI/            SRIXMLGenerator, XAdESSigner, SRISoapClient, FacturaService, Keychain
  Shared/         EstadoColor (paleta = color-coding del escritorio), Formatters
```

## 5. Concurrencia
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Swift approachable concurrency). Repos y firma
son síncronos sobre GRDB; la red SRI es `async` (`URLSession`) y el polling usa `Task.sleep`.

## 6. Fuera de alcance de esta iteración (esquema ya soportado)
Ficha médica, historial de medidas, asistencia, import Excel, gráficas, RIDE PDF, email, backups.
