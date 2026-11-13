# Penumbra

**Control fino del brillo, la temperatura de color (hasta el rojo puro) y la luz del teclado de tu Mac, desde las teclas de brillo que ya tienes.**

[English](README.md)

<!-- TODO: añadir docs/hud.png (captura o GIF de la barra) -->

Penumbra es una pequeña app de barra de menús para MacBooks con Apple Silicon que toma el control de las teclas de brillo y les da más usos:

- **Brillo en 50 pasos** del 2 %, en lugar de los 16 de macOS.
- **Temperatura de color** de 6000 K a 1000 K en pasos de 50 K (por debajo del límite de 2700 K de Night Shift) y después hasta **rojo puro**, para astronomía y para no perder la adaptación a la oscuridad.
- **Luz del teclado** en 10 pasos, todos con un cambio visible. Los teclados con Apple Silicon perdieron sus teclas dedicadas.
- **Fn Lock** como en un ThinkPad: `fn` + `Esc` alterna entre F1–F12 y teclas multimedia.
- Una barra en pantalla con aspecto nativo (Liquid Glass en macOS 26) que muestra el valor: `25/50`, `3450 K`, `● 40%`.

Sin ventanas, sin icono en el Dock y sin dependencias. Swift nativo, unos cientos de líneas.

## Atajos

| Teclas | Hace |
|---|---|
| ☀︎ | Brillo |
| ⇧ Shift + ☀︎ | Temperatura de color (Night Shift → rojo) |
| ⌃ Control + ☀︎ | Luz del teclado |
| Las dos ☀︎ a la vez | Cambia de modo: brillo → temperatura → teclado (vuelve a brillo tras 5 s sin uso) |
| `fn` + `Esc` | Fn Lock: F1–F12 ⇄ teclas multimedia |

- **Tap** = un paso. **Taps rápidos** = pasos mayores (1, 1, 2, 2, 3). **Mantener** = repetición constante.
- "☀︎" es lo que en tu Mac genera un evento de brillo: las teclas de brillo, o `fn` + F1/F2 si usas F1–F12 como teclas de función estándar. Penumbra respeta ese ajuste.

## Instalación

### Desde el código fuente (recomendado)

Requiere las Command Line Tools de Xcode (`xcode-select --install`).

```sh
git clone https://github.com/juanmacuevas/penumbra-mac.git
cd penumbra-mac
make install
```

Compila `Penumbra.app`, la instala en `/Applications` y la abre. La primera vez, macOS pide permiso de **Accesibilidad**, necesario para capturar las teclas de brillo: Ajustes del Sistema → Privacidad y seguridad → Accesibilidad → activa Penumbra.

`make install` firma la app con un certificado autofirmado que crea una sola vez en tu llavero (`Penumbra Local Signing`, sin datos personales). Así la identidad de la app no cambia y **el permiso se mantiene al actualizar**. Con firma ad hoc se perdería en cada versión.

### Precompilada (GitHub Releases)

Descarga `Penumbra-x.y.z.zip` de [Releases](https://github.com/juanmacuevas/penumbra-mac/releases), descomprímelo y mueve `Penumbra.app` a `/Applications`. No está firmada por Apple (no hay cuenta de desarrollador de pago), así que la primera vez macOS la bloquea: abre Ajustes del Sistema → Privacidad y seguridad y pulsa **Abrir igualmente**. Al actualizar la versión precompilada hay que volver a conceder Accesibilidad.

### Homebrew

```sh
brew install --cask juanmacuevas/tap/penumbra
```

Instala la app precompilada, así que vale la misma nota de arriba para el primer arranque (Abrir igualmente y después Accesibilidad).

## Barra de menús

Pausar / reanudar · Abrir al iniciar sesión · lista de atajos · Salir.

## Cómo funciona

Penumbra escucha las teclas de brillo con un `CGEventTap` y las bloquea, de modo que el sistema nunca las ve. Después:

| Qué | API |
|---|---|
| Brillo de la pantalla | `DisplayServicesGetBrightness` / `SetBrightness` (framework privado DisplayServices). La vía antigua de IOKit no funciona con la pantalla interna en Apple Silicon. |
| Night Shift | `CBBlueLightClient` (CoreBrightness, privado). La fuerza se convierte a Kelvin en dos tramos lineales: 6000 → 4100 → 2700 K. Detalle: si Night Shift solo está activo por horario, el sistema guarda la fuerza nueva pero **no la aplica en pantalla**, así que Penumbra lo pasa antes a modo manual. |
| Más cálido que 2700 K | `CGSetDisplayTransferByTable` (pública): el verde y el azul se escalan según el cuerpo negro (aproximación de Tanner Helland) respecto a 2700 K, y después bajan a 0 para el rojo puro. macOS restaura la tabla al cerrar la app, así que la pantalla nunca puede quedarse teñida. |
| Luz del teclado | `KeyboardBrightnessClient` (CoreBrightness, privado). Fijar un nivel desactiva el ajuste automático, que si no sube la luz del teclado a oscuras. |
| Fn Lock | `HIDFKeyMode` de IOHIDSystem (se aplica al momento) y la preferencia `com.apple.keyboard.fnState`, para que Ajustes muestre lo mismo. |
| Barra en pantalla | Panel flotante propio. La barra del sistema siempre muestra el brillo real, así que no puede mostrar estos pasos ni la temperatura. |

Todos los parámetros (pasos, zonas, tiempos) están en [`Sources/Penumbra/Config.swift`](Sources/Penumbra/Config.swift).

## Limitaciones

- **APIs privadas.** No puede ir a la App Store, y una actualización de macOS podría romper alguna función.
- Solo funciona con la pantalla interna (todavía no con monitores externos).
- Probado en un MacBook Air M2 con macOS 26.
- Cambiar Night Shift desde Penumbra lo pasa a modo manual. Tu horario sigue guardado.

## Desinstalar

```sh
make uninstall
```

Después quita Penumbra en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad y, si quieres, borra el certificado `Penumbra Local Signing` en Acceso a Llaveros.

## Proyectos relacionados

Otros enfoques de problemas parecidos, que vale la pena conocer:

- [Lunar](https://github.com/alin23/Lunar): control completo del brillo, incluidos monitores externos.
- [MonitorControl](https://github.com/MonitorControl/MonitorControl): brillo y volumen de monitores externos con las teclas nativas.
- [BetterDisplay](https://github.com/waydabber/BetterDisplay): gestión de pantallas, incluido el aumento de brillo XDR/HDR.
- [f.lux](https://justgetflux.com): la app original de temperatura de color, con modo cuarto oscuro (rojo).
- [Shifty](https://github.com/thompsonate/Shifty): controles de Night Shift en la barra de menús, con reglas por app.
- [Fluor](https://github.com/Pyroh/Fluor): cambia el modo de la tecla Fn según la app.
- [macos-fn-toggle](https://github.com/jkbrzt/macos-fn-toggle): cambia el modo Fn desde un script.
- [Midnight Keyboard](https://midnightkeyboard.pages.dev/): luz del teclado por debajo del mínimo de macOS (de pago).

## Licencia

[MIT](LICENSE) · Hecho por [JuanMa Cuevas](https://github.com/juanmacuevas)
