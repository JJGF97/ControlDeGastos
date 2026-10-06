import Foundation

struct Item: Identifiable {
    let id: String            // "idGasto_claveMesCalendario"
    let gasto: Gasto
    let fecha: Date
    let monto: Double
    let periodo: Int
    let marca: Marca?
}

enum Situacion: String {
    case pagado = "Pagado", omitido = "Omitido", vencido = "Vencido"
    case porVencer = "Por vencer", pendiente = "Pendiente"
}

struct PeriodoTotales {
    var prog = 0.0, pag = 0.0, pen = 0.0, ext = 0.0, ing = 0.0
    var op = 0.0, disp = 0.0
}

func etiquetaMes(_ k: Int) -> String { "\(MESES[((k % 12) + 12) % 12]) \(k / 12)" }

extension Datos {
    /// Clave del "mes de control" al que pertenece una fecha
    func clave(_ d: Date) -> Int {
        let c = calendario.dateComponents([.year, .month, .day], from: d)
        let corte = (c.day ?? 1) < tipo.inicioCiclo ? 1 : 0
        return (c.year ?? 2000) * 12 + ((c.month ?? 1) - 1) - corte
    }

    /// Fecha del pago de un gasto en el mes calendario `c` (año*12 + mes0), si toca
    func generar(_ g: Gasto, mes c: Int) -> Date? {
        guard g.activo, !g.nombre.isEmpty else { return nil }
        let ini = calendario.startOfDay(for: g.inicio)
        let ic = calendario.dateComponents([.year, .month], from: ini)
        let df = c - ((ic.year ?? 2000) * 12 + ((ic.month ?? 1) - 1))
        let n = g.frecuencia.meses
        if df < 0 { return nil }
        if n == 0 { if df != 0 { return nil } } else if df % n != 0 { return nil }
        let y = c / 12, m = c % 12 + 1
        guard let primero = calendario.date(from: DateComponents(year: y, month: m, day: 1)),
              let rango = calendario.range(of: .day, in: .month, for: primero),
              let f = calendario.date(from: DateComponents(year: y, month: m, day: min(g.dia, rango.count)))
        else { return nil }
        return f < ini ? nil : f
    }

    /// Monto total del recibo vigente en una fecha (considera los cambios de monto)
    func montoTotal(_ g: Gasto, en f: Date) -> Double {
        var a = g.monto
        var mejor: Date? = nil
        for c in cambios where c.gastoId == g.id && calendario.startOfDay(for: c.desde) <= f {
            if mejor == nil || c.desde >= mejor! { a = c.monto; mejor = c.desde }
        }
        return a
    }

    /// Pagos programados de un mes de control
    func items(_ k: Int) -> [Item] {
        var r: [Item] = []
        for g in gastos {
            for c in [k, k + 1] {
                if let d = generar(g, mes: c), clave(d) == k {
                    let id = "\(g.id)_\(c)"
                    let pct = g.porcentaje > 0 ? g.porcentaje : 100
                    let m = (montoTotal(g, en: d) * pct / 100 * 100).rounded() / 100
                    r.append(Item(id: id, gasto: g, fecha: d, monto: m,
                                  periodo: tipo.periodo(dia: min(g.dia, 31)), marca: marcas[id]))
                }
            }
        }
        return r
    }

    func situacion(_ i: Item) -> Situacion {
        if let m = i.marca { return m.estado == .pagado ? .pagado : .omitido }
        let hoy = calendario.startOfDay(for: Date())
        if i.fecha < hoy { return .vencido }
        let dias = calendario.dateComponents([.day], from: hoy, to: i.fecha).day ?? 0
        return dias <= 3 ? .porVencer : .pendiente
    }

    func pagado(_ i: Item) -> Double { i.marca?.real ?? i.monto }

    func orden(_ i: Item) -> Int {
        if let m = i.marca { return m.estado == .omitido ? 2 : 1 }
        return 0
    }

    /// Totales por periodo de un mes de control
    func ciclo(_ k: Int) -> [PeriodoTotales] {
        var P = Array(repeating: PeriodoTotales(), count: tipo.etiquetas.count)
        for i in items(k) {
            let s = situacion(i)
            if s == .omitido { continue }
            P[i.periodo].prog += i.monto
            if s == .pagado { P[i.periodo].pag += pagado(i) } else { P[i.periodo].pen += i.monto }
        }
        for x in extras where clave(x.fecha) == k {
            P[tipo.periodo(dia: calendario.component(.day, from: x.fecha))].ext += x.monto
        }
        for x in ingresos where clave(x.fecha) == k {
            P[tipo.periodo(dia: calendario.component(.day, from: x.fecha))].ing += x.monto
        }
        return P
    }

    /// Igual que `ciclo`, pero con saldo que llega y dinero disponible acumulados
    func acumulado(_ k: Int) -> [PeriodoTotales] {
        var lo = k
        for x in ingresos { lo = min(lo, clave(x.fecha)) }
        for x in extras { lo = min(lo, clave(x.fecha)) }
        for g in gastos { lo = min(lo, clave(g.inicio)) }
        lo = max(lo, k - 120)
        var c = saldo
        var salida: [PeriodoTotales] = []
        for j in lo...k {
            var P = ciclo(j)
            for n in P.indices {
                P[n].op = c
                P[n].disp = c + P[n].ing - P[n].pag - P[n].ext - P[n].pen
                c = P[n].disp
            }
            salida = P
        }
        return salida
    }

    /// Gasto por categoría (pagado + pendiente + extraordinarios) de un mes
    func gastoPorCategoria(_ k: Int) -> [String: Double] {
        var c: [String: Double] = [:]
        for i in items(k) where situacion(i) != .omitido {
            c[i.gasto.categoria, default: 0] += i.marca != nil ? pagado(i) : i.monto
        }
        for x in extras where clave(x.fecha) == k { c[x.categoria, default: 0] += x.monto }
        return c
    }
}
