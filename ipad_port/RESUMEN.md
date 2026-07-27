# RESUMEN.md — Port de `gym_system` a iPadOS (app nativa local)

App **SwiftUI nativa para iPadOS 17+**, 100% local (SQLite embebido con GRDB), que replica el
sistema de escritorio `gym_system` (Python/tkinter) incluyendo **facturación electrónica SRI
con firma XAdES-BES** — sin Java, sin OpenSSL, sin backend remoto.

- Proyecto: `gym_systemOS.xcodeproj` (raíz del repo). Bundle: `TOQ.gym-systemOS`.
- Docs del port: `ipad_port/` (AUDIT.md, ARQUITECTURA.md, BLOCKERS.md, este archivo).

---

## 1. Qué se implementó

| Módulo | Estado | Notas |
|---|---|---|
| Base de datos (GRDB) | ✅ | Migración que replica **exacto** el esquema de `gym.db` (10 tablas) |
| **Inicio (Dashboard)** | ✅ | Métricas (clientes/activos/vencidos/ingresos) + gráficas (Swift Charts) |
| Clientes | ✅ | CRUD + búsqueda + recordatorios WhatsApp/correo + acceso a Ficha |
| **Asistencia** | ✅ | Check-in por cédula con estado de membresía + historial |
| Suscripciones | ✅ | Asignar/renovar/editar fechas, buscar, estado; gestión de Planes |
| Pagos | ✅ | Tarjetas + color-coding + histórico + cambiar plan/resetear/rápida |
| Clientes Caducados | ✅ | Filtros mes/año + color-coding por antigüedad |
| **Ficha del cliente** | ✅ | Datos físicos/médicos + foto + historial de medidas (IMC) |
| Facturación SRI | ✅ | XML v2.1.0 → **XAdES-BES** → SOAP → polling → reintento; borrador + **RIDE PDF** |
| Configuración | ✅ | Emisor + `.p12` (Keychain) + **PIN** + exportar/importar BD |
| Firma XAdES-BES | ✅ (auto-consistencia probada) | libxml2 (C14N) + CryptoKit (SHA1) + Security (RSA-SHA1) |
| Cliente SOAP SRI | ✅ (sin validar contra WS real) | URLSession + sobres SOAP + XMLParser (reemplaza zeep) |

### Paridad con el `.exe`
Ver **[PARIDAD.md](PARIDAD.md)** para la matriz función-por-función. Exclusiones justificadas:
import/export **Excel** (sustituido por export/import de `gym.db`), **PDF de ficha/reporte
mensual** (diferidos; el RIDE sí está), **Selenium** (no aplica en iOS), **logo/acerca-de**
(cosmético) y **borrados masivos** (cubiertos por borrado por elemento + importar BD).

### Verificación
- **Compilación**: `xcodebuild build` en verde tras cada fase/grupo.
- **Pruebas** (`xcodebuild test`, **14/14** en verde):
  - Firma/SRI: `testFirmaXAdESAutoConsistente` (firma RSA + 3 digests), `testIssuerRFC4514_yModExp`,
    `testC14NBasico`, `testModulo11Deterministico`.
  - Datos/negocio: CRUD/ID hueco, vencimiento, reglas de pago, caducados vs activos, secuencial.
  - Módulos: Ficha+IMC, Asistencia, Dashboard, cambiar plan/resetear/editar fechas.
  - **Orquestador SRI con mock SOAP**: happy-path (RECIBIDA→AUTORIZADO) y **reintento de
    secuencial** (error 45 → reserva nuevo → autoriza).
- **Arranque visual**: Dashboard con datos reales verificado en Simulador iPad Pro 13" (iOS 26.5).

---

## 2. Cómo abrir y correr el proyecto

### En Xcode (Simulador)
1. Abrir `gym_systemOS.xcodeproj` en Xcode.
2. Esperar a que resuelva el paquete **GRDB** (SPM, automático).
3. Seleccionar un destino **iPad Simulator** y pulsar Run (⌘R).

### Desde terminal (compilar / probar)
```bash
# Compilar para Simulador
xcodebuild -project gym_systemOS.xcodeproj -scheme gym_systemOS \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build

# Correr las pruebas (necesita un iPad Simulator booteado)
xcodebuild -project gym_systemOS.xcodeproj -scheme gym_systemOS \
  -destination 'id=<UDID-del-simulador>' -only-testing:gym_systemOSTests test
```
> Nota de entorno: si `xcodebuild` no encuentra destino iOS, instalar la plataforma con
> `xcodebuild -downloadPlatform iOS` (ya hecho en esta Mac).

### Instalar en un iPad físico (sideload con Apple ID de desarrollador)
1. Conectar el iPad por cable y confiar en la Mac.
2. En Xcode → target `gym_systemOS` → **Signing & Capabilities**: `Automatically manage
   signing` (ya activo) y seleccionar tu **Team** (tu Apple ID personal sirve para sideload).
3. Elegir el iPad como destino y Run (⌘R). La primera vez, en el iPad:
   **Ajustes → General → VPN y gestión de dispositivos → confiar** en tu certificado de
   desarrollador.
4. (Apps firmadas con Apple ID gratuito caducan a los 7 días; con membresía de pago, 1 año.)

### Primer uso
1. Ir a **Configuración**: llenar RUC, razón social, establecimiento/punto de emisión,
   ambiente (Pruebas/Producción) y **cargar el `.p12`** con su clave. Guardar.
2. Crear **Clientes**, **Planes** y **Suscripciones**; registrar **Pagos**.
3. En **Facturación SRI** → Nueva factura → emitir (firma + envío + autorización).

---

## 3. Dejar listo para TestFlight (pasos manuales cuando la membresía esté activa)

> **No ejecutar aún**: sin membresía de Apple Developer activa, `Archive`/subida fallan. El
> proyecto ya está preparado (signing automático, sin Team ID hardcodeado, `.p12` configurable
> en runtime), así que **no hacen falta cambios estructurales**: solo estos pasos.

1. **Activar la membresía** de Apple Developer y aceptar contratos en App Store Connect.
2. **Crear la app en App Store Connect**: My Apps → ➕ → New App. Plataforma iOS, nombre,
   idioma primario, y el **Bundle ID `TOQ.gym-systemOS`** (registrarlo en Certificates,
   Identifiers & Profiles si no aparece). SKU libre.
3. En Xcode, target → Signing: seleccionar tu **Team** (con signing automático Xcode crea el
   perfil de distribución). Subir `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` si hace falta.
4. Seleccionar destino **Any iOS Device (arm64)** → **Product → Archive**.
5. En el **Organizer**: seleccionar el archivo → **Distribute App → TestFlight (Internal/App
   Store Connect)** → subir. Esperar el procesamiento en App Store Connect.
6. En **App Store Connect → TestFlight**:
   - Completar la **información de cumplimiento de exportación** (la app usa criptografía
     estándar de Apple para HTTPS/firma; normalmente exenta — confirmar la pregunta ITSAppUsesNonExemptEncryption).
   - **Testers externos**: crear un grupo, agregar el correo del cliente, adjuntar el build y
     enviar a **revisión de TestFlight** (los externos requieren una revisión ligera de Apple).
   - El cliente instala **TestFlight** desde la App Store y acepta la invitación por correo.
7. Para nuevas versiones: subir el `siguiente_secuencial`… (no aplica), subir build number,
   Archive → Distribute → el grupo de testers recibe la actualización.

> El `.p12` **no** se incluye en el build: el cliente lo carga desde la pantalla de
> Configuración en su iPad. Así, el mismo build de TestFlight sirve para cualquier emisor.

---

## 4. Riesgos conocidos

- **Firma XAdES-BES**: auto-consistencia criptográfica **probada**, pero la aceptación final
  la da el SRI con un **certificado real** de entidad acreditada y el RUC de pruebas. Probar
  primero en **ambiente 1 (celcer)**. (Detalle y mitigación en BLOCKERS.md B3/B4.)
- **SOAP SRI**: endpoints y parseo portados de `sri_client.py` pero no validados contra los WS
  reales desde este entorno. Confirmar con un envío de prueba real.
- **Panel del Simulador**: la integración nativa del panel requiere
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (necesita tu contraseña).
  No afecta a compilar/probar/instalar.
- **Vigencia del sideload**: con Apple ID gratuito la app caduca a los 7 días; usar TestFlight
  para el cliente final.

---

## 5. Estructura del código (`gym_systemOS/`)
```
App/            Entry point, RootView (NavigationSplitView), Environment de la BD
Database/       AppDatabase (GRDB + migración del esquema)
Models/         Registros GRDB (Cliente, Membresia, Suscripcion, Pago, Factura, …) + Consultas
Repositories/   Reglas de negocio (port de modulos/*.py y services/factura_service.py)
Features/       Vistas + ViewModels por módulo
SRI/            C14N (libxml2 shim), DER, CertificateStore, SRIXMLGenerator,
                XAdESSigner, SRISoapClient, FacturaService
Shared/         Formatters, EstadoColor (paleta = color-coding del escritorio), bindings
```
El código Python original **no se tocó** (vive en repo aparte).
