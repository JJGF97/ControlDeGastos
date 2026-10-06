import SwiftUI
import Foundation

// MARK: - Colores y piezas comunes
extension Alerta {
    var color: Color {
        switch self {
        case .ok, .normal: return .green
        case .aviso: return .yellow
        case .alerta: return .orange
        case .vencida: return .red
        }
    }
}

extension NivelUso {
    var color: Color {
        switch self {
        case .baja: return .green
        case .moderada: return .yellow
        case .alta: return .orange
        case .muyAlta: return .red
        }
    }
}

func fechaLarga(_ d: Date) -> String { d.formatted(date: .abbreviated, time: .omitted) }

struct FilaDato: View {
    let t: String
    let v: String
    var color: Color = .primary
    var negrita = false
    var body: some View {
        HStack {
            Text(t).foregroundStyle(.secondary)
            Spacer()
            Text(v).fontWeight(negrita ? .bold : .regular).foregroundStyle(color)
        }
    }
}

struct Caja<Contenido: View>: View {
    let titulo: String
    let contenido: Contenido
    init(_ titulo: String, @ViewBuilder _ contenido: () -> Contenido) {
        self.titulo = titulo
        self.contenido = contenido()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo).font(.headline)
            contenido
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Lista de tarjetas
struct TarjetaView: View {
    @EnvironmentObject var store: Store
    @State private var seleccion: Int? = nil
    @State private var edicion: CreditCard? = nil

    var body: some View {
        if let id = seleccion, store.datos.tarjetas.contains(where: { $0.id == id }) {
            TarjetaDetalle(cardId: id, volver: { seleccion = nil })
        } else {
            lista
        }
    }

    private var lista: some View {
        let tarjetas = store.datos.tarjetas
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Mis tarjetas de crédito").font(.title3.bold())
                    Spacer()
                    Button("Agregar tarjeta") { edicion = store.tarjetaNueva() }
                        .buttonStyle(.borderedProminent)
                        .disabled(tarjetas.count >= Store.maxTarjetas)
                }
                Text("Puedes llevar hasta \(Store.maxTarjetas) tarjetas. Nunca se guarda el número completo, ni el CVV, ni el NIP.")
                    .font(.caption).foregroundStyle(.secondary)
                if tarjetas.isEmpty {
                    Caja("Aún no tienes tarjetas") {
                        Text("Agrega una tarjeta para controlar tu límite, tus fechas de pago, tus compras y tus meses sin intereses.")
                        Button("Agregar mi primera tarjeta") { edicion = store.tarjetaNueva() }
                    }
                }
                ForEach(tarjetas) { c in
                    Button { seleccion = c.id } label: { ResumenTarjeta(card: c) }
                        .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .sheet(item: $edicion) { c in CardForm(card: c) }
    }
}

struct ResumenTarjeta: View {
    let card: CreditCard

    var body: some View {
        let c = card
        let uso = c.uso()
        let nivel = c.nivel(uso)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(c.nombre).font(.headline)
                    Text(c.banco.isEmpty ? " " : c.banco + (c.ultimos4.isEmpty ? "" : " · ••\(c.ultimos4)"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            HStack {
                Tarjetita(titulo: "Límite", valor: dinero(c.limite))
                Tarjetita(titulo: "Disponible", valor: dinero(c.disponible()))
                Tarjetita(titulo: "Utilizado", valor: dinero(c.utilizado()))
            }
            ProgressView(value: min(uso, 100), total: 100).tint(nivel.color)
            Text("Utilización \(String(format: "%.1f", uso))% · \(nivel.rawValue)")
                .font(.caption).foregroundStyle(nivel.color)
            Divider()
            if let e = c.ultimoEstado() {
                let a = c.alerta(e)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Próximo pago: \(diaMes(e.limitePago))").font(.subheadline)
                        Text("Para no generar intereses").font(.caption).foregroundStyle(.secondary)
                        Text(dinero(e.falta)).font(.title3.bold())
                    }
                    Spacer()
                    Text(a.texto).font(.subheadline.bold()).foregroundStyle(a.tipo.color)
                        .multilineTextAlignment(.trailing).frame(maxWidth: 220, alignment: .trailing)
                }
            } else {
                Text("Aún sin estado de cuenta. Tu siguiente corte es el \(diaMes(c.cierre(c.claveAbierta))).")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Qué se va a borrar
enum Borrar: Identifiable {
    case mov(Int), pago(Int), tarjeta
    var id: String {
        switch self {
        case .mov(let i): return "m\(i)"
        case .pago(let i): return "p\(i)"
        case .tarjeta: return "t"
        }
    }
}

struct PeriodoSel: Identifiable { let id: Int }

// MARK: - Detalle de una tarjeta
struct TarjetaDetalle: View {
    @EnvironmentObject var store: Store
    let cardId: Int
    let volver: () -> Void

    @State private var cardEdit: CreditCard? = nil
    @State private var movEdit: TarjetaMov? = nil
    @State private var pagoEdit: TarjetaPago? = nil
    @State private var periodo: PeriodoSel? = nil
    @State private var borrar: Borrar? = nil

    private var tarjeta: CreditCard? { store.datos.tarjetas.first { $0.id == cardId } }

    var body: some View {
        if let c = tarjeta {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    cabecera(c)
                    pagarBox(c)
                    usoBox(c)
                    resumenBox(c)
                    movsBox(c)
                    msiBox(c)
                    pagosBox(c)
                    historialBox(c)
                    statsBox(c)
                    infoBox(c)
                }
                .padding()
            }
            .sheet(item: $cardEdit) { x in CardForm(card: x) }
            .sheet(item: $movEdit) { m in MovTarjetaForm(cardId: c.id, mov: m) }
            .sheet(item: $pagoEdit) { p in PagoTarjetaForm(cardId: c.id, pago: p) }
            .sheet(item: $periodo) { p in PeriodoDetalle(cardId: c.id, clave: p.id) }
            .confirmationDialog("¿Eliminar? No se puede deshacer.",
                                isPresented: Binding(get: { borrar != nil }, set: { if !$0 { borrar = nil } }),
                                presenting: borrar) { b in
                Button("Eliminar", role: .destructive) {
                    switch b {
                    case .mov(let i): store.borrarMov(c.id, i)
                    case .pago(let i): store.borrarPago(c.id, i)
                    case .tarjeta: store.borrarTarjeta(c.id); volver()
                    }
                }
            }
        } else {
            Text("Tarjeta no encontrada")
        }
    }

    // Cabecera
    @ViewBuilder private func cabecera(_ c: CreditCard) -> some View {
        HStack {
            Button { volver() } label: { Label("Mis tarjetas", systemImage: "chevron.left") }
            Spacer()
            Button("Editar tarjeta") { cardEdit = c }
            Button("Eliminar tarjeta", role: .destructive) { borrar = .tarjeta }
        }
        VStack(alignment: .leading, spacing: 2) {
            Text(c.nombre).font(.title2.bold())
            Text(c.banco.isEmpty ? " " : c.banco + (c.ultimos4.isEmpty ? "" : " · ••\(c.ultimos4)"))
                .foregroundStyle(.secondary)
        }
    }

    // 1. ¿Cuánto tengo que pagar?
    @ViewBuilder private func pagarBox(_ c: CreditCard) -> some View {
        Caja("¿Cuánto tengo que pagar?") {
            if let e = c.ultimoEstado() {
                let a = c.alerta(e)
                Text("Pago para no generar intereses").font(.caption).foregroundStyle(.secondary)
                Text(dinero(e.saldo)).font(.system(size: 34, weight: .bold))
                Text(a.texto).font(.subheadline.bold()).foregroundStyle(a.tipo.color)
                Divider()
                FilaDato(t: "Pagado", v: dinero(e.pagado))
                FilaDato(t: "Falta", v: dinero(e.falta), color: e.falta > 0 ? a.tipo.color : .green, negrita: true)
                FilaDato(t: "Fecha límite de pago", v: fechaLarga(e.limitePago))
                FilaDato(t: "Saldo al corte (\(diaMes(e.corte)))", v: dinero(e.saldo))
                FilaDato(t: "Pago mínimo (estimado)", v: dinero(e.minimo))
                Text("El pago mínimo es una estimación. Confirma el monto real en tu estado de cuenta.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Aún no hay un estado de cuenta cerrado. Tu primer corte es el \(fechaLarga(c.cierre(c.claveAbierta))).")
            }
            Button("Registrar pago") { pagoEdit = store.pagoNuevo() }.buttonStyle(.borderedProminent)
        }
    }

    // 2. Utilización y objetivo personal
    @ViewBuilder private func usoBox(_ c: CreditCard) -> some View {
        let uso = c.uso()
        let nivel = c.nivel(uso)
        Caja("Mi crédito") {
            FilaDato(t: "Debo actualmente", v: dinero(c.utilizado()), negrita: true)
            FilaDato(t: "Crédito disponible", v: dinero(c.disponible()))
            FilaDato(t: "Límite de crédito", v: dinero(c.limite))
            ProgressView(value: min(uso, 100), total: 100).tint(nivel.color)
            Text("\(dinero(c.utilizado())) de \(dinero(c.limite)) · \(String(format: "%.1f", uso))% · \(nivel.rawValue)")
                .font(.caption).foregroundStyle(nivel.color)
            if c.objetivoPct > 0 {
                Divider()
                Text("¿Cuánto puedo gastar?").font(.subheadline.bold())
                FilaDato(t: "Mi objetivo personal", v: "\(Int(c.objetivoPct))% del límite")
                FilaDato(t: "Mi límite personal", v: dinero(c.limitePersonal))
                FilaDato(t: "Disponible dentro de mi objetivo", v: dinero(c.disponibleObjetivo()),
                         color: c.disponibleObjetivo() > 0 ? .green : .red, negrita: true)
                Text("Es una meta que tú defines, no una recomendación financiera.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // 3. Resumen del periodo abierto
    @ViewBuilder private func resumenBox(_ c: CreditCard) -> some View {
        let k = c.claveAbierta
        let r = c.resumen(k)
        Caja("Periodo actual · corte el \(fechaLarga(c.cierre(k)))") {
            FilaDato(t: "Saldo del corte anterior", v: dinero(r.saldoAnterior))
            FilaDato(t: "Compras", v: dinero(r.compras))
            FilaDato(t: "Devoluciones", v: dinero(-r.devoluciones))
            FilaDato(t: "Comisiones", v: dinero(r.comisiones))
            FilaDato(t: "Intereses", v: dinero(r.intereses))
            if r.otros != 0 { FilaDato(t: "Ajustes y otros", v: dinero(r.otros)) }
            FilaDato(t: "Mensualidades a meses sin intereses", v: dinero(r.msi))
            FilaDato(t: "Pagos realizados", v: dinero(-r.pagos))
            Divider()
            FilaDato(t: "Saldo estimado al corte", v: dinero(c.saldoAlCorte(k)), negrita: true)
        }
    }

    // 4. Movimientos
    @ViewBuilder private func movsBox(_ c: CreditCard) -> some View {
        let recientes = Array(c.movs.sorted { $0.fecha > $1.fecha }.prefix(10))
        Caja("Compras y movimientos recientes") {
            Button("Nueva compra o movimiento") { movEdit = store.movNuevo() }.buttonStyle(.borderedProminent)
            if recientes.isEmpty { Text("Todavía no registras movimientos.").foregroundStyle(.secondary) }
            ForEach(recientes) { m in
                let cat = m.categoria.isEmpty ? "" : " · " + m.categoria
                let msi = c.esMSI(m) ? " · " + String(m.msiMeses) + " MSI" : ""
                HStack {
                    VStack(alignment: .leading) {
                        Text(m.descripcion.isEmpty ? m.tipo.rawValue : m.descripcion).bold()
                        Text(diaMes(m.fecha) + " · " + m.tipo.rawValue + cat + msi)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(dinero(c.firmado(m))).bold()
                    Button("Editar") { movEdit = m }
                    Button("Borrar") { borrar = .mov(m.id) }
                }
                Divider()
            }
        }
    }

    // 5. Meses sin intereses
    @ViewBuilder private func msiBox(_ c: CreditCard) -> some View {
        let lista = c.infoMSI()
        let futuros = c.compromisosMSI(12)
        Caja("Meses sin intereses") {
            if lista.isEmpty {
                Text("No tienes compras a meses sin intereses. Al registrar una compra, activa la opción «Compra a meses sin intereses».")
                    .foregroundStyle(.secondary)
            }
            ForEach(lista) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(i.mov.descripcion.isEmpty ? "Compra a MSI" : i.mov.descripcion).bold()
                    FilaDato(t: "Compra", v: "\(dinero(i.total)) a \(i.meses) meses")
                    FilaDato(t: "Mensualidad", v: dinero(i.mensualidad))
                    FilaDato(t: "Ya cobradas", v: "\(i.cobradas) / \(i.meses)")
                    FilaDato(t: "Restantes", v: "\(i.restantes)")
                    FilaDato(t: "Saldo pendiente", v: dinero(i.saldoPendiente), negrita: true)
                    FilaDato(t: "Termina", v: i.restantes == 0 ? "Terminada" : etiquetaMes(i.ultimoCorte))
                }
                Divider()
            }
            if !futuros.isEmpty {
                Text("Compromisos de los próximos estados de cuenta").font(.subheadline.bold())
                ForEach(futuros) { f in
                    FilaDato(t: etiquetaMes(f.clave), v: dinero(f.monto))
                }
            }
        }
    }

    // 6. Pagos
    @ViewBuilder private func pagosBox(_ c: CreditCard) -> some View {
        let lista = Array(c.pagos.sorted { $0.fecha > $1.fecha }.prefix(10))
        Caja("Pagos realizados") {
            if lista.isEmpty { Text("Todavía no registras pagos.").foregroundStyle(.secondary) }
            ForEach(lista) { p in
                HStack {
                    VStack(alignment: .leading) {
                        Text(dinero(p.monto)).bold()
                        Text("\(fechaLarga(p.fecha))\(p.notas.isEmpty ? "" : " · " + p.notas)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Editar") { pagoEdit = p }
                    Button("Borrar") { borrar = .pago(p.id) }
                }
                Divider()
            }
        }
    }

    // 7. Historial
    @ViewBuilder private func historialBox(_ c: CreditCard) -> some View {
        let filas = c.historial()
        Caja("Historial de periodos") {
            if filas.isEmpty { Text("Aún no hay periodos cerrados.").foregroundStyle(.secondary) }
            ForEach(filas) { f in
                Button { periodo = PeriodoSel(id: f.clave) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(etiquetaMes(f.clave).uppercased()).font(.subheadline.bold())
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        FilaDato(t: "Corte / fecha límite", v: "\(diaMes(f.corte)) / \(diaMes(f.limitePago))")
                        FilaDato(t: "Saldo al corte", v: dinero(f.saldo))
                        FilaDato(t: "Pago mínimo (estimado)", v: dinero(f.minimo))
                        FilaDato(t: "Pago para no generar intereses", v: dinero(f.saldo))
                        FilaDato(t: "Pagado", v: dinero(f.pagado))
                        FilaDato(t: "Intereses / comisiones", v: "\(dinero(f.intereses)) / \(dinero(f.comisiones))")
                        Text(f.estado).font(.caption.bold())
                    }
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    // 8. Estadísticas
    @ViewBuilder private func statsBox(_ c: CreditCard) -> some View {
        let s = c.estadisticas()
        Caja("Estadísticas") {
            FilaDato(t: "Compras del periodo actual", v: dinero(s.gastoPeriodo))
            FilaDato(t: "Gasto promedio mensual", v: dinero(s.promedio))
            FilaDato(t: "Mayor compra", v: dinero(s.mayor))
            FilaDato(t: "Total pagado", v: dinero(s.pagado))
            FilaDato(t: "Total de intereses", v: dinero(s.intereses))
            FilaDato(t: "Total de comisiones", v: dinero(s.comisiones))
            FilaDato(t: "Utilización promedio (últimos cortes)", v: "\(String(format: "%.1f", s.usoPromedio))%")
            FilaDato(t: "Total comprometido en MSI", v: dinero(s.msiComprometido))
        }
    }

    // 9. Información financiera
    @ViewBuilder private func infoBox(_ c: CreditCard) -> some View {
        Caja("Información de la tarjeta") {
            FilaDato(t: "Día de corte", v: "\(c.diaCorte)")
            FilaDato(t: "Día límite de pago", v: "\(c.diaPago)")
            if c.tasaAnual > 0 { FilaDato(t: "Tasa de interés anual", v: "\(String(format: "%.1f", c.tasaAnual))%") }
            if c.cat > 0 { FilaDato(t: "CAT", v: "\(String(format: "%.1f", c.cat))%") }
            if c.anualidad > 0 { FilaDato(t: "Anualidad", v: dinero(c.anualidad)) }
            if c.comisionTardia > 0 { FilaDato(t: "Comisión por pago tardío", v: dinero(c.comisionTardia)) }
            if !c.otrasComisiones.isEmpty { FilaDato(t: "Otras comisiones", v: c.otrasComisiones) }
            if c.cashbackPct > 0 { FilaDato(t: "Cashback", v: "\(String(format: "%.1f", c.cashbackPct))%") }
            if c.puntos > 0 { FilaDato(t: "Puntos acumulados", v: "\(Int(c.puntos))") }
        }
    }
}

// MARK: - Formulario de tarjeta
struct CardForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var card: CreditCard

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Información básica") {
                    TextField("Nombre de la tarjeta (ej. Tarjeta Santander)", text: $card.nombre)
                    TextField("Banco o emisor (opcional)", text: $card.banco)
                    TextField("Últimos 4 dígitos (opcional)", text: $card.ultimos4)
                    TextField("Límite de crédito", value: $card.limite, format: .number)
                    Stepper("Día de corte: \(card.diaCorte)", value: $card.diaCorte, in: 1...31)
                    Stepper("Día límite de pago: \(card.diaPago)", value: $card.diaPago, in: 1...31)
                }
                Section("Para empezar") {
                    TextField("Lo que debes hoy en esta tarjeta (puede ser 0)", value: $card.saldoInicial, format: .number)
                    DatePicker("Llevar el control desde", selection: $card.fechaInicio, displayedComponents: .date)
                }
                Section("Información financiera (opcional)") {
                    TextField("Tasa de interés anual (%)", value: $card.tasaAnual, format: .number)
                    TextField("CAT (%)", value: $card.cat, format: .number)
                    TextField("Anualidad", value: $card.anualidad, format: .number)
                    TextField("Comisión por pago tardío", value: $card.comisionTardia, format: .number)
                    TextField("Otras comisiones (texto libre)", text: $card.otrasComisiones)
                    TextField("Cashback (%)", value: $card.cashbackPct, format: .number)
                    TextField("Puntos acumulados", value: $card.puntos, format: .number)
                }
                Section("Preferencias") {
                    TextField("Mi objetivo de utilización (% del límite, 0 = ninguno)", value: $card.objetivoPct, format: .number)
                    TextField("Pago mínimo estimado (% del saldo)", value: $card.pagoMinimoPct, format: .number)
                }
                Text("No guardes aquí el número completo, el CVV, el NIP ni contraseñas.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    if !card.nombre.trimmingCharacters(in: .whitespaces).isEmpty && card.limite > 0 {
                        store.guardarTarjeta(card)
                        dismiss()
                    } else {
                        store.mensaje = "Escribe el nombre y el límite de crédito de la tarjeta."
                    }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 540, height: 660)
    }
}

// MARK: - Formulario de compra o movimiento
struct MovTarjetaForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let cardId: Int
    @State var mov: TarjetaMov

    private var tarjeta: CreditCard? { store.datos.tarjetas.first { $0.id == cardId } }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                DatePicker("Fecha", selection: $mov.fecha, displayedComponents: .date)
                TextField("Descripción", text: $mov.descripcion)
                Picker("Tipo", selection: $mov.tipo) {
                    ForEach(TipoMov.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField(mov.tipo == .ajuste ? "Monto (usa negativo para restar)" : "Monto", value: $mov.monto, format: .number)
                Picker("Categoría", selection: $mov.categoria) {
                    Text("Sin categoría").tag("")
                    ForEach(store.datos.categorias, id: \.self) { Text($0).tag($0) }
                }
                if mov.tipo == .compra {
                    Toggle("Compra a meses sin intereses", isOn: Binding(
                        get: { mov.msiMeses >= 2 },
                        set: { mov.msiMeses = $0 ? max(mov.msiMeses, 6) : 0 }))
                    if mov.msiMeses >= 2 {
                        Stepper("Meses: \(mov.msiMeses)", value: $mov.msiMeses, in: 2...60)
                        if let c = tarjeta {
                            Text("Mensualidad: \(dinero(c.mensualidad(mov))) · empieza en el corte del \(diaMes(c.cierre(c.clave(mov.fecha))))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                TextField("Notas (opcional)", text: $mov.notas)
                if let c = tarjeta {
                    Text("Entra al estado de cuenta con corte el \(fechaLarga(c.cierre(c.clave(mov.fecha)))).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    if mov.monto != 0 {
                        store.guardarMov(cardId, mov)
                        dismiss()
                    } else {
                        store.mensaje = "Escribe el monto."
                    }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 500, height: 520)
    }
}

// MARK: - Formulario de pago
struct PagoTarjetaForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let cardId: Int
    @State var pago: TarjetaPago

    private var tarjeta: CreditCard? { store.datos.tarjetas.first { $0.id == cardId } }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                DatePicker("Fecha del pago", selection: $pago.fecha, displayedComponents: .date)
                TextField("Monto", value: $pago.monto, format: .number)
                TextField("Nota (opcional)", text: $pago.notas)
                if let c = tarjeta {
                    Text(c.descripcionPago(pago.fecha)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    if pago.monto > 0 {
                        store.guardarPago(cardId, pago)
                        dismiss()
                    } else {
                        store.mensaje = "Escribe el monto del pago."
                    }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 460, height: 330)
    }
}

// MARK: - Detalle de un periodo del historial
struct PeriodoDetalle: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let cardId: Int
    let clave: Int

    var body: some View {
        VStack(spacing: 0) {
            if let c = store.datos.tarjetas.first(where: { $0.id == cardId }) {
                let r = c.resumen(clave)
                let movs = c.movs.filter { !c.esMSI($0) && c.clave($0.fecha) == clave }.sorted { $0.fecha < $1.fecha }
                let cuotas = c.infoMSI().filter { clave >= c.clave($0.mov.fecha) && clave < c.clave($0.mov.fecha) + $0.meses }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(etiquetaMes(clave)) · corte el \(fechaLarga(c.cierre(clave)))").font(.title3.bold())
                        Caja("Resumen") {
                            FilaDato(t: "Saldo del corte anterior", v: dinero(r.saldoAnterior))
                            FilaDato(t: "Compras", v: dinero(r.compras))
                            FilaDato(t: "Devoluciones", v: dinero(-r.devoluciones))
                            FilaDato(t: "Comisiones", v: dinero(r.comisiones))
                            FilaDato(t: "Intereses", v: dinero(r.intereses))
                            FilaDato(t: "Mensualidades MSI", v: dinero(r.msi))
                            FilaDato(t: "Pagos en el periodo", v: dinero(-r.pagos))
                            Divider()
                            FilaDato(t: "Saldo al corte", v: dinero(c.saldoAlCorte(clave)), negrita: true)
                        }
                        Caja("Movimientos del periodo") {
                            if movs.isEmpty && cuotas.isEmpty { Text("Sin movimientos.").foregroundStyle(.secondary) }
                            ForEach(movs) { m in
                                FilaDato(t: "\(diaMes(m.fecha)) · \(m.descripcion.isEmpty ? m.tipo.rawValue : m.descripcion)",
                                         v: dinero(c.firmado(m)))
                            }
                            ForEach(cuotas) { i in
                                let n = clave - c.clave(i.mov.fecha) + 1
                                FilaDato(t: "Mensualidad \(n)/\(i.meses) · \(i.mov.descripcion.isEmpty ? "MSI" : i.mov.descripcion)",
                                         v: dinero(c.sumaMensualidades(i.mov, n) - c.sumaMensualidades(i.mov, n - 1)))
                            }
                        }
                    }
                    .padding()
                }
            }
            HStack { Spacer(); Button("Cerrar") { dismiss() }.buttonStyle(.borderedProminent) }.padding()
        }
        .frame(width: 540, height: 600)
    }
}
