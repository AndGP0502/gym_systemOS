//
//  ModulosTests.swift
//  gym_systemOSTests
//
//  Pruebas de los módulos añadidos para paridad total: Ficha/Medidas,
//  Asistencia, Dashboard, cambiar plan/resetear/editar fechas, y el
//  orquestador de facturación (mock SOAP, sin red).
//

import XCTest
@testable import gym_systemOS

final class ModulosTests: XCTestCase {

    private func nuevaDB() -> AppDatabase { AppDatabase.empty() }

    private func clienteYPlan(_ db: AppDatabase, dur: Int = 30, precio: Double = 30) -> (Int64, Int64) {
        let cli = ClientesRepo(db: db); let mem = MembresiasRepo(db: db)
        _ = cli.agregar(nombre: "Ana", cedula: "111", telefono: "1")
        _ = mem.crear(nombrePlan: "Mensual", precio: precio, duracionDias: dur)
        return (cli.ver().first!.id!, mem.ver().first!.id!)
    }

    // MARK: - Ficha + medidas

    func testFichaYMedidas() throws {
        let db = nuevaDB()
        let (cid, _) = clienteYPlan(db)
        let repo = FichaRepo(db: db)

        var f = FichaCliente(clienteId: cid)
        f.objetivo = "Bajar de peso"; f.lesion = "Ninguna"
        XCTAssertTrue(repo.guardar(f).ok)

        let leida = repo.obtener(clienteId: cid)
        XCTAssertEqual(leida?.objetivo, "Bajar de peso")

        // Upsert: no duplica, actualiza
        var f2 = leida!; f2.objetivo = "Ganar masa"
        XCTAssertTrue(repo.guardar(f2).ok)
        XCTAssertEqual(repo.obtener(clienteId: cid)?.objetivo, "Ganar masa")

        // IMC: 80 kg / (1.80 m)^2 = 24.69
        let imc = repo.agregarMedida(clienteId: cid, pesoKg: 80, alturaCm: 180)
        XCTAssertEqual(imc, 24.69, accuracy: 0.01)
        XCTAssertEqual(repo.historial(clienteId: cid).count, 1)
        let mid = repo.historial(clienteId: cid).first!.id!
        XCTAssertTrue(repo.eliminarMedida(id: mid))
        XCTAssertEqual(repo.historial(clienteId: cid).count, 0)
    }

    // MARK: - Asistencia

    func testAsistencia() throws {
        let db = nuevaDB()
        let (cid, mid) = clienteYPlan(db)
        let asi = AsistenciaRepo(db: db)

        // Sin suscripción → SIN MEMBRESÍA
        var r = asi.registrar(cedula: "111")
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.estado, "SIN MEMBRESÍA")

        // Con suscripción activa → ACTIVO
        _ = SuscripcionesRepo(db: db).asignar(clienteId: cid, membresiaId: mid, precioTotal: 30, pagado: 30)
        r = asi.registrar(cedula: "111")
        XCTAssertEqual(r.estado, "ACTIVO")
        XCTAssertEqual(r.nombre, "Ana")

        // Cédula inexistente → error
        XCTAssertFalse(asi.registrar(cedula: "000").ok)

        XCTAssertEqual(asi.historial().count, 2)
    }

    // MARK: - Cambiar plan / resetear / editar fechas

    func testCambiarPlanResetearFechas() throws {
        let db = nuevaDB()
        let (cid, mid) = clienteYPlan(db, dur: 30, precio: 30)
        let sus = SuscripcionesRepo(db: db); let pag = PagosRepo(db: db); let mem = MembresiasRepo(db: db)
        _ = sus.asignar(clienteId: cid, membresiaId: mid, precioTotal: 30, pagado: 10)
        let sid = sus.verCompletas().first!.id

        // Nuevo plan trimestral (90 días, $80)
        _ = mem.crear(nombrePlan: "Trimestral", precio: 80, duracionDias: 90)
        let nuevoPlan = mem.ver().first { $0.nombrePlan == "Trimestral" }!.id!
        XCTAssertTrue(pag.cambiarPlan(suscripcionId: sid, nuevoPlanId: nuevoPlan).ok)
        var d = sus.verCompletas().first!
        XCTAssertEqual(d.precioTotal, 80, accuracy: 0.001)
        XCTAssertEqual(d.pendiente, 70, accuracy: 0.001)   // 80 - 10 pagado

        // Resetear pago
        XCTAssertTrue(pag.resetearPago(suscripcionId: sid))
        d = sus.verCompletas().first!
        XCTAssertEqual(d.pagado, 0, accuracy: 0.001)
        XCTAssertEqual(d.pendiente, 80, accuracy: 0.001)

        // Editar fechas
        XCTAssertTrue(sus.editarFechas(id: sid, fechaInicio: "2026-01-01", fechaVencimiento: "2026-12-31").ok)
        d = sus.verCompletas().first!
        XCTAssertEqual(d.fechaInicio, "2026-01-01")
        XCTAssertEqual(d.fechaVencimiento, "2026-12-31")
    }

    // MARK: - Dashboard

    func testDashboard() throws {
        let db = nuevaDB()
        let (cid, mid) = clienteYPlan(db)
        _ = SuscripcionesRepo(db: db).asignar(clienteId: cid, membresiaId: mid, precioTotal: 30, pagado: 30)
        let r = DashboardRepo(db: db).resumen()
        XCTAssertEqual(r.clientes, 1)
        XCTAssertEqual(r.activos, 1)
        XCTAssertEqual(r.planes, 1)
        XCTAssertEqual(r.recaudadoTotal, 30, accuracy: 0.001)
    }

    // MARK: - Editar pago

    func testEditarPago() throws {
        let db = nuevaDB()
        let (cid, mid) = clienteYPlan(db, dur: 30, precio: 30)
        let sus = SuscripcionesRepo(db: db); let pag = PagosRepo(db: db)
        _ = sus.asignar(clienteId: cid, membresiaId: mid, precioTotal: 30, pagado: 0)
        let sid = sus.verCompletas().first!.id
        _ = pag.registrar(suscripcionId: sid, monto: 10)
        let pid = pag.historial(suscripcionId: sid).first!.id!

        // Editar 10 → 25: la suscripción sube a pagado 25, pendiente 5
        XCTAssertTrue(pag.editarPago(id: pid, nuevoMonto: 25).ok)
        let d = sus.verCompletas().first!
        XCTAssertEqual(d.pagado, 25, accuracy: 0.001)
        XCTAssertEqual(d.pendiente, 5, accuracy: 0.001)
        XCTAssertEqual(pag.historial(suscripcionId: sid).first?.monto, 25)
    }

    func testEditarMontosSuscripcion() throws {
        let db = nuevaDB()
        let (cid, mid) = clienteYPlan(db, dur: 30, precio: 30)
        let sus = SuscripcionesRepo(db: db)
        _ = sus.asignar(clienteId: cid, membresiaId: mid, precioTotal: 30, pagado: 10)
        let sid = sus.verCompletas().first!.id
        // Edición directa: precio 50, pagado 20 → pendiente 30
        XCTAssertTrue(sus.editarMontos(id: sid, precioTotal: 50, pagado: 20).ok)
        let d = sus.verCompletas().first!
        XCTAssertEqual(d.precioTotal, 50, accuracy: 0.001)
        XCTAssertEqual(d.pagado, 20, accuracy: 0.001)
        XCTAssertEqual(d.pendiente, 30, accuracy: 0.001)
    }

    func testResumenClientes() throws {
        let db = nuevaDB()
        let cli = ClientesRepo(db: db); let mem = MembresiasRepo(db: db); let sus = SuscripcionesRepo(db: db)
        _ = cli.agregar(nombre: "Activo", cedula: "1", telefono: "1")
        _ = cli.agregar(nombre: "Vencido", cedula: "2", telefono: "2")
        _ = cli.agregar(nombre: "SinSub", cedula: "3", telefono: "3")
        _ = mem.crear(nombrePlan: "M", precio: 30, duracionDias: 30)
        let mid = mem.ver().first!.id!
        let ids = cli.ver().map { $0.id! }
        _ = sus.asignar(clienteId: ids[0], membresiaId: mid, precioTotal: 30, pagado: 30) // activo
        _ = sus.asignar(clienteId: ids[1], membresiaId: mid, precioTotal: 30, pagado: 0,
                        fechaInicio: Fechas.sumarDias(Fechas.hoyStr(), -60)) // vencido + deuda
        let r = cli.resumen()
        XCTAssertEqual(r.total, 3)
        XCTAssertEqual(r.activos, 1)
        XCTAssertEqual(r.vencidos, 1)
        XCTAssertEqual(r.conDeuda, 1)
    }

    // MARK: - Coherencia: borrado en cascada

    func testBorradoClienteEnCascada() throws {
        let db = nuevaDB()
        let cli = ClientesRepo(db: db); let mem = MembresiasRepo(db: db)
        let sus = SuscripcionesRepo(db: db); let pag = PagosRepo(db: db)
        let ficha = FichaRepo(db: db); let asi = AsistenciaRepo(db: db)

        _ = cli.agregar(nombre: "Ana", cedula: "111", telefono: "1")
        _ = mem.crear(nombrePlan: "M", precio: 30, duracionDias: 30)
        let cid = cli.ver().first!.id!
        let mid = mem.ver().first!.id!
        _ = sus.asignar(clienteId: cid, membresiaId: mid, precioTotal: 30, pagado: 10)
        let sid = sus.verCompletas().first!.id
        _ = pag.registrar(suscripcionId: sid, monto: 5)
        _ = ficha.guardar(FichaCliente(clienteId: cid, objetivo: "X"))
        _ = ficha.agregarMedida(clienteId: cid, pesoKg: 80, alturaCm: 180)
        _ = asi.registrar(cedula: "111")

        // Factura del cliente (comprobante fiscal): debe SOBREVIVIR desvinculada.
        let facRepo = FacturacionRepo(db: db)
        var f = Factura(); f.clienteId = cid; f.razonSocial = "Ana"; f.total = 10
        _ = facRepo.guardarFactura(f, detalles: [])

        XCTAssertEqual(sus.verCompletas().count, 1)

        // Borrar el cliente debe eliminar TODO lo suyo (sin datos huérfanos).
        XCTAssertTrue(cli.eliminar(id: cid))
        XCTAssertEqual(cli.contar(), 0)
        XCTAssertEqual(sus.verCompletas().count, 0)
        XCTAssertEqual(sus.contarVencidas() + sus.contarActivos(), 0)  // dashboard coherente
        XCTAssertEqual(pag.historial(suscripcionId: sid).count, 0)
        XCTAssertNil(ficha.obtener(clienteId: cid))
        XCTAssertEqual(ficha.historial(clienteId: cid).count, 0)
        XCTAssertEqual(asi.historialDe(clienteId: cid).count, 0)
        // La factura sigue existiendo (desvinculada del cliente).
        XCTAssertEqual(facRepo.verFacturas().count, 1)
        XCTAssertNil(facRepo.verFacturas().first?.clienteId)
    }

    func testNoEliminarPlanEnUso() throws {
        let db = nuevaDB()
        let (cid, mid) = clienteYPlan(db)
        let mem = MembresiasRepo(db: db); let sus = SuscripcionesRepo(db: db)
        _ = sus.asignar(clienteId: cid, membresiaId: mid, precioTotal: 30, pagado: 0)
        // Plan en uso → no se puede eliminar
        XCTAssertFalse(mem.eliminar(id: mid).ok)
        XCTAssertEqual(mem.ver().count, 1)
        // Sin suscripciones → sí se elimina
        sus.eliminar(id: sus.verCompletas().first!.id)
        XCTAssertTrue(mem.eliminar(id: mid).ok)
        XCTAssertEqual(mem.ver().count, 0)
    }

    // MARK: - Orquestador de facturación (mock SOAP)

    private func prepararFactura(_ db: AppDatabase, siguienteSecuencial: Int = 1) -> Int64 {
        let cfg = ConfiguracionRepo(db: db)
        _ = cfg.guardar(ConfiguracionSRI(id: 1, ruc: "9999999999001", razonSocial: "GYM",
            codigoEstablecimiento: "001", puntoEmision: "001", ambiente: 1, tipoEmision: 1,
            siguienteSecuencial: siguienteSecuencial, smtpPort: 587))
        var f = Factura()
        f.fechaEmision = Fechas.hoyStr(); f.ambiente = 1; f.identificacion = "9999999999999"
        f.razonSocial = "CONSUMIDOR FINAL"; f.tipoIdentificacion = "07"
        f.rucEmisor = "9999999999001"; f.total = 11.5; f.subtotal15 = 10; f.iva15 = 1.5
        let det = FacturaDetalle(facturaId: nil, descripcion: "Mensualidad", cantidad: 1,
            precioUnitario: 10, descuento: 0, tieneIva: 1, porcentajeIva: 15, subtotal: 10, iva: 1.5, total: 11.5)
        return FacturacionRepo(db: db).guardarFactura(f, detalles: [det])!.id
    }

    func testOrquestadorHappyPath() async throws {
        let db = nuevaDB()
        let fid = prepararFactura(db)
        var svc = FacturaService(db: db)
        svc.firmarXML = { $0 }                                   // no firma real
        svc.esperar = { _ in }                                    // sin sleeps
        svc.enviar = { _, _ in RecepcionResult(estado: "RECIBIDA", mensajes: []) }
        svc.autorizar = { _, _ in
            AutorizacionResult(estado: "AUTORIZADO", numeroAutorizacion: "AUT-123",
                               fechaAutorizacion: "2026-07-26", xmlAutorizado: "", mensajes: [])
        }
        let r = await svc.procesar(facturaId: fid)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.estado, "AUTORIZADO")
        XCTAssertEqual(r.numeroAutorizacion, "AUT-123")
    }

    /// El SRI rechaza con error 45 la primera vez → el orquestador reserva un
    /// nuevo secuencial y reintenta hasta autorizar.
    func testOrquestadorReintentoSecuencial() async throws {
        let db = nuevaDB()
        let fid = prepararFactura(db, siguienteSecuencial: 1)
        let contador = Contador()
        var svc = FacturaService(db: db)
        svc.firmarXML = { $0 }
        svc.esperar = { _ in }
        svc.enviar = { _, _ in RecepcionResult(estado: "RECIBIDA", mensajes: []) }
        svc.autorizar = { _, _ in
            contador.n += 1
            if contador.n == 1 {
                return AutorizacionResult(estado: "NO AUTORIZADO", numeroAutorizacion: "",
                    fechaAutorizacion: "", xmlAutorizado: "",
                    mensajes: [SRIMensaje(identificador: "45", mensaje: "SECUENCIAL REGISTRADO", tipo: "ERROR", informacionAdicional: "")])
            }
            return AutorizacionResult(estado: "AUTORIZADO", numeroAutorizacion: "AUT-999",
                fechaAutorizacion: "2026-07-26", xmlAutorizado: "", mensajes: [])
        }
        let r = await svc.procesar(facturaId: fid)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.numeroAutorizacion, "AUT-999")
        XCTAssertGreaterThanOrEqual(contador.n, 2)   // hubo reintento
        // El contador de secuencial avanzó por la reserva del reintento
        XCTAssertGreaterThanOrEqual(ConfiguracionRepo(db: db).obtener()?.siguienteSecuencial ?? 0, 3)
    }
}

private final class Contador: @unchecked Sendable { var n = 0 }
