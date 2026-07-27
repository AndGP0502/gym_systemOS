//
//  FichaView.swift
//  gym_systemOS
//
//  Ficha del cliente: datos físicos/médicos + foto + historial de medidas (IMC).
//  Port de modulos/ficha_cliente.py + ui/ficha_ui.py. Se abre desde Clientes.
//

import SwiftUI
import PhotosUI
import Combine

@MainActor
final class FichaViewModel: ObservableObject {
    @Published var ficha = FichaCliente()
    @Published var historial: [HistorialMedida] = []
    @Published var fotoData: Data?
    @Published var mensaje: String?
    @Published var mostrarMensaje = false

    private var repo: FichaRepo?
    private var clienteId: Int64 = 0

    func setup(db: AppDatabase, clienteId: Int64) {
        guard repo == nil else { return }
        repo = FichaRepo(db: db)
        self.clienteId = clienteId
        ficha = repo?.obtener(clienteId: clienteId) ?? FichaCliente(clienteId: clienteId)
        fotoData = repo?.fotoData(clienteId: clienteId)
        historial = repo?.historial(clienteId: clienteId) ?? []
    }

    func guardar() {
        guard let repo else { return }
        ficha.clienteId = clienteId
        let r = repo.guardar(ficha)
        notificar(r.mensaje)
    }

    func guardarFoto(_ data: Data) {
        guard let repo else { return }
        if let ruta = repo.guardarFoto(clienteId: clienteId, data: data) {
            ficha.fotoRuta = ruta
            fotoData = data
            _ = repo.guardar(ficha)
        }
    }

    func agregarMedida(peso: Double, altura: Double, notas: String) {
        guard let repo else { return }
        let imc = repo.agregarMedida(clienteId: clienteId, pesoKg: peso, alturaCm: altura, notas: notas)
        historial = repo.historial(clienteId: clienteId)
        notificar(String(format: "Medida agregada. IMC = %.2f", imc))
    }

    func eliminarMedida(_ id: Int64) {
        repo?.eliminarMedida(id: id)
        historial = repo?.historial(clienteId: clienteId) ?? []
    }

    private func notificar(_ m: String) { mensaje = m; mostrarMensaje = true }
}

struct FichaView: View {
    let cliente: Cliente
    @Environment(\.appDatabase) private var db
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = FichaViewModel()

    @State private var fotoItem: PhotosPickerItem?
    @State private var nuevoPeso = ""
    @State private var nuevaAltura = ""
    @State private var nuevaNota = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Foto") {
                    HStack {
                        if let d = vm.fotoData, let ui = UIImage(data: d) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(width: 90, height: 90).clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill").resizable()
                                .frame(width: 90, height: 90).foregroundStyle(.tint.opacity(0.5))
                        }
                        PhotosPicker(selection: $fotoItem, matching: .images) {
                            Label("Cambiar foto", systemImage: "photo")
                        }
                    }
                }

                Section("Objetivo y estado") {
                    TextField("Objetivo", text: bind(\.objetivo))
                    TextField("Objetivo secundario", text: bind(\.objetivo2))
                    TextField("Estado físico", text: bind(\.estadoFisico))
                    TextField("Status físico", text: bind(\.statusFisico))
                }

                Section("Medidas base") {
                    numField("Peso (kg)", \.pesoKg)
                    numField("Altura (m)", \.alturaM)
                    numField("Cir. abdominal (cm)", \.cirAbdominal)
                    numField("Peso ideal (kg)", \.pesoIdeal)
                }

                Section("Condiciones médicas") {
                    TextField("Condiciones", text: bind(\.condiciones))
                    TextField("Lesión", text: bind(\.lesion))
                    TextField("Cardiovascular", text: bind(\.cardiovascular))
                    TextField("Asfixia", text: bind(\.asfixia))
                    TextField("Asmático", text: bind(\.asmatico))
                    TextField("Medicación", text: bind(\.medicacion))
                    TextField("Mareos", text: bind(\.mareos))
                    TextField("Notas", text: bind(\.notas), axis: .vertical)
                }

                Section("Historial de medidas (IMC)") {
                    HStack {
                        TextField("Peso kg", text: $nuevoPeso).keyboardType(.decimalPad).frame(width: 80)
                        TextField("Altura cm", text: $nuevaAltura).keyboardType(.decimalPad).frame(width: 80)
                        TextField("Nota", text: $nuevaNota)
                        Button {
                            let p = Double(nuevoPeso.replacingOccurrences(of: ",", with: ".")) ?? 0
                            let a = Double(nuevaAltura.replacingOccurrences(of: ",", with: ".")) ?? 0
                            if p > 0 && a > 0 { vm.agregarMedida(peso: p, altura: a, notas: nuevaNota)
                                nuevoPeso = ""; nuevaAltura = ""; nuevaNota = "" }
                        } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(nuevoPeso.isEmpty || nuevaAltura.isEmpty)
                    }
                    ForEach(vm.historial) { m in
                        HStack {
                            Text(m.fecha ?? "—").font(.caption)
                            Spacer()
                            Text(String(format: "%.1f kg · %.0f cm · IMC %.1f",
                                        m.pesoKg ?? 0, m.alturaCm ?? 0, m.imc ?? 0)).font(.caption)
                        }
                        .swipeActions {
                            Button(role: .destructive) { if let id = m.id { vm.eliminarMedida(id) } } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ficha — \(cliente.nombre ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { vm.guardar() } }
            }
            .task { vm.setup(db: db, clienteId: cliente.id ?? 0) }
            .onChange(of: fotoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        vm.guardarFoto(data)
                    }
                }
            }
            .alert(vm.mensaje ?? "", isPresented: $vm.mostrarMensaje) { Button("OK", role: .cancel) {} }
        }
    }

    // Bindings a campos opcionales de texto/número de la ficha.
    private func bind(_ kp: WritableKeyPath<FichaCliente, String?>) -> Binding<String> {
        Binding(get: { vm.ficha[keyPath: kp] ?? "" },
                set: { vm.ficha[keyPath: kp] = $0.isEmpty ? nil : $0 })
    }
    private func numField(_ label: String, _ kp: WritableKeyPath<FichaCliente, Double?>) -> some View {
        HStack {
            Text(label); Spacer()
            TextField("0", text: Binding(
                get: { vm.ficha[keyPath: kp].map { String($0) } ?? "" },
                set: { vm.ficha[keyPath: kp] = Double($0.replacingOccurrences(of: ",", with: ".")) }))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
        }
    }
}
