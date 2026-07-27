# PARIDAD.md — Paridad funcional gym_system (.exe Python) → gym_systemOS (iPad)

Matriz de **todas** las funciones del sistema de escritorio y su estado en el port.
Leyenda: ✅ portada · 🟦 adaptada (equivalente iOS) · ⛔ excluida (con motivo).

> Se omiten de la tabla los helpers de UI puramente de tkinter (scroll, `_ajustar`,
> `traer_al_frente`, `_card`, `maximizar`, relojes, etc.) que no son "funciones de negocio".

---

## Clientes  (`modulos/clientes.py`, `ui/clientes_ui.py`)
| Función .exe | Estado | Dónde en iPad |
|---|---|---|
| agregar_cliente / editar_cliente / eliminar_cliente / ver_clientes | ✅ | ClientesRepo + ClientesView |
| buscar_clientes (cédula/nombre) | ✅ | `.searchable` |
| contar_clientes / contar_clientes_filtro | ✅ | ClientesRepo.contar + DashboardRepo |
| abrir_correo | 🟦 | Recordatorios (mailto:) — menú del cliente |
| enviar_whatsapp_manual | 🟦 | Recordatorios (wa.me) — menú del cliente |
| ver_ficha | ✅ | FichaView |
| renovar_suscripcion | ✅ | Suscripciones (renovar) |
| actualizar_grafico / actualizar_tarjetas | ✅ | Movidas al módulo **Inicio** (Dashboard) |

## Membresías  (`modulos/membresias.py`, `ui/membresias_ui.py`)
| crear/editar/ver/eliminar/contar_membresias | ✅ | MembresiasRepo + PlanesView |

## Suscripciones  (`modulos/suscripciones.py`, `ui/suscripciones_ui.py`)
| Función | Estado | Dónde |
|---|---|---|
| asignar_membresia / crear_suscripcion | ✅ | SuscripcionesRepo (asignar/crear) |
| ver_suscripciones_completas / buscar_suscripciones | ✅ | verCompletas / buscar |
| ver_clientes_activos_detalle / ver_clientes_caducados_detalle | ✅ | activasDetalle / caducadasDetalle |
| contar_clientes_activos / contar_suscripciones_vencidas (+filtros) | ✅ | contarActivos / contarVencidas + Caducados |
| renovar_suscripcion_cliente | ✅ | renovar |
| eliminar_suscripcion | ✅ | eliminar |
| abrir_popup_editar_fechas / validar_fecha | ✅ | editarFechas (DatePickers) |
| ingresos_por_mes / cargar_grafico_ingresos | ✅ | DashboardRepo + Charts |
| ver_estado_gimnasio / ver_clientes_vencidos / ver_dias_restantes / clientes_por_vencer | ✅ | Dashboard + Caducados + estado por fila |
| leer_clave / guardar_clave / cambiar_clave | 🟦 | AppSettings (PIN SHA-256 en Keychain/UserDefaults) |
| borrar_todo (borrado masivo) | ⛔ | **Ver Exclusiones #5** |

## Pagos  (`modulos/pagos.py`, `ui/pagos_ui.py`)
| Función | Estado | Dónde |
|---|---|---|
| registrar_pago / ver_historial_pagos / eliminar_pago | ✅ | PagosRepo + RegistrarPagoSheet |
| listar_suscripciones_para_pago / buscar | ✅ | PagosView |
| actualizar_cards (totales) | ✅ | PagosRepo.totales + tarjetas |
| cambiar_plan | ✅ | cambiarPlan |
| crear_suscripcion_rapida | ✅ | crearRapida |
| resetear_pago | ✅ | resetearPago |
| ver_clientes_caducados_pagos | ✅ | Módulo Clientes Caducados |
| on_mes_change (filtro por mes en Pagos) | ⛔ | **Ver Exclusiones #6** (menor) |

## Clientes Caducados  (`modulos/caducados.py`)
| filtros mes/año + búsqueda + color por antigüedad (≤7 / 8–30 / >30) | ✅ | CaducadosView + EstadoCaducado |

## Asistencia  (`ui/asistencia_ui.py`)
| registrar_asistencia (estado membresía) / historial | ✅ | AsistenciaRepo + AsistenciaView |
| reloj en vivo | ⛔ | cosmético (omitido) |

## Ficha del cliente  (`modulos/ficha_cliente.py`, `ui/ficha_ui.py`)
| obtener_ficha / guardar_ficha (upsert) | ✅ | FichaRepo + FichaView |
| agregar_medida / obtener_historial / eliminar_medida / IMC | ✅ | FichaRepo (IMC = peso/altura²) |
| guardar_foto / obtener_foto | ✅ | FichaRepo (PhotosPicker → contenedor app) |
| generar_pdf_ficha_cliente | ✅ | FichaPDF (PDFKit) — botón **PDF** en cada cliente |

## Facturación SRI  (`services/factura_service.py`, `sri/*`, `ui/facturacion_ui.py`)
| Función | Estado | Dónde |
|---|---|---|
| generar_xml_factura / clave_acceso / modulo11 | ✅ | SRIXMLGenerator |
| firmar_xml (XAdES-BES) | ✅ | XAdESSigner (libxml2 + Security + CryptoKit) |
| enviar_comprobante / consultar_autorizacion (SOAP) | ✅ | SRISoapClient (URLSession) |
| procesar_factura_completa (polling + reintento secuencial) | ✅ | FacturaService |
| guardar_factura / guardar_borrador | ✅ | FacturacionRepo / VM.guardarBorrador |
| calcular_totales | ✅ | Compositor |
| eliminar_factura (protege AUTORIZADA) | ✅ | eliminarFactura |
| eliminar_facturas_no_validas (limpieza masiva) | ⛔ | **Ver Exclusiones #5** |
| cargar_historial | ✅ | verFacturas |
| generar_pdf_factura (RIDE) | 🟦 | RidePDF (PDFKit) + compartir |
| info_certificado / seleccionar_p12 | ✅ | CertificateStore + ConfiguracionView |

## Configuración  (`ui/configuracion_ui.py`)
| leer_config / guardar_config | ✅ | ConfiguracionRepo + View |
| cambiar_logo / cargar_preview (logo) | ⛔ | **Ver Exclusiones #4** |

## Dashboard / Backups  (`ui/ventana_princi.py`, `modulos/backup_db.py`, `modulos/graficas.py`)
| actualizar_dashboard | ✅ | DashboardView |
| grafica_clientes | ✅ | Dashboard (Charts) |
| crear_backup | 🟦 | Configuración → Exportar base de datos (VACUUM INTO + compartir) |
| exportar_backup_excel / importar_desde_excel | ⛔ | **Ver Exclusiones #1** |
| hacer_restauracion | 🟦 | Configuración → Importar base de datos |
| mostrar_contacto (ventana "acerca de/contacto") | ⛔ | **Ver Exclusiones #4** |

## Import Excel  (`ui/importar_excel.py`)
| importar_plantilla / importar_fivgym / detectar_formato | ⛔ | **Ver Exclusiones #1** |

## Alertas  (`modulos/alertas.py`)
| whatsapp / correo / dias_restantes | 🟦 | Recordatorios (wa.me / mailto en vez de Chrome/WhatsApp Web) |

## SRI Selenium  (`sri/selenium_sri.py`)
| emitir_factura_sri (automatiza el portal web) | ⛔ | **Ver Exclusiones #3** |

---

## Exclusiones — qué se dejó fuera y por qué

1. **Import/Export a Excel** (`importar_plantilla`, `importar_fivgym`, `exportar_backup_excel`,
   `importar_desde_excel`). **Motivo**: dependen de formatos `.xlsx` propios del escritorio y de
   `openpyxl`, poco naturales en iPad. **Sustituto implementado**: *Exportar / Importar base de
   datos* (`gym.db`) en Configuración — el esquema del port es **idéntico** al del `.exe`, así que
   copiar el `gym.db` migra los datos **sin pérdida** y sin conversión. (Si más adelante se
   requiere Excel específicamente, se puede añadir con un parser CSV/xlsx.)

2. **PDF de reporte mensual** (`generar_pdf_reporte_mensual`). **Motivo**: reporte interno; el
   RIDE (factura) y el **PDF de ficha del cliente** ya están implementados con PDFKit. Se añade con
   el mismo enfoque cuando se necesite.
   *(Actualización: el PDF de ficha del cliente ya NO está excluido — se implementó como
   `FichaPDF` con botón **PDF** en cada cliente.)*

3. **Fallback Selenium del portal SRI** (`sri/selenium_sri.py`). **Motivo**: **no aplica en iOS**
   (no hay Selenium/automatización de navegador). La vía **oficial SOAP** (recepción + autorización)
   está implementada y es la correcta; el Selenium era un plan B del escritorio.

4. **Logo/branding y ventana de contacto** (`cambiar_logo`, `cargar_preview`, `mostrar_contacto`).
   **Motivo**: cosmético. El RIDE usa el encabezado de texto del emisor (razón social, RUC, dir.).
   Se puede añadir carga de logo (PhotosPicker) y una pantalla "Acerca de" fácilmente.

5. **Borrados masivos** (`borrar_todo` de suscripciones, `eliminar_facturas_no_validas`).
   **Motivo**: operaciones destructivas de alto riesgo. Se cubre con **borrado por elemento** +
   *Importar base de datos* (para reemplazar todo de forma controlada). Además quedó implementado
   el **PIN** (`AppSettings`) para proteger estas acciones si se decide exponerlas.

6. **Filtro por mes dentro de Pagos** (`on_mes_change`) y el **reloj en vivo** de Asistencia.
   **Motivo**: menores/cosméticos. El filtrado por mes/año ya existe en **Clientes Caducados**, y
   Pagos tiene búsqueda por cédula/nombre.

Todo lo demás del `.exe` está portado (✅) o adaptado a su equivalente iOS (🟦).
