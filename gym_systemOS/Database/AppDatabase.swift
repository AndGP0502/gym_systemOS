//
//  AppDatabase.swift
//  gym_systemOS
//
//  Capa de persistencia local (GRDB / SQLite embebido).
//  La migración `v1` replica EXACTAMENTE el esquema auditado de gym.db
//  (ver ipad_port/AUDIT.md §1) para permitir importar/sincronizar en el futuro.
//

import Foundation
import GRDB

/// Punto único de acceso a la base local.
final class AppDatabase: Sendable {

    /// GRDB writer (DatabaseQueue). Sendable: seguro entre hilos.
    let dbWriter: any DatabaseWriter

    init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try Self.migrator.migrate(dbWriter)
    }

    /// Acceso de solo lectura para las vistas / repos.
    var reader: any DatabaseReader { dbWriter }

    // MARK: - Bootstrap

    /// Resultado de abrir la BD en disco. Se evalúa una sola vez al arrancar.
    static let bootstrapResult: Result<AppDatabase, Error> = {
        Result { try AppDatabase(makeOnDiskWriter()) }
    }()

    /// Instancia compartida (solo válida si `bootstrapResult` fue `.success`).
    static var shared: AppDatabase { (try? bootstrapResult.get()) ?? .empty() }

    /// BD en memoria (default de Environment y para previews/tests).
    static func empty() -> AppDatabase {
        try! AppDatabase(DatabaseQueue())
    }

    /// Ruta en disco: Application Support/gym.db (persistente en el dispositivo).
    private static func makeOnDiskWriter() throws -> DatabaseQueue {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        let dir = appSupport.appendingPathComponent("GymSystem", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("gym.db")
        var config = Configuration()
        config.foreignKeysEnabled = true
        return try DatabaseQueue(path: dbURL.path, configuration: config)
    }

    // MARK: - Migraciones (esquema exacto de gym.db)

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // En desarrollo, borra y recrea si cambia el esquema.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_esquema_gym") { db in
            // ---- Núcleo de gimnasio ----
            try db.execute(sql: """
                CREATE TABLE clientes(
                    id             INTEGER PRIMARY KEY AUTOINCREMENT,
                    nombre         TEXT,
                    cedula         TEXT,
                    telefono       TEXT,
                    fecha_registro TEXT,
                    correo         TEXT,
                    edad           REAL,
                    fecha_nacimiento TEXT,
                    sexo           TEXT
                );
            """)

            try db.execute(sql: """
                CREATE TABLE membresias(
                    id            INTEGER PRIMARY KEY AUTOINCREMENT,
                    nombre_plan   TEXT,
                    precio        REAL,
                    duracion_dias INTEGER
                );
            """)

            try db.execute(sql: """
                CREATE TABLE suscripciones(
                    id                INTEGER PRIMARY KEY AUTOINCREMENT,
                    cliente_id        INTEGER,
                    membresia_id      INTEGER,
                    fecha_inicio      TEXT,
                    fecha_vencimiento TEXT,
                    precio_total      REAL,
                    pagado            REAL,
                    pendiente         REAL,
                    FOREIGN KEY(cliente_id)   REFERENCES clientes(id),
                    FOREIGN KEY(membresia_id) REFERENCES membresias(id)
                );
            """)

            try db.execute(sql: """
                CREATE TABLE pagos(
                    id             INTEGER PRIMARY KEY AUTOINCREMENT,
                    suscripcion_id INTEGER,
                    monto          REAL,
                    fecha_pago     TEXT,
                    FOREIGN KEY(suscripcion_id) REFERENCES suscripciones(id)
                );
            """)

            try db.execute(sql: """
                CREATE TABLE ficha_cliente(
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    cliente_id      INTEGER UNIQUE,
                    objetivo        TEXT,
                    estado_fisico   TEXT,
                    condiciones     TEXT,
                    notas           TEXT,
                    foto_ruta       TEXT,
                    peso_kg         REAL,
                    altura_m        REAL,
                    cir_abdominal   REAL,
                    status_fisico   TEXT,
                    objetivo_2      TEXT,
                    peso_ideal      REAL,
                    lesion          TEXT,
                    cardiovascular  TEXT,
                    asfixia         TEXT,
                    asmatico        TEXT,
                    medicacion      TEXT,
                    mareos          TEXT,
                    FOREIGN KEY(cliente_id) REFERENCES clientes(id)
                );
            """)

            try db.execute(sql: """
                CREATE TABLE historial_medidas(
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    cliente_id  INTEGER,
                    fecha       TEXT,
                    peso_kg     REAL,
                    altura_cm   REAL,
                    imc         REAL,
                    notas       TEXT,
                    FOREIGN KEY(cliente_id) REFERENCES clientes(id)
                );
            """)

            try db.execute(sql: """
                CREATE TABLE asistencia(
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    cliente_id  INTEGER,
                    cedula      TEXT,
                    nombre      TEXT,
                    fecha       TEXT,
                    hora        TEXT,
                    estado      TEXT,
                    vencimiento TEXT,
                    FOREIGN KEY(cliente_id) REFERENCES clientes(id)
                );
            """)

            // ---- Facturación SRI ----
            try db.execute(sql: """
                CREATE TABLE configuracion_sri(
                    id                     INTEGER PRIMARY KEY DEFAULT 1,
                    ruc                    TEXT NOT NULL,
                    razon_social           TEXT NOT NULL,
                    nombre_comercial       TEXT,
                    direccion_matriz       TEXT,
                    direccion_sucursal     TEXT,
                    codigo_establecimiento TEXT DEFAULT '001',
                    punto_emision          TEXT DEFAULT '001',
                    ambiente               INTEGER DEFAULT 1,
                    tipo_emision           INTEGER DEFAULT 1,
                    ruta_certificado       TEXT,
                    clave_certificado      TEXT,
                    siguiente_secuencial   INTEGER DEFAULT 1,
                    correo_remitente       TEXT,
                    smtp_host              TEXT,
                    smtp_port              INTEGER DEFAULT 587,
                    smtp_usuario           TEXT,
                    smtp_clave             TEXT,
                    ruta_xmls              TEXT,
                    ruta_rides             TEXT,
                    clave_sri              TEXT,
                    apellido_paterno       TEXT,
                    apellido_materno       TEXT,
                    primer_nombre          TEXT,
                    segundo_nombre         TEXT,
                    correo_electronico     TEXT,
                    telefono_conv          TEXT,
                    telefono_celular       TEXT,
                    direccion_domicilio    TEXT
                );
            """)

            try db.execute(sql: """
                CREATE TABLE facturas(
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    clave_acceso        TEXT UNIQUE,
                    numero_autorizacion TEXT,
                    estado              TEXT DEFAULT 'BORRADOR',
                    ambiente            INTEGER DEFAULT 2,
                    fecha_emision       TEXT,
                    fecha_autorizacion  TEXT,
                    ruc_emisor          TEXT,
                    razon_social_emisor TEXT,
                    tipo_identificacion TEXT DEFAULT '05',
                    identificacion      TEXT,
                    razon_social        TEXT,
                    correo              TEXT,
                    telefono            TEXT,
                    direccion           TEXT,
                    subtotal_0          REAL DEFAULT 0,
                    subtotal_15         REAL DEFAULT 0,
                    subtotal_no_iva     REAL DEFAULT 0,
                    descuento_total     REAL DEFAULT 0,
                    iva_15              REAL DEFAULT 0,
                    total               REAL DEFAULT 0,
                    establecimiento     TEXT DEFAULT '001',
                    punto_emision       TEXT DEFAULT '001',
                    secuencial          TEXT,
                    ruta_xml            TEXT,
                    ruta_xml_autorizado TEXT,
                    ruta_ride           TEXT,
                    cliente_id          INTEGER,
                    observacion         TEXT,
                    FOREIGN KEY(cliente_id) REFERENCES clientes(id)
                );
            """)

            try db.execute(sql: """
                CREATE TABLE factura_detalle(
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    factura_id      INTEGER NOT NULL,
                    descripcion     TEXT NOT NULL,
                    cantidad        REAL NOT NULL,
                    precio_unitario REAL NOT NULL,
                    descuento       REAL DEFAULT 0,
                    tiene_iva       INTEGER DEFAULT 1,
                    porcentaje_iva  REAL DEFAULT 15,
                    subtotal        REAL NOT NULL,
                    iva             REAL NOT NULL,
                    total           REAL NOT NULL,
                    FOREIGN KEY(factura_id) REFERENCES facturas(id)
                );
            """)
        }

        return migrator
    }
}
