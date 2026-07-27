//
//  FacturacionView.swift
//  gym_systemOS
//
//  Módulo Facturación SRI: lista de comprobantes + compositor + emisión
//  (firma XAdES-BES, envío SOAP, polling de autorización).
//

import SwiftUI

struct FacturacionView: View {
    @Environment(\.appDatabase) private var db
    @StateObject private var vm = FacturacionViewModel()
    @State private var mostrarNueva = false
    @State private var compartir: IdentifiableURL?

    var body: some View {
        ZStack {
            List {
                if !vm.puedeEmitir {
                    Section {
                        Label("Configura el emisor y carga el certificado .p12 en Configuración para poder emitir.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                if vm.facturas.isEmpty {
                    ContentUnavailableView("Sin comprobantes", systemImage: "doc.text",
                        description: Text("Crea una factura con el botón +."))
                } else {
                    ForEach(vm.facturas) { f in
                        FacturaFila(f: f)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { vm.eliminar(f) } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                if (f.estado ?? "") != "AUTORIZADO", let id = f.id {
                                    Button { Task { await vm.emitir(facturaId: id) } } label: {
                                        Label("Emitir", systemImage: "paperplane")
                                    }.tint(.green)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { compartirRide(f) } label: { Label("RIDE", systemImage: "square.and.arrow.up") }
                                    .tint(.blue)
                            }
                            .contextMenu {
                                Button { compartirRide(f) } label: { Label("Compartir RIDE (PDF)", systemImage: "doc.richtext") }
                                if (f.estado ?? "") != "AUTORIZADO", let id = f.id {
                                    Button { Task { await vm.emitir(facturaId: id) } } label: { Label("Emitir", systemImage: "paperplane") }
                                }
                            }
                    }
                }
            }
            .disabled(vm.emitiendo)

            if vm.emitiendo {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(vm.progreso).font(.callout)
                    Text("Esto puede tardar hasta ~40 s (polling de autorización).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationTitle("Facturación SRI")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNueva = true } label: { Label("Nueva", systemImage: "plus") }
                    .disabled(vm.emitiendo)
            }
        }
        .task { vm.setup(db: db) }
        .sheet(isPresented: $mostrarNueva) {
            NuevaFacturaSheet(clientes: vm.clientes,
                onEmitir: { comprador, lineas in Task { await vm.crearYEmitir(comprador: comprador, lineas: lineas) } },
                onBorrador: { comprador, lineas in vm.guardarBorrador(comprador: comprador, lineas: lineas) })
        }
        .sheet(item: $compartir) { item in ShareSheet(items: [item.url]) }
        .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) { Button("OK", role: .cancel) {} }
    }

    private func compartirRide(_ f: Factura) {
        guard let data = vm.rideData(f) else { return }
        let numero = "\(f.establecimiento ?? "001")-\(f.puntoEmision ?? "001")-\(f.secuencial ?? "")"
        if let url = TempFiles.escribir(data, nombre: "RIDE_\(numero).pdf") {
            compartir = IdentifiableURL(url: url)
        }
    }
}

private struct FacturaFila: View {
    let f: Factura
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(numero).font(.headline)
                Text(f.razonSocial ?? "—").font(.subheadline).foregroundStyle(.secondary)
                if let ac = f.claveAcceso, !ac.isEmpty {
                    Text(ac).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text((f.total ?? 0).comoMoneda).font(.headline)
                Text(f.estado ?? "BORRADOR").font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.2), in: Capsule())
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
    }

    private var numero: String {
        "\(f.establecimiento ?? "001")-\(f.puntoEmision ?? "001")-\((f.secuencial ?? "").leftPad(9))"
    }
    private var color: Color {
        switch (f.estado ?? "").uppercased() {
        case "AUTORIZADO": return .green
        case "PENDIENTE": return .orange
        case "BORRADOR": return .gray
        default: return .red
        }
    }
}

private extension String {
    func leftPad(_ n: Int) -> String {
        count >= n ? self : String(repeating: "0", count: n - count) + self
    }
}

// MARK: - Compositor

private struct NuevaFacturaSheet: View {
    let clientes: [Cliente]
    let onEmitir: (DatosComprador, [LineaFactura]) -> Void
    let onBorrador: (DatosComprador, [LineaFactura]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comprador = DatosComprador()
    @State private var consumidorFinal = false
    @State private var lineas: [LineaFactura] = [LineaFactura()]

    var body: some View {
        NavigationStack {
            Form {
                Section("Comprador") {
                    Toggle("Consumidor final", isOn: $consumidorFinal)
                        .onChange(of: consumidorFinal) { _, nuevo in
                            if nuevo {
                                comprador.tipoIdentificacion = "07"
                                comprador.identificacion = "9999999999999"
                                comprador.razonSocial = "CONSUMIDOR FINAL"
                            } else {
                                comprador.tipoIdentificacion = "05"
                                comprador.identificacion = ""
                                comprador.razonSocial = ""
                            }
                        }
                    if !consumidorFinal {
                        Picker("Cliente registrado", selection: Binding(
                            get: { comprador.clienteId },
                            set: { id in
                                comprador.clienteId = id
                                if let c = clientes.first(where: { $0.id == id }) {
                                    comprador.identificacion = c.cedula ?? ""
                                    comprador.razonSocial = c.nombre ?? ""
                                    comprador.correo = c.correo ?? ""
                                    comprador.telefono = c.telefono ?? ""
                                }
                            })) {
                            Text("— (manual)").tag(Int64?.none)
                            ForEach(clientes) { c in Text(c.nombre ?? "—").tag(Int64?.some(c.id ?? -1)) }
                        }
                        TextField("Identificación", text: $comprador.identificacion).keyboardType(.numbersAndPunctuation)
                        TextField("Razón social / Nombre", text: $comprador.razonSocial)
                        TextField("Correo", text: $comprador.correo).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        TextField("Teléfono", text: $comprador.telefono).keyboardType(.phonePad)
                        TextField("Dirección", text: $comprador.direccion)
                    }
                }

                Section("Detalle") {
                    ForEach($lineas) { $l in
                        VStack(spacing: 6) {
                            TextField("Descripción", text: $l.descripcion)
                            HStack {
                                stepperNum("Cant.", value: $l.cantidad)
                                montoField("P. unit.", value: $l.precioUnitario)
                            }
                            Picker("IVA", selection: $l.porcentajeIva) {
                                Text("15%").tag(15.0); Text("0%").tag(0.0)
                            }.pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { lineas.remove(atOffsets: $0) }
                    Button { lineas.append(LineaFactura()) } label: {
                        Label("Agregar línea", systemImage: "plus.circle")
                    }
                }

                Section("Total") {
                    LabeledContent("Subtotal", value: subtotal.comoMoneda)
                    LabeledContent("IVA 15%", value: iva.comoMoneda)
                    LabeledContent("Total", value: total.comoMoneda).bold()
                }
            }
            .navigationTitle("Nueva factura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Borrador") { onBorrador(comprador, lineas); dismiss() }
                        .disabled(comprador.razonSocial.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Emitir") { onEmitir(comprador, lineas); dismiss() }
                        .disabled(comprador.razonSocial.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var subtotal: Double { lineas.reduce(0) { $0 + $1.cantidad * $1.precioUnitario } }
    private var iva: Double { lineas.reduce(0) { $0 + ($1.porcentajeIva == 15 ? $1.cantidad * $1.precioUnitario * 0.15 : 0) } }
    private var total: Double { subtotal + iva }

    private func stepperNum(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number).keyboardType(.decimalPad).frame(width: 60)
        }
    }
    private func montoField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number).keyboardType(.decimalPad)
        }
    }
}
