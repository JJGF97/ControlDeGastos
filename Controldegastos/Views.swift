import SwiftUI
import Charts
import Foundation

// Cambia aquí tu enlace de donaciones
let kofiURL = "https://ko-fi.com/flowmac"

enum Fmt {
    static let money: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.positivePrefix = "$"
        f.negativePrefix = "-$"
        return f
    }()
}
func dinero(_ x: Double) -> String { Fmt.money.string(from: NSNumber(value: x)) ?? "$0.00" }
func diaMes(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated)) }

extension Situacion {
    var color: Color {
        switch self {
        case .pagado: return .green
        case .vencido: return .red
        case .porVencer: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Navegación principal
enum Seccion: String, CaseIterable, Identifiable {
    case resumen = "Resumen", pagos = "Pagos", gastos = "Gastos fijos", ingresos = "Ingresos y extras"
    case anual = "Anual", tarjeta = "Tarjetas", ajustes = "Ajustes"
    var id: Seccion { self }
    var icono: String {
        switch self {
        case .resumen: return "chart.pie"
        case .pagos: return "checkmark.circle"
        case .gastos: return "repeat"
        case .ingresos: return "plus.circle"
        case .anual: return "calendar"
        case .tarjeta: return "creditcard"
        case .ajustes: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var seccion: Seccion? = .resumen

    var body: some View {
        NavigationSplitView {
            List(Seccion.allCases, selection: $seccion) { s in
                Label(s.rawValue, systemImage: s.icono)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch seccion ?? .resumen {
                case .resumen: ResumenView()
                case .pagos: PagosView()
                case .gastos: GastosView()
                case .ingresos: IngresosView()
                case .anual: AnualView()
                case .tarjeta: TarjetaView()
                case .ajustes: AjustesView()
                }
            }
            .navigationTitle(store.datos.titulo)
        }
        .frame(minWidth: 860, minHeight: 600)
        .alert("Aviso", isPresented: Binding(get: { store.mensaje != nil },
                                              set: { if !$0 { store.mensaje = nil } })) {
            Button("OK") { store.mensaje = nil }
        } message: { Text(store.mensaje ?? "") }
    }
}

// MARK: - Piezas comunes
struct Tarjetita: View {
    let titulo: String
    let valor: String
    var color: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption).foregroundStyle(.secondary)
            Text(valor).font(.title3.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SelectorMes: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let k = store.clave
        let y = k / 12, m = ((k % 12) + 12) % 12
        let s = store.datos.tipo.inicioCiclo
        let a = fecha(y, m + 1, s)
        let b = calendario.date(byAdding: .day, value: -1, to: fecha(y, m + 2, s)) ?? a
        HStack {
            Button { store.clave -= 1 } label: { Image(systemName: "chevron.left") }
            VStack {
                Text("\(MESES[m]) \(y)").font(.title3.bold())
                Text("\(diaMes(a)) – \(diaMes(b))").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            Button { store.clave += 1 } label: { Image(systemName: "chevron.right") }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Resumen
struct ResumenView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let d = store.datos, k = store.clave
        let P = d.acumulado(k)
        let ing = P.reduce(0) { $0 + $1.ing }
        let pag = P.reduce(0) { $0 + $1.pag }
        let ext = P.reduce(0) { $0 + $1.ext }
        let pen = P.reduce(0) { $0 + $1.pen }
        let balance = ing - pag - ext - pen
        let vencidos = d.items(k).filter { d.situacion($0) == .vencido }.count
        let cat = d.gastoPorCategoria(k).merging(d.limites.mapValues { _ in 0.0 }) { a, _ in a }
        let cats = cat.sorted { $0.value > $1.value }
        let mx = max(1, cats.map { max($0.value, d.limites[$0.key] ?? 0) }.max() ?? 1)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SelectorMes()
                if d.gastos.isEmpty && d.ingresos.isEmpty && d.extras.isEmpty {
                    GroupBox {
                        HStack {
                            Text("Empieza agregando tus gastos fijos, o mira cómo funciona con datos de ejemplo.")
                            Spacer()
                            Button("Cargar ejemplo") { store.cargarEjemplo() }
                        }
                    }
                }
                if vencidos > 0 {
                    Text("Tienes \(vencidos) pago(s) vencido(s) en este mes.")
                        .bold().foregroundStyle(.red)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                    Tarjetita(titulo: "Ingresos", valor: dinero(ing))
                    Tarjetita(titulo: "Gastado (pagado + extras)", valor: dinero(pag + ext))
                    Tarjetita(titulo: "Pendiente por pagar", valor: dinero(pen))
                    Tarjetita(titulo: "Balance del mes", valor: dinero(balance), color: balance < 0 ? .red : .green)
                }

                Text("Por periodo").font(.headline)
                Grid(alignment: .trailing, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        Text("Programado"); Text("Pagado"); Text("Disponible")
                    }.font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(P.indices, id: \.self) { i in
                        GridRow {
                            Text(d.tipo.etiquetas[i]).gridColumnAlignment(.leading)
                            Text(dinero(P[i].prog))
                            Text(dinero(P[i].pag + P[i].ext))
                            Text(dinero(P[i].disp)).bold().foregroundStyle(P[i].disp < 0 ? Color.red : Color.primary)
                        }
                    }
                }
                .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                Text("Categorías").font(.headline)
                if cats.isEmpty { Text("Sin gastos en este mes.").foregroundStyle(.secondary) }
                ForEach(cats, id: \.key) { par in
                    let lim = d.limites[par.key] ?? 0
                    let q = lim > 0 ? par.value / lim : 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(par.key)
                            Spacer()
                            Text(dinero(par.value)).bold()
                        }
                        if lim > 0 {
                            Text("\(Int((q * 100).rounded()))% de \(dinero(lim)) · \(q > 1 ? "Excedido" : (q >= 0.8 ? "Cerca del límite" : "En orden"))")
                                .font(.caption).foregroundStyle(q > 1 ? Color.red : (q >= 0.8 ? Color.orange : Color.secondary))
                        }
                        ProgressView(value: min(par.value, mx), total: mx).tint(q > 1 ? Color.red : Color.accentColor)
                    }
                    .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
    }
}

// MARK: - Pagos del mes
struct OtroMontoSheet: View {
    let item: Item
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var texto = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Cuánto pagaste realmente por \(item.gasto.nombre)?").font(.headline)
            TextField("Monto", text: $texto).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    if let v = Double(texto.replacingOccurrences(of: ",", with: ".")), v >= 0 {
                        onSave(v); dismiss()
                    }
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 380)
    }
}

struct PagosView: View {
    @EnvironmentObject var store: Store
    @State private var otro: Item? = nil

    var body: some View {
        let d = store.datos
        let lista = d.items(store.clave).sorted { (d.orden($0), $0.fecha) < (d.orden($1), $1.fecha) }
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SelectorMes()
                Text("Pagos del mes").font(.headline)
                if lista.isEmpty {
                    Text("No hay pagos programados en este mes. Agrégalos en Gastos fijos.").foregroundStyle(.secondary)
                }
                ForEach(lista) { i in
                    let s = d.situacion(i)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(i.gasto.nombre).bold()
                                Text("\(diaMes(i.fecha)) · \(d.tipo.etiquetas[i.periodo])").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(dinero(i.marca != nil ? d.pagado(i) : i.monto)).bold()
                                Text(s.rawValue).font(.caption.bold()).foregroundStyle(s.color)
                            }
                        }
                        HStack {
                            if i.marca != nil {
                                Button("Deshacer") { store.quitarMarca(i.id) }
                            } else {
                                Button("Pagado") { store.marcar(i.id, .pagado) }.buttonStyle(.borderedProminent)
                                Button("Otro monto") { otro = i }
                                Button("Omitir") { store.marcar(i.id, .omitido) }
                            }
                        }
                    }
                    .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
        .sheet(item: $otro) { i in
            OtroMontoSheet(item: i) { v in store.marcar(i.id, .pagado, v) }
        }
    }
}

// MARK: - Gastos fijos
struct GastoForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var g: Gasto
    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Nombre", text: $g.nombre)
                Picker("Categoría", selection: $g.categoria) {
                    ForEach(store.datos.categorias, id: \.self) { Text($0).tag($0) }
                }
                TextField("Monto total del recibo", value: $g.monto, format: .number)
                TextField("% que pago (0 = 100%)", value: $g.porcentaje, format: .number)
                Picker("Frecuencia", selection: $g.frecuencia) {
                    ForEach(Frecuencia.allCases) { Text($0.rawValue).tag($0) }
                }
                Stepper("Día de pago: \(g.dia)", value: $g.dia, in: 1...31)
                DatePicker("Fecha del primer pago", selection: $g.inicio, displayedComponents: .date)
                Toggle("Activo", isOn: $g.activo)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    if !g.nombre.trimmingCharacters(in: .whitespaces).isEmpty {
                        store.guardarGasto(g); dismiss()
                    }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 460, height: 460)
    }
}

struct CambioForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var gastoId: Int = 0
    @State private var desde = Date()
    @State private var monto = 0.0
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Gasto", selection: $gastoId) {
                    ForEach(store.datos.gastos) { Text($0.nombre).tag($0.id) }
                }
                DatePicker("Vigente desde", selection: $desde, displayedComponents: .date)
                TextField("Nuevo monto total", value: $monto, format: .number)
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    if gastoId != 0 && monto >= 0 {
                        store.agregarCambio(gastoId: gastoId, desde: desde, monto: monto); dismiss()
                    }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 440, height: 260)
        .onAppear { gastoId = store.datos.gastos.first?.id ?? 0 }
    }
}

struct GastosView: View {
    @EnvironmentObject var store: Store
    @State private var edicion: Gasto? = nil
    @State private var porBorrar: Gasto? = nil
    @State private var nuevoCambio = false

    var body: some View {
        let d = store.datos
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Mis gastos fijos (se repiten solos cada mes)").font(.headline)
                    Spacer()
                    Button("Nuevo gasto fijo") { edicion = store.gastoNuevo() }.buttonStyle(.borderedProminent)
                }
                if d.gastos.isEmpty { Text("Aún no tienes gastos fijos.").foregroundStyle(.secondary) }
                ForEach(d.gastos) { g in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(g.nombre).bold()
                            Text("\(g.categoria) · \(g.frecuencia.rawValue) · día \(g.dia)\(g.activo ? "" : " · pausado")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(dinero(d.montoTotal(g, en: Date()) * (g.porcentaje > 0 ? g.porcentaje : 100) / 100)).bold()
                        Button("Editar") { edicion = g }
                        Button("Borrar") { porBorrar = g }
                    }
                    .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }

                HStack {
                    Text("Cambios de monto").font(.headline)
                    Spacer()
                    Button("Nuevo cambio") { nuevoCambio = true }.disabled(d.gastos.isEmpty)
                }.padding(.top, 14)
                Text("Si un gasto sube o baja, regístralo aquí: el monto nuevo aplica desde esa fecha y los meses anteriores no cambian.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(d.cambios) { c in
                    if let g = d.gastos.first(where: { $0.id == c.gastoId }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(g.nombre).bold()
                                Text("Desde \(c.desde.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(dinero(c.monto)).bold()
                            Button("Borrar") { store.borrarCambio(c.id) }
                        }
                        .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
        }
        .sheet(item: $edicion) { g in GastoForm(g: g) }
        .sheet(isPresented: $nuevoCambio) { CambioForm() }
        .confirmationDialog("¿Borrar este gasto fijo? Se pierde también el estado de sus pagos.",
                            isPresented: Binding(get: { porBorrar != nil }, set: { if !$0 { porBorrar = nil } }),
                            presenting: porBorrar) { g in
            Button("Borrar", role: .destructive) { store.borrarGasto(g.id) }
        }
    }
}

// MARK: - Ingresos y extras
struct IngresoForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var fecha = Date()
    @State private var concepto = ""
    @State private var monto = 0.0
    var body: some View {
        VStack(spacing: 0) {
            Form {
                DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                TextField("Concepto (sueldo, ventas…)", text: $concepto)
                TextField("Monto", value: $monto, format: .number)
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    if monto > 0 { store.agregarIngreso(fecha: fecha, concepto: concepto, monto: monto); dismiss() }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }.frame(width: 440, height: 280)
    }
}

struct ExtraForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var fecha = Date()
    @State private var nombre = ""
    @State private var categoria = ""
    @State private var monto = 0.0
    var body: some View {
        VStack(spacing: 0) {
            Form {
                DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                TextField("Gasto (reparación, regalo…)", text: $nombre)
                Picker("Categoría", selection: $categoria) {
                    ForEach(store.datos.categorias, id: \.self) { Text($0).tag($0) }
                }
                TextField("Monto", value: $monto, format: .number)
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    if monto > 0 {
                        store.agregarExtra(fecha: fecha, nombre: nombre, categoria: categoria, monto: monto); dismiss()
                    }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 440, height: 320)
        .onAppear { categoria = store.datos.categorias.first ?? "Otros" }
    }
}

struct IngresosView: View {
    @EnvironmentObject var store: Store
    @State private var nuevoIngreso = false
    @State private var nuevoExtra = false

    var body: some View {
        let d = store.datos, k = store.clave
        let ings = d.ingresos.filter { d.clave($0.fecha) == k }.sorted { $0.fecha < $1.fecha }
        let exts = d.extras.filter { d.clave($0.fecha) == k }.sorted { $0.fecha < $1.fecha }
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SelectorMes()
                HStack {
                    Text("Ingresos del mes").font(.headline)
                    Spacer()
                    Button("Nuevo ingreso") { nuevoIngreso = true }.buttonStyle(.borderedProminent)
                }
                if ings.isEmpty { Text("Sin ingresos en este mes.").foregroundStyle(.secondary) }
                ForEach(ings) { x in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(x.concepto).bold()
                            Text(diaMes(x.fecha)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(dinero(x.monto)).bold()
                        Button("Borrar") { store.borrarIngreso(x.id) }
                    }
                    .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }
                HStack {
                    Text("Gastos extraordinarios del mes").font(.headline)
                    Spacer()
                    Button("Nuevo gasto extra") { nuevoExtra = true }.buttonStyle(.borderedProminent)
                }.padding(.top, 14)
                Text("Solo para gastos que no se repiten. Los gastos fijos se agregan en la sección Gastos fijos.")
                    .font(.caption).foregroundStyle(.secondary)
                if exts.isEmpty { Text("Sin gastos extraordinarios en este mes.").foregroundStyle(.secondary) }
                ForEach(exts) { x in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(x.nombre).bold()
                            Text("\(diaMes(x.fecha)) · \(x.categoria)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(dinero(x.monto)).bold()
                        Button("Borrar") { store.borrarExtra(x.id) }
                    }
                    .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
        .sheet(isPresented: $nuevoIngreso) { IngresoForm() }
        .sheet(isPresented: $nuevoExtra) { ExtraForm() }
    }
}

// MARK: - Anual
struct FilaAnual: Identifiable {
    let id = UUID()
    let mes: String
    let tipo: String
    let valor: Double
}

struct AnualView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let d = store.datos, y = store.anio
        let meses: [(ing: Double, gas: Double, pen: Double)] = (0..<12).map { m in
            let P = d.ciclo(y * 12 + m)
            return (P.reduce(0) { $0 + $1.ing }, P.reduce(0) { $0 + $1.pag + $1.ext }, P.reduce(0) { $0 + $1.pen })
        }
        let tIng = meses.reduce(0) { $0 + $1.ing }
        let tGas = meses.reduce(0) { $0 + $1.gas }
        let tPen = meses.reduce(0) { $0 + $1.pen }
        let cat = (0..<12).reduce(into: [String: Double]()) { acc, m in
            for (c, v) in d.gastoPorCategoria(y * 12 + m) { acc[c, default: 0] += v }
        }
        let cats = cat.sorted { $0.value > $1.value }
        let mxCat = max(1, cats.first?.value ?? 1)
        let filas: [FilaAnual] = (0..<12).flatMap { m in
            [FilaAnual(mes: String(MESES[m].prefix(3)), tipo: "Ingresos", valor: meses[m].ing),
             FilaAnual(mes: String(MESES[m].prefix(3)), tipo: "Gasto", valor: meses[m].gas)]
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button { store.anio -= 1 } label: { Image(systemName: "chevron.left") }
                    Text("Año \(String(y))").font(.title3.bold()).frame(maxWidth: .infinity)
                    Button { store.anio += 1 } label: { Image(systemName: "chevron.right") }
                }
                .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                    Tarjetita(titulo: "Ingresos del año", valor: dinero(tIng))
                    Tarjetita(titulo: "Gastado del año", valor: dinero(tGas))
                    Tarjetita(titulo: "Pendiente", valor: dinero(tPen))
                    Tarjetita(titulo: "Balance", valor: dinero(tIng - tGas - tPen),
                              color: tIng - tGas - tPen < 0 ? .red : .green)
                }

                Text("Ingresos vs. gasto por mes").font(.headline)
                Chart(filas) { f in
                    BarMark(x: .value("Mes", f.mes), y: .value("Monto", f.valor))
                        .foregroundStyle(by: .value("Tipo", f.tipo))
                        .position(by: .value("Tipo", f.tipo))
                }
                .chartForegroundStyleScale(["Ingresos": Color.green, "Gasto": Color.red])
                .frame(height: 240)

                Text("Mes por mes").font(.headline)
                Grid(alignment: .trailing, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        Text("Ingresos"); Text("Gastado"); Text("Balance")
                    }.font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(0..<12, id: \.self) { m in
                        let b = meses[m].ing - meses[m].gas - meses[m].pen
                        GridRow {
                            Text(MESES[m]).gridColumnAlignment(.leading)
                            Text(dinero(meses[m].ing)); Text(dinero(meses[m].gas))
                            Text(dinero(b)).foregroundStyle(b < 0 ? Color.red : Color.primary)
                        }
                    }
                }
                .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                Text("Gasto por categoría").font(.headline)
                if cats.isEmpty { Text("Sin gastos este año.").foregroundStyle(.secondary) }
                ForEach(cats, id: \.key) { par in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text(par.key); Spacer(); Text(dinero(par.value)).bold() }
                        ProgressView(value: par.value, total: mxCat)
                    }
                    .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }

                #if os(macOS)
                Button("Exportar \(String(y)) a CSV (para Excel)") { store.exportarCSV(anio: y) }
                    .buttonStyle(.borderedProminent)
                #endif
            }
            .padding()
        }
    }
}

// MARK: - Ajustes
struct AjustesView: View {
    @EnvironmentObject var store: Store
    @State private var textoCats = ""
    @State private var confirmarBorrado = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("General") {
                    Form {
                        TextField("Título", text: $store.datos.titulo)
                        TextField("Saldo inicial disponible", value: $store.datos.saldo, format: .number)
                        Picker("Tipo de periodo", selection: Binding(get: { store.datos.tipo },
                                                                      set: { store.cambiarTipo($0) })) {
                            ForEach(TipoPeriodo.allCases) { Text($0.nombre).tag($0) }
                        }
                    }.formStyle(.columns)
                }
                GroupBox("Categorías y límite mensual (una por línea: Nombre | límite)") {
                    VStack(alignment: .leading) {
                        TextEditor(text: $textoCats)
                            .font(.body.monospaced()).frame(height: 190)
                        Button("Guardar categorías") { store.guardarCategorias(textoCats); textoCats = store.categoriasTexto() }
                    }
                }
                GroupBox("Tus datos") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Todo se guarda solo en esta Mac. Haz respaldos de vez en cuando.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            #if os(macOS)
                            Button("Exportar respaldo") { store.exportarRespaldo() }
                            Button("Importar respaldo") { store.importarRespaldo() }
                            #endif
                            Button("Cargar ejemplo") { store.cargarEjemplo() }
                            Button("Borrar todo", role: .destructive) { confirmarBorrado = true }
                        }
                    }
                }
                GroupBox("Acerca de") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Control de Gastos · código abierto (licencia MIT).")
                        Text("Si te sirve y quieres apoyar el proyecto, puedes invitarme un café. Es totalmente opcional.")
                            .font(.caption).foregroundStyle(.secondary)
                        if let url = URL(string: kofiURL) {
                            Link("☕ Apoyar en Ko-fi", destination: url)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear { textoCats = store.categoriasTexto() }
        .confirmationDialog("¿Borrar todos tus datos? No se puede deshacer.", isPresented: $confirmarBorrado) {
            Button("Borrar todo", role: .destructive) { store.borrarTodo(); textoCats = store.categoriasTexto() }
        }
    }
}
