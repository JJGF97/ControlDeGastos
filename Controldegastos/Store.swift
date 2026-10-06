import SwiftUI
import Combine
import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

final class Store: ObservableObject {
    @Published var datos: Datos { didSet { guardar() } }
    @Published var clave: Int
    @Published var anio: Int
    @Published var mensaje: String? = nil

    private let archivo: URL

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ControlDeGastos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("datos.json")
        var d = Datos()
        if let data = try? Data(contentsOf: url), let leido = try? Store.decoder.decode(Datos.self, from: data) {
            d = leido
        }
        self.archivo = url
        self.datos = d
        self.clave = d.clave(Date())
        self.anio = calendario.component(.year, from: Date())
    }

    func guardar() {
        if let data = try? Store.encoder.encode(datos) {
            try? data.write(to: archivo, options: .atomic)
        }
    }

    func nuevoId() -> Int {
        datos.siguienteId += 1
        return datos.siguienteId - 1
    }

    // MARK: Pagos
    func marcar(_ id: String, _ e: EstadoPago, _ real: Double? = nil) {
        datos.marcas[id] = Marca(estado: e, real: real)
    }
    func quitarMarca(_ id: String) { datos.marcas.removeValue(forKey: id) }

    // MARK: Gastos fijos
    func gastoNuevo() -> Gasto {
        Gasto(id: 0, nombre: "", categoria: datos.categorias.first ?? "Otros", monto: 0, porcentaje: 0,
              frecuencia: .mensual, dia: 1, inicio: Date(), activo: true)
    }
    func guardarGasto(_ g: Gasto) {
        var x = g
        if x.id == 0 {
            x.id = nuevoId()
            datos.gastos.append(x)
        } else if let i = datos.gastos.firstIndex(where: { $0.id == x.id }) {
            datos.gastos[i] = x
        }
    }
    func borrarGasto(_ id: Int) {
        datos.gastos.removeAll { $0.id == id }
        datos.cambios.removeAll { $0.gastoId == id }
        datos.marcas = datos.marcas.filter { !$0.key.hasPrefix("\(id)_") }
    }

    // MARK: Cambios, ingresos, extras, tarjeta
    func agregarCambio(gastoId: Int, desde: Date, monto: Double) {
        datos.cambios.append(CambioMonto(id: nuevoId(), gastoId: gastoId, desde: desde, monto: monto))
    }
    func borrarCambio(_ id: Int) { datos.cambios.removeAll { $0.id == id } }

    func agregarIngreso(fecha: Date, concepto: String, monto: Double) {
        datos.ingresos.append(Ingreso(id: nuevoId(), fecha: fecha,
                                      concepto: concepto.isEmpty ? "Ingreso" : concepto, monto: monto))
        clave = datos.clave(fecha)
    }
    func borrarIngreso(_ id: Int) { datos.ingresos.removeAll { $0.id == id } }

    func agregarExtra(fecha: Date, nombre: String, categoria: String, monto: Double) {
        datos.extras.append(Extra(id: nuevoId(), fecha: fecha, nombre: nombre.isEmpty ? "Gasto" : nombre,
                                  categoria: categoria, monto: monto))
        clave = datos.clave(fecha)
    }
    func borrarExtra(_ id: Int) { datos.extras.removeAll { $0.id == id } }

    // MARK: Tarjetas de crédito (hasta 3)
    static let maxTarjetas = 3

    func tarjetaNueva() -> CreditCard {
        CreditCard(id: 0, nombre: "", diaCorte: 5, diaPago: 25)
    }
    func movNuevo() -> TarjetaMov {
        TarjetaMov(id: 0, fecha: Date(), categoria: "", tipo: .compra)
    }
    func pagoNuevo() -> TarjetaPago {
        TarjetaPago(id: 0, fecha: Date())
    }
    func guardarTarjeta(_ c: CreditCard) {
        var x = c
        x.ultimos4 = String(x.ultimos4.filter { $0.isNumber }.suffix(4))
        if x.id == 0 {
            if datos.tarjetas.count >= Store.maxTarjetas { mensaje = "Puedes tener hasta 3 tarjetas."; return }
            x.id = nuevoId()
            datos.tarjetas.append(x)
        } else if let i = datos.tarjetas.firstIndex(where: { $0.id == x.id }) {
            x.movs = datos.tarjetas[i].movs
            x.pagos = datos.tarjetas[i].pagos
            datos.tarjetas[i] = x
        }
    }
    func borrarTarjeta(_ id: Int) { datos.tarjetas.removeAll { $0.id == id } }

    func guardarMov(_ cid: Int, _ m: TarjetaMov) {
        guard let i = datos.tarjetas.firstIndex(where: { $0.id == cid }) else { return }
        var x = m
        if x.tipo != .compra { x.msiMeses = 0 }
        if x.id == 0 {
            x.id = nuevoId()
            datos.tarjetas[i].movs.append(x)
        } else if let j = datos.tarjetas[i].movs.firstIndex(where: { $0.id == x.id }) {
            datos.tarjetas[i].movs[j] = x
        }
    }
    func borrarMov(_ cid: Int, _ id: Int) {
        guard let i = datos.tarjetas.firstIndex(where: { $0.id == cid }) else { return }
        datos.tarjetas[i].movs.removeAll { $0.id == id }
    }
    func guardarPago(_ cid: Int, _ p: TarjetaPago) {
        guard let i = datos.tarjetas.firstIndex(where: { $0.id == cid }) else { return }
        var x = p
        if x.id == 0 {
            x.id = nuevoId()
            datos.tarjetas[i].pagos.append(x)
        } else if let j = datos.tarjetas[i].pagos.firstIndex(where: { $0.id == x.id }) {
            datos.tarjetas[i].pagos[j] = x
        }
    }
    func borrarPago(_ cid: Int, _ id: Int) {
        guard let i = datos.tarjetas.firstIndex(where: { $0.id == cid }) else { return }
        datos.tarjetas[i].pagos.removeAll { $0.id == id }
    }

    func ejemploTarjeta() -> CreditCard {
        let hoy = Date()
        func hace(_ d: Int) -> Date { calendario.date(byAdding: .day, value: -d, to: hoy) ?? hoy }
        func mov(_ id: Int, _ d: Int, _ desc: String, _ cat: String, _ m: Double, _ t: TipoMov = .compra, _ msi: Int = 0) -> TarjetaMov {
            TarjetaMov(id: id, fecha: hace(d), descripcion: desc, categoria: cat, monto: m, tipo: t, msiMeses: msi)
        }
        var c = CreditCard(id: 90, nombre: "Tarjeta de ejemplo", banco: "Banco ejemplo", ultimos4: "1234",
                           limite: 30000, diaCorte: 5, diaPago: 25)
        c.tasaAnual = 60; c.cat = 85; c.anualidad = 800; c.comisionTardia = 350
        c.cashbackPct = 1; c.objetivoPct = 40; c.fechaInicio = hace(100)
        c.movs = [mov(91, 80, "Despensa", "Alimentos", 1800),
                  mov(92, 60, "Laptop (12 meses sin intereses)", "Hogar", 12000, .compra, 12),
                  mov(93, 40, "Gasolina", "Transporte", 900),
                  mov(94, 30, "Devolución de ropa", "Ropa y calzado", 500, .devolucion),
                  mov(95, 12, "Restaurante", "Entretenimiento", 750)]
        c.pagos = [TarjetaPago(id: 96, fecha: hace(45), monto: 3000, notas: "Pago del estado de cuenta"),
                   TarjetaPago(id: 97, fecha: hace(8), monto: 2000, notas: "Pago parcial")]
        return c
    }

    // MARK: Categorías (texto "Nombre | límite", una por línea)
    func categoriasTexto() -> String {
        datos.categorias.map { c in
            if let l = datos.limites[c], l > 0 { return "\(c) | \(Int(l))" }
            return c
        }.joined(separator: "\n")
    }
    func guardarCategorias(_ texto: String) {
        var cats: [String] = []
        var lim: [String: Double] = [:]
        for linea in texto.split(separator: "\n") {
            let partes = linea.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let nombre = partes.first, !nombre.isEmpty else { continue }
            cats.append(nombre)
            if partes.count > 1, let v = Double(partes[1].replacingOccurrences(of: ",", with: ".")), v > 0 {
                lim[nombre] = v
            }
        }
        if !cats.isEmpty {
            datos.categorias = cats
            datos.limites = lim
        }
    }

    func cambiarTipo(_ t: TipoPeriodo) {
        datos.tipo = t
        clave = datos.clave(Date())
    }

    // MARK: Ejemplo y borrado
    func cargarEjemplo() {
        func g(_ id: Int, _ n: String, _ c: String, _ m: Double, _ f: Frecuencia, _ dia: Int, _ ini: Date, _ pct: Double = 0) -> Gasto {
            Gasto(id: id, nombre: n, categoria: c, monto: m, porcentaje: pct, frecuencia: f, dia: dia, inicio: ini, activo: true)
        }
        var d = Datos()
        d.gastos = [
            g(1, "Renta", "Vivienda", 8000, .mensual, 1, fecha(2026, 10, 1)),
            g(2, "Electricidad", "Servicios", 1200, .bimestral, 10, fecha(2026, 10, 10)),
            g(3, "Internet", "Servicios", 600, .mensual, 15, fecha(2026, 9, 15)),
            g(4, "Streaming", "Suscripciones", 219, .mensual, 3, fecha(2026, 10, 3)),
            g(5, "Gas (compartido 50%)", "Servicios", 850, .mensual, 28, fecha(2026, 9, 28), 50),
            g(6, "Tarjeta de crédito", "Finanzas y deudas", 1500, .mensual, 15, fecha(2026, 9, 15)),
            g(7, "Gimnasio", "Salud", 450, .mensual, 30, fecha(2026, 9, 30)),
            g(8, "Seguro de auto", "Transporte", 9600, .anual, 20, fecha(2026, 11, 20)),
        ]
        d.marcas = [
            "3_24320": Marca(estado: .pagado), "6_24320": Marca(estado: .pagado, real: 1650),
            "5_24320": Marca(estado: .pagado), "7_24320": Marca(estado: .pagado),
            "1_24321": Marca(estado: .pagado), "4_24321": Marca(estado: .pagado),
        ]
        d.ingresos = [Ingreso(id: 10, fecha: fecha(2026, 9, 15), concepto: "Sueldo", monto: 15000),
                      Ingreso(id: 11, fecha: fecha(2026, 9, 30), concepto: "Sueldo", monto: 15000)]
        d.extras = [Extra(id: 12, fecha: fecha(2026, 9, 20), nombre: "Reparación de llave", categoria: "Hogar", monto: 450)]
        d.cambios = [CambioMonto(id: 13, gastoId: 3, desde: fecha(2027, 1, 1), monto: 650)]
        d.limites = ["Alimentos": 6000, "Suscripciones": 800, "Finanzas y deudas": 1500]
        d.tarjetas = [ejemploTarjeta()]
        d.siguienteId = 200
        datos = d
        clave = 2026 * 12 + 8
        anio = 2026
    }

    func borrarTodo() {
        datos = Datos()
        clave = datos.clave(Date())
    }

    // MARK: Respaldo y CSV (solo Mac)
    #if os(macOS)
    func exportarRespaldo() {
        let p = NSSavePanel()
        p.nameFieldStringValue = "respaldo-control-de-gastos.json"
        p.allowedContentTypes = [.json]
        if p.runModal() == .OK, let url = p.url, let data = try? Store.encoder.encode(datos) {
            do { try data.write(to: url); mensaje = "Respaldo guardado." } catch { mensaje = "No se pudo guardar el respaldo." }
        }
    }

    func importarRespaldo() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.json]
        p.allowsMultipleSelection = false
        if p.runModal() == .OK, let url = p.url {
            if let data = try? Data(contentsOf: url), let d = try? Store.decoder.decode(Datos.self, from: data) {
                datos = d
                clave = d.clave(Date())
                mensaje = "Respaldo restaurado."
            } else {
                mensaje = "El archivo no es un respaldo válido."
            }
        }
    }

    func exportarCSV(anio: Int) {
        var filas: [[String]] = [["Fecha", "Tipo", "Concepto", "Categoría", "Monto", "Estado"]]
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        for m in 0..<12 {
            let k = anio * 12 + m
            for i in datos.items(k) {
                filas.append([f.string(from: i.fecha), "Pago programado", i.gasto.nombre, i.gasto.categoria,
                              String(format: "%.2f", i.marca != nil ? datos.pagado(i) : i.monto),
                              datos.situacion(i).rawValue])
            }
            for x in datos.extras where datos.clave(x.fecha) == k {
                filas.append([f.string(from: x.fecha), "Extraordinario", x.nombre, x.categoria,
                              String(format: "%.2f", x.monto), "Pagado"])
            }
            for x in datos.ingresos where datos.clave(x.fecha) == k {
                filas.append([f.string(from: x.fecha), "Ingreso", x.concepto, "",
                              String(format: "%.2f", x.monto), "Recibido"])
            }
        }
        let texto = "\u{FEFF}" + filas.map { fila in
            fila.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",")
        }.joined(separator: "\n")
        let p = NSSavePanel()
        p.nameFieldStringValue = "gastos-\(anio).csv"
        p.allowedContentTypes = [.commaSeparatedText]
        if p.runModal() == .OK, let url = p.url {
            do { try texto.write(to: url, atomically: true, encoding: .utf8); mensaje = "CSV guardado." }
            catch { mensaje = "No se pudo guardar el CSV." }
        }
    }
    #endif
}
