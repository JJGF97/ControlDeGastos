import Foundation

let MESES = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
             "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
let calendario = Calendar.current

func fecha(_ y: Int, _ m: Int, _ d: Int) -> Date {
    calendario.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
}

enum Frecuencia: String, Codable, CaseIterable, Identifiable {
    case mensual = "Mensual"
    case bimestral = "Cada 2 meses"
    case trimestral = "Trimestral"
    case semestral = "Semestral"
    case anual = "Anual"
    case unico = "Pago único"

    var id: String { rawValue }
    /// Cada cuántos meses se repite (0 = una sola vez)
    var meses: Int {
        switch self {
        case .mensual: return 1
        case .bimestral: return 2
        case .trimestral: return 3
        case .semestral: return 6
        case .anual: return 12
        case .unico: return 0
        }
    }
}

enum TipoPeriodo: Int, Codable, CaseIterable, Identifiable {
    case quincenal1530 = 0, quincenal115, mensual, semanal

    var id: Int { rawValue }

    var nombre: String {
        switch self {
        case .quincenal1530: return "Quincenal (días 15 y 30)"
        case .quincenal115: return "Quincenal (días 1 y 15)"
        case .mensual: return "Mensual"
        case .semanal: return "Semanal (semanas del mes)"
        }
    }

    /// Día del mes en que empieza cada "mes" de control
    var inicioCiclo: Int { self == .quincenal1530 ? 15 : 1 }

    var etiquetas: [String] {
        switch self {
        case .quincenal1530, .quincenal115: return ["1.ª quincena", "2.ª quincena"]
        case .mensual: return ["Mes completo"]
        case .semanal: return ["Semana 1", "Semana 2", "Semana 3", "Semana 4", "Semana 5"]
        }
    }

    /// Índice del periodo (0...) según el día del mes
    func periodo(dia d: Int) -> Int {
        switch self {
        case .quincenal1530: return (15...29).contains(d) ? 0 : 1
        case .quincenal115: return d <= 14 ? 0 : 1
        case .mensual: return 0
        case .semanal: return d <= 7 ? 0 : (d <= 14 ? 1 : (d <= 21 ? 2 : (d <= 28 ? 3 : 4)))
        }
    }
}

enum EstadoPago: String, Codable { case pagado, omitido }

struct Marca: Codable {
    var estado: EstadoPago
    var real: Double? = nil
}

struct Gasto: Codable, Identifiable, Hashable {
    var id: Int
    var nombre: String
    var categoria: String
    var monto: Double          // monto total del recibo
    var porcentaje: Double     // % que pago (0 = 100 %)
    var frecuencia: Frecuencia
    var dia: Int
    var inicio: Date           // fecha del primer pago
    var activo: Bool
}

struct CambioMonto: Codable, Identifiable {
    var id: Int
    var gastoId: Int
    var desde: Date
    var monto: Double
}

struct Ingreso: Codable, Identifiable {
    var id: Int
    var fecha: Date
    var concepto: String
    var monto: Double
}

struct Extra: Codable, Identifiable {
    var id: Int
    var fecha: Date
    var nombre: String
    var categoria: String
    var monto: Double
}

enum TipoMov: String, Codable, CaseIterable, Identifiable {
    case compra = "Compra"
    case devolucion = "Devolución"
    case ajuste = "Ajuste"
    case comision = "Comisión"
    case interes = "Interés"
    case otro = "Otro"
    var id: String { rawValue }
}

struct TarjetaMov: Codable, Identifiable {
    var id: Int
    var fecha: Date
    var descripcion = ""
    var categoria = ""
    var monto = 0.0
    var tipo: TipoMov = .compra
    var msiMeses = 0           // 0 = compra normal; 2 o más = meses sin intereses
    var notas = ""
}

struct TarjetaPago: Codable, Identifiable {
    var id: Int
    var fecha: Date
    var monto = 0.0
    var notas = ""
}

struct CreditCard: Codable, Identifiable {
    var id: Int
    var nombre = ""
    var banco = ""
    var ultimos4 = ""
    var limite = 0.0
    var diaCorte = 5
    var diaPago = 25
    var tasaAnual = 0.0
    var cat = 0.0
    var anualidad = 0.0
    var comisionTardia = 0.0
    var otrasComisiones = ""
    var cashbackPct = 0.0
    var puntos = 0.0
    var objetivoPct = 0.0      // objetivo personal de utilización (0 = sin objetivo)
    var pagoMinimoPct = 5.0    // estimación del pago mínimo como % del saldo
    var saldoInicial = 0.0
    var fechaInicio = Date()
    var movs: [TarjetaMov] = []
    var pagos: [TarjetaPago] = []
}

struct Datos: Codable {
    var titulo = "Control de Gastos"
    var saldo = 0.0
    var tipo: TipoPeriodo = .quincenal1530
    var categorias: [String] = ["Vivienda", "Servicios", "Alimentos", "Transporte", "Salud", "Educación",
                                "Suscripciones", "Finanzas y deudas", "Hogar", "Entretenimiento",
                                "Ropa y calzado", "Otros"]
    var limites: [String: Double] = [:]
    var gastos: [Gasto] = []
    var cambios: [CambioMonto] = []
    var marcas: [String: Marca] = [:]
    var ingresos: [Ingreso] = []
    var extras: [Extra] = []
    var tarjetas: [CreditCard] = []
    var siguienteId = 1

    enum CodingKeys: String, CodingKey {
        case titulo, saldo, tipo, categorias, limites, gastos, cambios, marcas
        case ingresos, extras, tarjetas, siguienteId
    }
}

extension Datos {
    /// Lectura tolerante: si falta algún campo (archivos de versiones anteriores), usa el valor por defecto
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        titulo = try c.decodeIfPresent(String.self, forKey: .titulo) ?? titulo
        saldo = try c.decodeIfPresent(Double.self, forKey: .saldo) ?? saldo
        tipo = try c.decodeIfPresent(TipoPeriodo.self, forKey: .tipo) ?? tipo
        categorias = try c.decodeIfPresent([String].self, forKey: .categorias) ?? categorias
        limites = try c.decodeIfPresent([String: Double].self, forKey: .limites) ?? limites
        gastos = try c.decodeIfPresent([Gasto].self, forKey: .gastos) ?? gastos
        cambios = try c.decodeIfPresent([CambioMonto].self, forKey: .cambios) ?? cambios
        marcas = try c.decodeIfPresent([String: Marca].self, forKey: .marcas) ?? marcas
        ingresos = try c.decodeIfPresent([Ingreso].self, forKey: .ingresos) ?? ingresos
        extras = try c.decodeIfPresent([Extra].self, forKey: .extras) ?? extras
        tarjetas = try c.decodeIfPresent([CreditCard].self, forKey: .tarjetas) ?? tarjetas
        siguienteId = try c.decodeIfPresent(Int.self, forKey: .siguienteId) ?? siguienteId
    }
}
