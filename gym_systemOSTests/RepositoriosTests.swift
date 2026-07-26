//
//  RepositoriosTests.swift
//  gym_systemOSTests
//
//  Pruebas de integración de la capa de datos contra una BD en memoria.
//  Verifican que las reglas de negocio replican el sistema Python.
//

import XCTest
@testable import gym_systemOS

final class RepositoriosTests: XCTestCase {

    private func nuevaDB() -> AppDatabase { AppDatabase.empty() }

    func testClientesCRUD_yIDHuecoMasBajo() throws {
        let db = nuevaDB()
        let repo = ClientesRepo(db: db)

        XCTAssertTrue(repo.agregar(nombre: "Ana", cedula: "111", telefono: "099").ok)
        XCTAssertTrue(repo.agregar(nombre: "Beto", cedula: "222", telefono: "098").ok)
        // Cédula duplicada rechazada
        XCTAssertFalse(repo.agregar(nombre: "Otro", cedula: "111", telefono: "097").ok)

        var clientes = repo.ver()
        XCTAssertEqual(clientes.count, 2)
        XCTAssertEqual(clientes.map { $0.id }, [1, 2])

        // Al borrar el 1 y crear otro, se reutiliza el ID 1 (hueco más bajo).
        repo.eliminar(id: 1)
        XCTAssertTrue(repo.agregar(nombre: "Caro", cedula: "333", telefono: "096").ok)
        clientes = repo.ver()
        XCTAssertTrue(clientes.contains { $0.id == 1 && $0.nombre == "Caro" })

        // Búsqueda por nombre / cédula
        XCTAssertEqual(repo.buscar("caro").count, 1)
        XCTAssertEqual(repo.buscar("333").count, 1)
    }

    func testSuscripcionVencimiento_yPagos() throws {
        let db = nuevaDB()
        let cli = ClientesRepo(db: db)
        let mem = MembresiasRepo(db: db)
        let sus = SuscripcionesRepo(db: db)
        let pag = PagosRepo(db: db)

        XCTAssertTrue(cli.agregar(nombre: "Ana", cedula: "111", telefono: "1").ok)
        XCTAssertTrue(mem.crear(nombrePlan: "Mensual", precio: 30, duracionDias: 30).ok)
        let cid = cli.ver().first!.id!
        let mid = mem.ver().first!.id!

        // Asignar con pago inicial 10 → pendiente 20, vencimiento = hoy+30
        XCTAssertTrue(sus.asignar(clienteId: cid, membresiaId: mid, precioTotal: 30, pagado: 10).ok)
        let d = sus.verCompletas().first!
        XCTAssertEqual(d.pagado, 10, accuracy: 0.001)
        XCTAssertEqual(d.pendiente, 20, accuracy: 0.001)
        XCTAssertEqual(d.fechaVencimiento, Fechas.sumarDias(Fechas.hoyStr(), 30))

        // Registrar pago de 25 → se limita a precio_total (pagado 30, pendiente 0)
        XCTAssertTrue(pag.registrar(suscripcionId: d.id, monto: 25).ok)
        let d2 = sus.verCompletas().first!
        XCTAssertEqual(d2.pagado, 30, accuracy: 0.001)
        XCTAssertEqual(d2.pendiente, 0, accuracy: 0.001)
        // Ya pagada → nuevo pago rechazado
        XCTAssertFalse(pag.registrar(suscripcionId: d.id, monto: 5).ok)
        XCTAssertEqual(pag.historial(suscripcionId: d.id).count, 1)
    }

    func testCaducadosVsActivos() throws {
        let db = nuevaDB()
        let cli = ClientesRepo(db: db)
        let mem = MembresiasRepo(db: db)
        let sus = SuscripcionesRepo(db: db)

        _ = cli.agregar(nombre: "Vencido", cedula: "1", telefono: "1")
        _ = cli.agregar(nombre: "Activo", cedula: "2", telefono: "2")
        _ = mem.crear(nombrePlan: "Mensual", precio: 30, duracionDias: 30)
        let mid = mem.ver().first!.id!
        let ids = cli.ver().map { $0.id! }

        // Vencido: inicio hace 60 días → vence hace 30 días
        let inicioViejo = Fechas.sumarDias(Fechas.hoyStr(), -60)!
        _ = sus.asignar(clienteId: ids[0], membresiaId: mid, precioTotal: 30, pagado: 0, fechaInicio: inicioViejo)
        // Activo: inicio hoy → vence en 30 días
        _ = sus.asignar(clienteId: ids[1], membresiaId: mid, precioTotal: 30, pagado: 0)

        XCTAssertEqual(sus.contarVencidas(), 1)
        XCTAssertEqual(sus.contarActivos(), 1)
        XCTAssertEqual(sus.caducadasDetalle().count, 1)
        XCTAssertEqual(sus.caducadasDetalle().first?.nombre, "Vencido")
        // El caducado lleva ~30 días vencido
        let dias = sus.caducadasDetalle().first?.diasVencido ?? 0
        XCTAssertTrue((28...32).contains(dias))
    }

    func testSecuencialAtomico() throws {
        let db = nuevaDB()
        let cfg = ConfiguracionRepo(db: db)
        _ = cfg.guardar(ConfiguracionSRI(id: 1, ruc: "9999999999001", razonSocial: "GYM",
                                         codigoEstablecimiento: "001", puntoEmision: "001",
                                         ambiente: 1, tipoEmision: 1, siguienteSecuencial: 5, smtpPort: 587))
        XCTAssertEqual(cfg.reservarSiguienteSecuencial(), 5)
        XCTAssertEqual(cfg.reservarSiguienteSecuencial(), 6)
        XCTAssertEqual(cfg.obtener()?.siguienteSecuencial, 7)
    }
}
