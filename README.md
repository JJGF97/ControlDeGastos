# Control de Gastos para Mac

App sencilla, gratuita y de código abierto para llevar el control de tus **gastos fijos, pagos, ingresos y tarjetas de crédito**, pensada para personas que no quieren pelearse con Excel.

> **English:** a simple, free and open-source macOS app (SwiftUI) to track recurring bills, payments, income and up to 3 credit cards. All your data stays on your Mac. MIT licensed.

## ¿Qué hace?

- **Gastos fijos que se repiten solos.** Los das de alta una vez (renta, servicios, suscripciones…) y cada mes solo marcas si ya pagaste.
- **Pagos del mes** con estados claros: Pagado, Pendiente, Por vencer y Vencido. Puedes marcar «Otro monto» u «Omitir».
- **Periodos a tu medida:** quincenal (15 y 30), quincenal (1 y 15), mensual o semanal.
- **Cambios de monto** con fecha: si tu renta sube, los meses anteriores no cambian.
- **Ingresos y gastos extraordinarios**, con dinero disponible por periodo.
- **Límites por categoría** con aviso de «Cerca del límite» o «Excedido».
- **Resumen anual** con gráfica y **exportación a CSV** para abrir en Excel.
- **Hasta 3 tarjetas de crédito**, cada una con su nombre:
  - límite, crédito disponible y porcentaje de utilización;
  - fecha de corte, fecha límite de pago, pago mínimo (estimado) y pago para no generar intereses;
  - compras, devoluciones, comisiones e intereses;
  - compras a **meses sin intereses** con mensualidades, restantes y saldo pendiente;
  - pagos, historial por periodo y estadísticas;
  - un objetivo personal de utilización («¿cuánto puedo gastar?»).

## Capturas

<!-- Agrega tus capturas en la carpeta docs/ y descomenta estas líneas:
![Resumen](docs/resumen.png)
![Tarjetas](docs/tarjetas.png)
-->

## Privacidad

- **Tus datos se quedan en tu Mac.** No hay cuentas, servidores ni rastreo, y la app no se conecta a internet.
- **Nunca pide ni guarda** el número completo de la tarjeta, el CVV, el NIP ni contraseñas. Solo los últimos 4 dígitos, si tú quieres.
- Los datos viven en un archivo `datos.json` dentro de la carpeta de datos de la app. Haz respaldos desde **Ajustes → Exportar respaldo**.

## Instalación

### Opción 1: descargar la app

1. Ve a [**Releases**](../../releases) y descarga el `.zip` de la última versión.
2. Descomprímelo y arrastra la app a la carpeta **Aplicaciones**.
3. **Primer arranque:** la app no está firmada con una cuenta de desarrollador de pago, así que macOS mostrará un aviso de «desarrollador no identificado». Para abrirla, autoriza la app en **Ajustes del Sistema → Privacidad y seguridad** (botón «Abrir de todas formas»). Los pasos exactos pueden cambiar según tu versión de macOS.

### Opción 2: compilarla tú mismo

Necesitas **macOS 13 o superior** y [Xcode](https://developer.apple.com/xcode/) (gratis).

1. Clona el repositorio o descarga el código.
2. Abre `ControlDeGastos.xcodeproj` con Xcode.
3. Presiona **Cmd + R** para ejecutarla.
4. En **Ajustes → Cargar ejemplo** puedes ver cómo funciona con datos de prueba.

## Estructura del código

| Archivo | Qué contiene |
|---|---|
| `ControlDeGastosApp.swift` | Punto de entrada de la app y carga del icono |
| `Models.swift` | Tipos de datos: gastos, ingresos, tarjetas, periodos |
| `Engine.swift` | Reglas de cálculo de pagos, periodos y saldo disponible |
| `EngineTarjetas.swift` | Reglas de las tarjetas: cortes, fechas límite, MSI, pagos, utilización, historial |
| `Store.swift` | Guardado automático en JSON, respaldo, ejemplo y CSV |
| `Views.swift` | Pantallas principales |
| `TarjetasViews.swift` | Pantallas del módulo de tarjetas |
| `app_icon.png` | Icono de la app |

Sin dependencias externas: solo SwiftUI, Charts y los frameworks de Apple.

## Hoja de ruta

- Versión para iPhone (el modelo y el motor ya son independientes de macOS).
- Recordatorios de pagos por vencer.
- Proyección de cuándo se liquida una deuda.

## Contribuir

¿Encontraste un error o tienes una idea? Lee [CONTRIBUTING.md](CONTRIBUTING.md) y abre un *Issue*. Cualquier ayuda es bienvenida.

## Apoya el proyecto

Es gratis y siempre lo será. Si te sirve y quieres invitarme un café, es totalmente opcional:

☕ **[ko-fi.com/flowmac](https://ko-fi.com/flowmac)**

## Licencia

[MIT](LICENSE). Puedes usarla, copiarla y modificarla libremente.
