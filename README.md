# Penumbra

**Finer control of your Mac's brightness, color temperature (all the way to pure red) and keyboard backlight — from the brightness keys you already have.**

[Español](README.es.md)

<!-- TODO: add docs/hud.png (screenshot or GIF of the on-screen bar) -->

Penumbra is a tiny menu bar app for Apple Silicon MacBooks that takes over the brightness keys and makes them do more:

- **Brightness in 100 steps** of 1 % instead of macOS's 16.
- **Color temperature** from 6000 K down to 1000 K in 50 K steps — past Night Shift's 2700 K floor — and then on to **pure red** for astronomy and dark-adapted eyes.
- **Keyboard backlight** in 10 steps that all visibly change the light. (Apple Silicon keyboards dropped the dedicated keys.)
- **Fn Lock** like on a ThinkPad: `fn` + `Esc` toggles between F1–F12 and media keys.
- A native-looking on-screen bar (Liquid Glass on macOS 26) with the value: `50/100`, `3450 K`, `● 40%`.

No windows, no Dock icon, no dependencies. Native Swift, a few hundred lines.

## Shortcuts

| Keys | Does |
|---|---|
| ☀︎ | Brightness |
| ⇧ Shift + ☀︎ | Color temperature (Night Shift → red) |
| ⌃ Control + ☀︎ | Keyboard backlight |
| Both ☀︎ keys together | Cycle the mode: brightness → temperature → keyboard (back to brightness after 5 s idle) |
| `fn` + `Esc` | Fn Lock: F1–F12 ⇄ media keys |

- **Tap** = one step. **Quick taps** take bigger steps (1, 1, 2, 2, 3). **Hold** = steady repeat.
- "☀︎" means whatever produces a brightness event on your Mac: the brightness keys, or `fn` + F1/F2 if you use F1–F12 as standard function keys. Penumbra respects that setting.

## Install

### From source (recommended)

Requires the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/juanmacuevas/penumbra-mac.git
cd penumbra-mac
make install
```

This builds `Penumbra.app`, installs it in `/Applications` and opens it. On first launch macOS asks for **Accessibility** permission (needed to capture the brightness keys): System Settings → Privacy & Security → Accessibility → enable Penumbra.

`make install` signs the app with a self-signed certificate it creates once in your login keychain (`Penumbra Local Signing`, no personal data). That keeps the app's identity stable, so **the permission survives updates**. Builds signed ad-hoc would lose it every time.

### Prebuilt (GitHub Releases)

Download `Penumbra-x.y.z.zip` from [Releases](https://github.com/juanmacuevas/penumbra-mac/releases), unzip, and move `Penumbra.app` to `/Applications`. It is not signed by Apple (no paid developer account), so the first time macOS will block it: open System Settings → Privacy & Security and click **Open Anyway**. Updating a prebuilt app requires granting Accessibility again.

### Homebrew

```sh
brew install --cask juanmacuevas/tap/penumbra
```

Installs the prebuilt app, so the same first-launch note as above applies (Open Anyway, then Accessibility).

## Menu bar

Pause / resume · Open at Login · the shortcuts list · Quit.

## How it works

Penumbra listens for the brightness keys with a `CGEventTap` and swallows them, so the system never sees them. Then:

| What | API |
|---|---|
| Display brightness | `DisplayServicesGetBrightness` / `SetBrightness` (private DisplayServices framework). The old IOKit route doesn't work on Apple Silicon's built-in panel. |
| Night Shift | `CBBlueLightClient` (private CoreBrightness). Strength maps to Kelvin in two linear segments: 6000 → 4100 → 2700 K. Gotcha: if Night Shift is only on because of its schedule, new strengths are stored but **not shown**, so Penumbra switches it to manual mode first. |
| Warmer than 2700 K | Public `CGSetDisplayTransferByTable`: green and blue are scaled by blackbody ratios (Tanner Helland's approximation) relative to 2700 K, then faded to 0 for pure red. macOS restores the table when the app quits, so the screen can never be left tinted. |
| Keyboard backlight | `KeyboardBrightnessClient` (private CoreBrightness). Setting a level turns off auto-adjust, which otherwise brightens the keyboard in the dark. |
| Fn Lock | `HIDFKeyMode` on IOHIDSystem (applies live), plus the `com.apple.keyboard.fnState` preference so System Settings agrees. |
| On-screen bar | Its own floating panel. The system OSD always shows the real brightness, so it can't show these steps or the temperature. |

All tunables (steps, zones, timings) are in [`Sources/Penumbra/Config.swift`](Sources/Penumbra/Config.swift).

## Limitations

- **Private APIs.** Not App Store material, and a macOS update could break a feature.
- Built-in display only (no external monitors yet).
- Tested on an M2 MacBook Air with macOS 26.
- Changing Night Shift from Penumbra puts it in manual mode (your schedule stays saved).

## Uninstall

```sh
make uninstall
```

Then remove Penumbra from System Settings → Privacy & Security → Accessibility, and optionally the `Penumbra Local Signing` certificate from Keychain Access.

## Related projects

Different takes on similar problems — worth a look:

- [Lunar](https://github.com/alin23/Lunar) — comprehensive display brightness control, including external monitors.
- [MonitorControl](https://github.com/MonitorControl/MonitorControl) — brightness and volume for external displays, with native keys.
- [BetterDisplay](https://github.com/waydabber/BetterDisplay) — display management, including XDR/HDR brightness upscaling.
- [f.lux](https://justgetflux.com) — the original color temperature app, with a darkroom (red) mode.
- [Shifty](https://github.com/thompsonate/Shifty) — Night Shift controls from the menu bar, per-app rules.
- [Fluor](https://github.com/Pyroh/Fluor) — switches the Fn key mode per app.
- [macos-fn-toggle](https://github.com/jkbrzt/macos-fn-toggle) — toggles the Fn key mode from a script.
- [Midnight Keyboard](https://midnightkeyboard.pages.dev/) — keyboard backlight below the macOS minimum (commercial).

## License

[MIT](LICENSE) · Made by [JuanMa Cuevas](https://github.com/juanmacuevas)
