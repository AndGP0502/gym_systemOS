# AUDIT.md — Auditoría de `gym_system` (Python) para el port a iPadOS

> Fase 0. Fuente auditada: `~/Desktop/A&G SOLUTIONS/gym_system/` (working copy local,
> **repo separado** del proyecto Swift). El código Python **no se toca**.
> Objetivo: replicar su funcionalidad en una app nativa SwiftUI 100% local.

---

## 0. Hallazgo de reconciliación (realidad vs. brief)

El prompt asumía un mapa de archivos que **no coincide** con el disco:

| Brief asumía | Realidad verificada |
|---|---|
| Proyecto base en `ipad_port/` con GRDB e iPadOS 17 | No existía. Hay un proyecto Xcode SwiftUI recién creado **en la raíz** (`gym_systemOS.xcodeproj`), plantilla SwiftData (`Item.swift`), sin GRDB, target iOS 26.5 |
| `ipad_port/` dentro del repo Python | El Python vive aparte en `A&G SOLUTIONS/gym_system/`; este repo (`gym_systemOS`) es el proyecto Swift |
| Signing automático, sin Team ID hardcodeado | ✅ Correcto (`CODE_SIGN_STYLE = Automatic`, bundle `TOQ.gym-systemOS`) |

**Decisión adoptada** (autonomía): este repo `gym_systemOS` **es** el port. Se adapta el
proyecto Xcode de la raíz (GRDB + iPad-first + deployment 17) y toda la documentación del
port vive en `ipad_port/`. El Xcode project permanece en la raíz (mover un `.xcodeproj` es
riesgoso y sin valor: el repo entero ya está dedicado a la app iPad).

---

## 1. Esquema de la base de datos SQLite (`gym.db`)

10 tablas. Fuente de verdad = `.schema` real de `gym.db` + `database/database.py` +
`database/facturacion_db.py`.

### 1.1 Núcleo de gimnasio

```
clientes(
  id INTEGER PK AUTOINCREMENT,
  nombre TEXT, cedula TEXT, telefono TEXT, fecha_registro TEXT,
  correo TEXT, edad REAL, fecha_nacimiento TEXT, sexo TEXT
)
```
- Cédula tratada como única a nivel de lógica (chequeo manual en `agregar_cliente`/`editar_cliente`), **no** hay UNIQUE en el esquema.
- IDs se asignan buscando "el hueco más bajo" (reutilización de IDs libres), no autoincrement puro.

```
membresias(
  id INTEGER PK AUTOINCREMENT,
  nombre_plan TEXT, precio REAL, duracion_dias INTEGER
)
```
- `nombre_plan` único por lógica. Duración en días.

```
suscripciones(
  id INTEGER PK AUTOINCREMENT,
  cliente_id INTEGER FK→clientes,
  membresia_id INTEGER FK→membresias,
  fecha_inicio TEXT, fecha_vencimiento TEXT,
  precio_total REAL, pagado REAL, pendiente REAL
)
```
- `fecha_vencimiento = fecha_inicio + duracion_dias`.
- `pendiente = max(0, precio_total - pagado)`.
- IDs con reutilización de huecos (`_nuevo_id_suscripcion`).

```
pagos(
  id INTEGER PK AUTOINCREMENT,
  suscripcion_id INTEGER FK→suscripciones,
  monto REAL, fecha_pago TEXT
)
```

```
ficha_cliente(
  id PK, cliente_id UNIQUE FK→clientes,
  objetivo, estado_fisico, condiciones, notas, foto_ruta,
  peso_kg, altura_m, cir_abdominal, status_fisico, objetivo_2,
  peso_ideal, lesion, cardiovascular, asfixia, asmatico, medicacion, mareos
)   -- 73 filas en la BD de muestra
```

```
historial_medidas(
  id PK, cliente_id FK, fecha, peso_kg, altura_cm, imc, notas
)   -- 4 filas
```

```
asistencia(
  id PK, cliente_id FK, cedula, nombre, fecha, hora, estado, vencimiento
)
```

### 1.2 Facturación SRI

```
configuracion_sri(
  id PK DEFAULT 1,                       -- fila única
  ruc TEXT NOT NULL, razon_social TEXT NOT NULL, nombre_comercial,
  direccion_matriz, direccion_sucursal,
  codigo_establecimiento DEFAULT '001', punto_emision DEFAULT '001',
  ambiente INTEGER DEFAULT 1,            -- 1=pruebas/celcer, 2=producción/cel
  tipo_emision INTEGER DEFAULT 1,
  ruta_certificado TEXT, clave_certificado TEXT,  -- .p12 y su clave
  siguiente_secuencial INTEGER DEFAULT 1,
  correo_remitente, smtp_host, smtp_port DEFAULT 587, smtp_usuario, smtp_clave,
  ruta_xmls, ruta_rides,
  clave_sri, apellido_paterno, apellido_materno, primer_nombre,
  segundo_nombre, correo_electronico, telefono_conv, telefono_celular,
  direccion_domicilio
)
```
> ⚠️ **Ambiente**: el default del esquema es `1`, y `sri_client` mapea `1→celcer` (pruebas)
> y `2→cel` (producción). Ojo: la tabla `facturas` tiene default de `ambiente=2`. En el
> port se toma **siempre** el valor de `configuracion_sri.ambiente` como fuente de verdad.

```
facturas(
  id PK AUTOINCREMENT, clave_acceso TEXT UNIQUE, numero_autorizacion,
  estado TEXT DEFAULT 'BORRADOR', ambiente INTEGER DEFAULT 2,
  fecha_emision, fecha_autorizacion, ruc_emisor, razon_social_emisor,
  tipo_identificacion DEFAULT '05', identificacion, razon_social,
  correo, telefono, direccion,
  subtotal_0, subtotal_15, subtotal_no_iva, descuento_total, iva_15, total,
  establecimiento DEFAULT '001', punto_emision DEFAULT '001', secuencial TEXT,
  ruta_xml, ruta_xml_autorizado, ruta_ride,
  cliente_id INTEGER FK→clientes, observacion
)
```

```
factura_detalle(
  id PK, factura_id NOT NULL FK→facturas,
  descripcion, cantidad, precio_unitario, descuento,
  tiene_iva DEFAULT 1, porcentaje_iva DEFAULT 15,
  subtotal, iva, total
)
```

**Estados de factura**: `BORRADOR → (envío) → AUTORIZADO | NO AUTORIZADO | RECHAZADA | DEVUELTA | ERROR | PENDIENTE`.
No se puede eliminar una factura `AUTORIZADO` (validez fiscal).

---

## 2. Módulos funcionales

### 2.1 Clientes  (`modulos/clientes.py`)
CRUD: `agregar_cliente` (valida nombre/cédula/teléfono, cédula no duplicada),
`editar_cliente`, `eliminar_cliente`, `ver_clientes`, contadores con filtro mes/año.
IDs por hueco más bajo.

### 2.2 Membresías  (`modulos/membresias.py`)
CRUD de planes (nombre único, precio > 0, duración > 0).

### 2.3 Suscripciones  (`modulos/suscripciones.py`)
- `asignar_membresia` / `crear_suscripcion`: calcula `fecha_vencimiento` y `pendiente`.
- `renovar_suscripcion_cliente(cliente_id, dias=30, monto)`: extiende `fecha_vencimiento`
  del **último** contrato del cliente; si `monto>0`, **acumula** `precio_total` y `pagado`
  del nuevo periodo y registra un `pago`.
- Consultas activos (`fecha_vencimiento >= hoy`) y caducados (`< hoy`), con detalle,
  búsqueda por cédula/nombre (`LIKE ... COLLATE NOCASE`), contadores con filtro mes/año.
- `dias_restantes = (fecha_venc - hoy).days`; `VENCIDO` si `< 0`; "por vencer" si `0..5`.

### 2.4 Pagos  (`modulos/pagos.py`)
- `registrar_pago(suscripcion_id, monto)`: si `precio_total==0` lo fija al monto;
  si no, `nuevo_pagado = min(pagado+monto, precio_total)`, `pendiente = max(0, total-pagado)`.
  Inserta fila en `pagos`. **Ojo**: existe una `registrar_pago` en `suscripciones.py` que
  NO inserta en `pagos` (solo actualiza la suscripción). El port unifica en **una** regla:
  la de `pagos.py` (registra histórico) es la canónica.
- `eliminar_pago`: revierte el monto de la suscripción.
- Listados para la vista de pagos + caducados.

### 2.5 Clientes Caducados  (`modulos/caducados.py`, consultas en suscripciones/pagos)
- `fecha_vencimiento < hoy`, con `dias_vencido = hoy - fecha_venc`.
- Filtros: texto (cédula/nombre), mes, año de vencimiento.
- **Color-coding (a replicar):**
  - `≤ 7 días` → amarillo (`#fff3cd` / `#664d03`)  "reciente"
  - `8–30 días` → rojo (`#f8d7da` / `#842029`)  "vencido"
  - `> 30 días` → rojo oscuro (`#f5b7b1` / `#641e16`)  "antiguo"

### 2.6 Color-coding de Pagos  (`ui/pagos_ui.py`)
  - `pagado` (pendiente=0) → verde `#b6f2c6` / `#0f5132`
  - `parcial` (0 < pagado < total) → amarillo `#fff3cd`
  - `deuda` (pagado=0) → rojo `#f8d7da`
  - `vencido` (fecha_venc < hoy) → rojo oscuro `#f5b7b1` (prioridad sobre lo anterior)

### 2.7 Otros (fuera de alcance inicial del port, documentados)
Ficha de cliente + historial de medidas, asistencia, importación Excel, gráficas,
generación de PDF/RIDE (`pdf_generador.py`, reportlab), backups automáticos,
`selenium_sri.py` (automatiza el portal web del SRI como fallback — **no se porta**;
en iPad se usa solo la vía SOAP oficial).

---

## 3. Facturación electrónica SRI — lógica crítica

### 3.1 `services/factura_service.py` — orquestador
Flujo `procesar_factura_completa(factura_id)`:
1. Carga `configuracion_sri` + factura + detalles.
2. **Bucle de emisión con reintento de secuencial** (máx 5):
   1. `generar_xml_factura` (usa `factura["secuencial"]`).
   2. Guarda XML sin firmar en `ruta_xmls/{clave_acceso}.xml`.
   3. `firmar_xml` (XAdES-BES).
   4. `enviar_comprobante` (recepción SOAP). Estado esperado `RECIBIDA`.
   5. Si RECIBIDA → **polling** `consultar_autorizacion`: hasta **8 intentos**, `sleep(4s)`
      entre cada uno; corta cuando estado ∉ {PENDIENTE, EN PROCESO, PROCESANDO, ERROR}.
   6. Si AUTORIZADO → éxito, sale del bucle.
   7. Si el rechazo es **error 45 "SECUENCIAL REGISTRADO"** → reserva el siguiente
      secuencial libre (`_reservar_siguiente_secuencial`, incremento atómico), reasigna y
      **reintenta** (hasta 5). Los huecos en la numeración local no importan; el SRI solo
      exige no repetir.
   8. Otro rechazo → marca estado final (`NO AUTORIZADO`/`RECHAZADA`/`DEVUELTA`) y termina.
3. Guarda XML autorizado, actualiza factura con `clave_acceso`, `numero_autorizacion`,
   `fecha_autorizacion`, `estado`, `secuencial` **realmente usado**.
- `guardar_factura`: inserta factura+detalles y **incrementa** `siguiente_secuencial`.
- `eliminar_factura`: bloquea borrar AUTORIZADAS.

### 3.2 `sri/xml_generator.py` — comprobante v2.1.0
- **Clave de acceso (49 díg.)**: `ddmmaaaa + tipoComprobante(01) + ruc + ambiente +
  serie(estab+ptoEmi) + secuencial(9) + codigoNumerico(8) + tipoEmision + dígito`.
- **Dígito verificador módulo 11** (factores 2..7 cíclicos; residuo 0→0, 1→1, else 11-residuo).
- `codigoNumerico` = primeros 8 díg. de `uuid4().int`.
- IVA: código `2`; `codigoPorcentaje` `4`=15%, `0`=0%. `secuencial` con `zfill(9)`.
- Genera `<factura id="comprobante" version="2.1.0">` con infoTributaria / infoFactura /
  detalles / infoAdicional. **`id="comprobante"`** es el ancla de la referencia de firma.

### 3.3 `sri/signer.py` — firmador XAdES-BES  ⭐ (pieza más crítica)
**Python puro: `cryptography` + `lxml`. Sin Java, sin OpenSSL externo.**
- **Carga `.p12`**: `load_key_and_certificates`; elige el cert de firma como el único cuya
  clave pública == clave privada (maneja BCE, Security Data, Lazzate, Uanataca, ANF, Datil…
  con cadena CA en orden variable). Exige clave **RSA**.
- **Algoritmos exactos exigidos por el SRI**:
  - Digest: **SHA1** (`http://www.w3.org/2000/09/xmldsig#sha1`).
  - Firma: **RSA-SHA1** PKCS#1 v1.5 (`...#rsa-sha1`).
  - Canonicalización: **Canonical XML 1.0 inclusivo** (`REC-xml-c14n-20010315`),
    `exclusive=False`, sin comentarios. (lxml `method="c14n"` == libxml2 c14n.)
- **3 referencias en SignedInfo**:
  1. `#Signature{id}-SignedProperties{id}` (Type SignedProperties).
  2. `#Certificate{keyinfo_id}` (KeyInfo).
  3. `#comprobante` con transform **enveloped-signature**.
- SignedProperties incluye `SigningTime` en hora Ecuador **UTC-5** (`-05:00`),
  `SigningCertificate` (CertDigest SHA1 + IssuerSerial), `DataObjectFormat`.
- KeyInfo lleva `X509Certificate` (b64 en líneas de 76) + `RSAKeyValue` (Modulus/Exponent).
- **Truco de digest de SignedProperties/KeyInfo**: se canonicalizan inyectando los
  namespaces `ds` y `etsi` heredados (`xmlns:ds`, `xmlns:etsi`) antes de hashear — porque
  c14n inclusivo materializa los namespaces del contexto. **Hay que replicarlo idéntico.**
- IDs aleatorios `randint(990, 999000)`. La firma se inserta antes del `</` del raíz.

### 3.4 `sri/sri_client.py` — cliente SOAP (usa `zeep`)
- **Recepción**: `RecepcionComprobantesOffline`, op. `validarComprobante(xml=<b64>)`.
  - Pruebas (amb 1): `https://celcer.sri.gob.ec/comprobantes-electronicos-ws/RecepcionComprobantesOffline`
  - Producción (amb 2): `https://cel.sri.gob.ec/comprobantes-electronicos-ws/RecepcionComprobantesOffline`
  - Respuesta: `estado` (`RECIBIDA`/`DEVUELTA`) + `comprobantes>comprobante>mensajes>mensaje{identificador,mensaje,tipo}`.
- **Autorización**: `AutorizacionComprobantesOffline`, op. `autorizacionComprobante(claveAccesoComprobante=<clave>)`.
  - Respuesta: `autorizaciones>autorizacion[0]{estado, numeroAutorizacion, fechaAutorizacion, comprobante(xml autorizado), mensajes}`.
  - `estado == AUTORIZADO` = éxito.

---

## 4. Dependencias Python y su equivalente iOS

| Python | Rol | Equivalente iOS (decisión) |
|---|---|---|
| `sqlite3` | Persistencia | **GRDB.swift** (SQLite embebido) |
| `cryptography` (PKCS12, RSA, SHA1) | Carga .p12 + firma | **Security framework** (`SecPKCS12Import`, `SecKeyCreateSignature .rsaSignatureDigestPKCS1v15SHA1`) + **CryptoKit** `Insecure.SHA1` |
| `lxml` (c14n) | Canonical XML 1.0 | **libxml2** del sistema iOS (`xmlC14NDocDumpMemory`, IDÉNTICO a lxml — lxml ES libxml2) |
| `zeep` (SOAP) | Cliente SRI | **URLSession** + sobres SOAP construidos a mano + `XMLParser` |
| `reportlab` (PDF/RIDE) | RIDE | PDFKit / `UIGraphicsPDFRenderer` (fase posterior) |
| `selenium` | Fallback portal SRI | **No se porta** (solo vía SOAP oficial) |
| `smtplib` | Envío email | `MFMailComposeViewController` o SMTP nativo (fase posterior) |

---

## 5. Alcance real y bloqueadores (resumen 10–15 líneas)

- **Alcance portable ahora**: Clientes, Membresías, Suscripciones, Pagos (con color-coding),
  Clientes Caducados (filtros mes/año + color-coding) y el **motor de facturación SRI
  completo** (clave de acceso + módulo 11, XML v2.1.0, firma XAdES-BES, SOAP recepción/
  autorización, polling y reintento de secuencial).
- **La firma XAdES-BES SÍ es viable 100% nativa** sin OpenSSL: la clave está en usar
  **libxml2** (incluido en iOS) para el C14N — produce exactamente el mismo bytes que lxml,
  porque lxml envuelve libxml2. RSA-SHA1 y SHA1 los cubre Security framework + CryptoKit.
  → El "riesgo XAdES" del brief queda **mitigado por diseño**; se documenta en BLOCKERS.md.
- **Bloqueador de verificación real**: sin `.p12` válido, sin RUC de pruebas y sin poder
  golpear los WS del SRI desde este entorno, la firma/SOAP no se puede validar end-to-end
  aquí. Se implementa fielmente y se deja un checklist de verificación con cert de pruebas.
- **Bloqueador de entorno**: no hay runtime de Simulador instalado → verificación por
  `xcodebuild build` en cada fase; ejecución visual queda para cuando se descargue el runtime.
- **Fuera de alcance inicial** (documentado, no implementado): ficha médica + historial de
  medidas, asistencia, importación Excel, gráficas, generación de RIDE PDF, envío por email,
  backups. La BD GRDB replica **todas** las tablas para no bloquear estas fases futuras.
- **Datos**: `gym.db` de muestra tiene ficha_cliente (73) e historial (4); el resto vacío.
