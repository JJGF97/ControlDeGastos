import Foundation

enum NivelUso: String {
    case baja = "Utilización baja"
    case moderada = "Utilización moderada"
    case alta = "Utilización alta"
    case muyAlta = "Utilización muy alta"
}

enum Alerta { case ok, normal, aviso, alerta, vencida }

struct EstadoCuenta {
    let clave: Int
    let corte: Date
    let limitePago: Date
    let saldo: Double      // saldo al corte = pago para no generar intereses
    let minimo: Double     // pago mínimo estimado
    let pagado: Double     // pagos hechos después del corte
    var falta: Double { max(0, saldo - pagado) }
}

struct ResumenPeriodo {
    var saldoAnterior = 0.0
    var compras = 0.0
    var devoluciones = 0.0
    var comisiones = 0.0
    var intereses = 0.0
    var otros = 0.0
    var msi = 0.0
    var pagos = 0.0
    var total: Double { compras - devoluciones + comisiones + intereses + otros + msi }
}

struct InfoMSI: Identifiable {
    let id: Int
    let mov: TarjetaMov
    let mensualidad: Double
    let total: Double
    let meses: Int
    let cobradas: Int
    let saldoPendiente: Double
    let ultimoCorte: Int
    var restantes: Int { meses - cobradas }
}

struct FilaHistorial: Identifiable {
    let id: Int
    let clave: Int
    let corte: Date
    let limitePago: Date
    let saldo: Double
    let minimo: Double
    let pagado: Double
    let intereses: Double
    let comisiones: Double
    let estado: String
}

struct CompromisoMSI: Identifiable {
    let clave: Int
    let monto: Double
    var id: Int { clave }
}

struct EstadisticasTarjeta {
    var gastoPeriodo = 0.0
    var promedio = 0.0
    var mayor = 0.0
    var pagado = 0.0
    var intereses = 0.0
    var comisiones = 0.0
    var usoPromedio = 0.0
    var msiComprometido = 0.0
}

extension CreditCard {
    // MARK: Fechas del ciclo
    private func fd(_ y: Int, _ m: Int, _ d: Int) -> Date {
        let primero = calendario.date(from: DateComponents(year: y, month: m, day: 1)) ?? Date()
        let dias = calendario.range(of: .day, in: .month, for: primero)?.count ?? 28
        let f = calendario.date(from: DateComponents(year: y, month: m, day: min(d, dias))) ?? primero
        return calendario.startOfDay(for: f)
    }

    /// Fecha de corte del periodo `k` (k = año*12 + mes0)
    func cierre(_ k: Int) -> Date { fd(k / 12, k % 12 + 1, diaCorte) }

    /// Fecha límite de pago del estado de cuenta del periodo `k`
    func vencimiento(_ k: Int) -> Date {
        let kv = k + (diaPago > diaCorte ? 0 : 1)
        return fd(kv / 12, kv % 12 + 1, diaPago)
    }

    /// Periodo (estado de cuenta) al que pertenece una fecha
    func clave(_ d: Date) -> Int {
        let x = calendario.startOfDay(for: d)
        let c = calendario.dateComponents([.year, .month], from: x)
        let k = (c.year ?? 2000) * 12 + ((c.month ?? 1) - 1)
        return x <= cierre(k) ? k : k + 1
    }

    var claveAbierta: Int { clave(Date()) }

    var claveMinima: Int {
        var k = clave(fechaInicio)
        for m in movs { k = min(k, clave(m.fecha)) }
        for p in pagos { k = min(k, clave(p.fecha)) }
        return k
    }

    // MARK: Movimientos
    func firmado(_ m: TarjetaMov) -> Double {
        switch m.tipo {
        case .devolucion: return -abs(m.monto)
        case .ajuste: return m.monto
        default: return abs(m.monto)
        }
    }

    func esMSI(_ m: TarjetaMov) -> Bool { m.tipo == .compra && m.msiMeses >= 2 }

    func mensualidad(_ m: TarjetaMov) -> Double {
        (abs(m.monto) / Double(max(m.msiMeses, 1)) * 100).rounded() / 100
    }

    /// Suma de las primeras `n` mensualidades (la última ajusta el redondeo)
    func sumaMensualidades(_ m: TarjetaMov, _ n: Int) -> Double {
        if n <= 0 { return 0 }
        if n >= m.msiMeses { return abs(m.monto) }
        return mensualidad(m) * Double(n)
    }

    /// Mensualidades MSI que se cobran en el estado de cuenta del periodo `k`
    func cargoMSI(_ k: Int) -> Double {
        var s = 0.0
        for m in movs where esMSI(m) {
            let p0 = clave(m.fecha)
            s += sumaMensualidades(m, k - p0 + 1) - sumaMensualidades(m, k - p0)
        }
        return (s * 100).rounded() / 100
    }

    // MARK: Pagos
    func pagosEntre(_ a: Date, _ b: Date) -> Double {
        var s = 0.0
        for p in pagos {
            let f = calendario.startOfDay(for: p.fecha)
            if f > a && f <= b { s += p.monto }
        }
        return s
    }

    func pagosHasta(_ b: Date) -> Double {
        var s = 0.0
        for p in pagos where calendario.startOfDay(for: p.fecha) <= b { s += p.monto }
        return s
    }

    // MARK: Saldos
    /// Lo que debías en el corte del periodo `k` (incluye lo no pagado de periodos anteriores)
    func saldoAlCorte(_ k: Int) -> Double {
        var s = saldoInicial
        for m in movs where !esMSI(m) && clave(m.fecha) <= k { s += firmado(m) }
        for m in movs where esMSI(m) { s += sumaMensualidades(m, k - clave(m.fecha) + 1) }
        s -= pagosHasta(cierre(k))
        return (s * 100).rounded() / 100
    }

    func estadoCuenta(_ k: Int, hasta: Date) -> EstadoCuenta {
        let s = max(0, saldoAlCorte(k))
        let minimo = s > 0 ? ((s * pagoMinimoPct / 100) * 100).rounded() / 100 : 0
        return EstadoCuenta(clave: k, corte: cierre(k), limitePago: vencimiento(k), saldo: s, minimo: minimo,
                            pagado: pagosEntre(cierre(k), hasta))
    }

    /// Último estado de cuenta ya cerrado (el que toca pagar)
    func ultimoEstado() -> EstadoCuenta? {
        let k = claveAbierta - 1
        if k < claveMinima { return nil }
        return estadoCuenta(k, hasta: calendario.startOfDay(for: Date()))
    }

    func resumen(_ k: Int) -> ResumenPeriodo {
        var r = ResumenPeriodo()
        r.saldoAnterior = saldoAlCorte(k - 1)
        for m in movs where !esMSI(m) && clave(m.fecha) == k {
            switch m.tipo {
            case .compra: r.compras += abs(m.monto)
            case .devolucion: r.devoluciones += abs(m.monto)
            case .comision: r.comisiones += abs(m.monto)
            case .interes: r.intereses += abs(m.monto)
            case .ajuste, .otro: r.otros += firmado(m)
            }
        }
        r.msi = cargoMSI(k)
        r.pagos = pagosEntre(cierre(k - 1), cierre(k))
        return r
    }

    // MARK: Utilización
    func utilizadoRaw(al f: Date) -> Double {
        let h = calendario.startOfDay(for: f)
        var s = saldoInicial
        for m in movs where calendario.startOfDay(for: m.fecha) <= h {
            s += esMSI(m) ? abs(m.monto) : firmado(m)
        }
        s -= pagosHasta(h)
        return (s * 100).rounded() / 100
    }

    func utilizado(al f: Date = Date()) -> Double { max(0, utilizadoRaw(al: f)) }
    func disponible() -> Double { limite - utilizado() }
    func uso(al f: Date = Date()) -> Double { limite > 0 ? utilizado(al: f) / limite * 100 : 0 }

    func nivel(_ p: Double) -> NivelUso {
        if p <= 30 { return .baja }
        if p <= 50 { return .moderada }
        if p <= 80 { return .alta }
        return .muyAlta
    }

    var limitePersonal: Double { objetivoPct > 0 ? limite * objetivoPct / 100 : 0 }
    func disponibleObjetivo() -> Double { max(0, limitePersonal - utilizado()) }

    // MARK: Alertas
    func alerta(_ e: EstadoCuenta) -> (tipo: Alerta, texto: String) {
        if e.saldo <= 0 { return (.ok, "No tienes saldo por pagar en este corte.") }
        if e.falta <= 0.005 { return (.ok, "Este estado de cuenta ya está pagado.") }
        let h = calendario.startOfDay(for: Date())
        let dias = calendario.dateComponents([.day], from: h, to: e.limitePago).day ?? 0
        if dias < 0 { return (.vencida, "Tu fecha límite ya pasó.") }
        if dias == 0 { return (.alerta, "Tu pago vence hoy.") }
        if dias <= 3 { return (.alerta, dias == 1 ? "Falta 1 día para pagar." : "Faltan \(dias) días para pagar.") }
        if dias <= 7 { return (.aviso, "Faltan \(dias) días para tu fecha límite.") }
        return (.normal, "Faltan \(dias) días para tu fecha límite.")
    }

    func descripcionPago(_ f: Date) -> String {
        let k = clave(f) - 1
        if k < claveMinima { return "Este pago reduce tu saldo." }
        let h = calendario.startOfDay(for: f)
        if h <= vencimiento(k) {
            return "Cuenta para el estado de cuenta con corte el \(diaMes(cierre(k))) (fecha límite \(diaMes(vencimiento(k))))."
        }
        return "Este pago es posterior a la fecha límite del corte del \(diaMes(cierre(k)))."
    }

    // MARK: Meses sin intereses
    func infoMSI() -> [InfoMSI] {
        let kA = claveAbierta
        return movs.filter { esMSI($0) }.sorted { $0.fecha < $1.fecha }.map { (m: TarjetaMov) -> InfoMSI in
            let p0 = clave(m.fecha)
            let cobradas = min(max(kA - p0, 0), m.msiMeses)
            let total = abs(m.monto)
            return InfoMSI(id: m.id, mov: m, mensualidad: mensualidad(m), total: total, meses: m.msiMeses,
                           cobradas: cobradas, saldoPendiente: max(0, total - sumaMensualidades(m, cobradas)),
                           ultimoCorte: p0 + m.msiMeses - 1)
        }
    }

    /// Mensualidades MSI que se cobrarán en los próximos estados de cuenta
    func compromisosMSI(_ cuantos: Int = 12) -> [CompromisoMSI] {
        let kA = claveAbierta
        var r: [CompromisoMSI] = []
        for k in kA..<(kA + cuantos) {
            let c = cargoMSI(k)
            if c > 0 { r.append(CompromisoMSI(clave: k, monto: c)) }
        }
        return r
    }

    // MARK: Historial y estadísticas
    func historial() -> [FilaHistorial] {
        let kA = claveAbierta
        let kMin = claveMinima
        if kA - 1 < kMin { return [] }
        let hoy = calendario.startOfDay(for: Date())
        var filas: [FilaHistorial] = []
        for k in stride(from: kA - 1, through: max(kMin, kA - 12), by: -1) {
            let e = estadoCuenta(k, hasta: cierre(k + 1))
            let aTiempo = pagosEntre(cierre(k), vencimiento(k))
            let texto: String
            if e.saldo <= 0 {
                texto = "Sin saldo por pagar"
            } else if aTiempo + 0.005 >= e.saldo {
                texto = "Pagado completamente"
            } else if e.pagado + 0.005 >= e.saldo {
                texto = "Pagado después de la fecha límite"
            } else if hoy <= vencimiento(k) {
                texto = e.pagado > 0 ? "Pago parcial (aún estás a tiempo)" : "Pendiente de pago"
            } else {
                texto = e.pagado > 0 ? "Pago incompleto" : "Sin pagar"
            }
            let r = resumen(k)
            filas.append(FilaHistorial(id: k, clave: k, corte: e.corte, limitePago: e.limitePago, saldo: e.saldo,
                                       minimo: e.minimo, pagado: e.pagado, intereses: r.intereses,
                                       comisiones: r.comisiones, estado: texto))
        }
        return filas
    }

    func estadisticas() -> EstadisticasTarjeta {
        var s = EstadisticasTarjeta()
        let kA = claveAbierta
        let compras = movs.filter { $0.tipo == .compra }
        s.gastoPeriodo = compras.filter { clave($0.fecha) == kA }.reduce(0) { $0 + abs($1.monto) }
        if let primera = compras.map({ clave($0.fecha) }).min() {
            let total = compras.reduce(0) { $0 + abs($1.monto) }
            s.promedio = total / Double(max(1, kA - primera + 1))
        }
        s.mayor = compras.map { abs($0.monto) }.max() ?? 0
        s.pagado = pagos.reduce(0) { $0 + $1.monto }
        s.intereses = movs.filter { $0.tipo == .interes }.reduce(0) { $0 + abs($1.monto) }
        s.comisiones = movs.filter { $0.tipo == .comision }.reduce(0) { $0 + abs($1.monto) }
        let kMin = claveMinima
        var usos: [Double] = []
        if kA - 1 >= kMin {
            for k in stride(from: kA - 1, through: max(kMin, kA - 6), by: -1) { usos.append(uso(al: cierre(k))) }
        }
        s.usoPromedio = usos.isEmpty ? 0 : usos.reduce(0, +) / Double(usos.count)
        s.msiComprometido = infoMSI().reduce(0) { $0 + $1.saldoPendiente }
        return s
    }
}
