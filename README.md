# caelestia → windows

Port of the [caelestia](https://github.com/caelestia-dots/shell) look to Windows
Terminal and WezTerm. One command on a fresh machine.

```powershell
git clone <this-repo> caelestia-windows
cd caelestia-windows
.\install.ps1
```

Idempotent — re-run it any time. Nothing needs admin rights.

---

## What this actually is

Caelestia is a **Quickshell desktop shell for Hyprland**: bar, launcher,
notification popups, dashboard, lockscreen, plus Material You theming driven by
your wallpaper. It is not a terminal.

So this repo ports the part that *can* cross over — the color scheme, font,
prompt, and surface treatment — onto two Windows terminals. The bar, launcher
and dashboard have no Windows equivalent and are out of scope.

Every value is extracted from upstream source, not eyeballed:

| What | Upstream file |
|---|---|
| ANSI 0–15 | `services/Colours.qml` → `term0`..`term15` |
| Surface / text / cursor | `services/Colours.qml` → `m3*` Material 3 roles |
| Font family + size | `plugin/src/Caelestia/Config/appearanceconfig.hpp` |
| Opacity `0.85` | same file → `transparency.base` |

`theme/caelestia.psd1` is the single source of truth for the Windows Terminal
side. `config/wezterm/wezterm.lua` and `config/starship/starship.toml` carry the
same values inline so they stay readable and hand-editable.

---

## What you get

- **Windows Terminal** — caelestia scheme, acrylic at 85%, CaskaydiaCove NF,
  bar cursor, tinted tab row, hidden scrollbar.
- **WezTerm** — same palette, plus the things Windows Terminal cannot do:
  WebGPU renderer, 120 fps, eased cursor animation, no title bar, real acrylic
  backdrop.
- **Starship** — rounded Material 3 pill prompt.
- **PowerShell profile** — fish-style inline autosuggestion, palette-matched
  syntax highlighting, history search on ↑/↓.

---

## Honest limitations

Read this before you are disappointed.

**Windows Terminal has no animations.** No pane transitions, no cursor easing,
no smooth scroll. Caelestia's "smooth" *is* the Hyprland + QML animation layer.
This is not a settings gap — the feature does not exist. If smoothness is what
you are chasing, use the WezTerm config; it is the half of this repo that can
actually deliver it.

**Acrylic ≠ Hyprland blur.** Windows exposes one fixed blur. No radius, no
passes, no noise, no vibrancy. It also desaturates when the window loses focus.
0.85 opacity is upstream's own value and stays readable; go lower and text
starts to swim.

**No custom corner radius or colored border.** You get Windows 11's default
rounding. Caelestia's thick rounded corners and accent borders are compositor
features.

**The scheme is static here.** Upstream regenerates the whole palette from your
wallpaper on every change. This repo ships the default scheme. See below to
re-theme.

**Nerd Font glyphs need the font.** Until the font installs and you restart the
terminal, the Starship prompt renders as tofu boxes. This is expected, not a
broken config.

**`CaskaydiaCove NF` is not in winget.** It is fetched from the Nerd Fonts
GitHub release (~52 MB) and installed to user scope. `JetBrainsMono NF` is
installed as an automatic fallback.

---

## Re-theming from a wallpaper

To reproduce upstream's wallpaper-driven Material You behaviour:

```powershell
cargo install matugen
matugen image "C:\path\to\wallpaper.jpg" --json hex
```

Map the output into `theme/caelestia.psd1` (`primary` → `Cursor`, `surface` →
`Background`, `onSurface` → `Foreground`) and re-run `.\install.ps1 -Only Terminal`.

The ANSI 0–15 slots are caelestia's own derivation, not standard Material You
output — keep them or hand-tune to taste.

---

## Usage

```powershell
.\install.ps1                          # everything
.\install.ps1 -WhatIf                  # dry run, changes nothing
.\install.ps1 -SkipPackages            # configs only
.\install.ps1 -Only Terminal,WezTerm   # one or more stages
```

Stages: `Packages`, `Font`, `Terminal`, `WezTerm`, `Starship`, `Profile`.

### Safety

`settings.json` is **merged, never overwritten** — your profiles, keybindings
and conda entries survive. A timestamped `.bak` is written next to it before
every run. Existing `wezterm.lua` and PowerShell profiles are backed up to
`.bak` too.

To roll back, restore the newest `.bak` in
`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\`.

---

## Layout

```
install.ps1                      idempotent installer
theme/caelestia.psd1             palette, single source of truth
config/wezterm/wezterm.lua       -> ~/.wezterm.lua
config/starship/starship.toml    -> ~/.config/starship.toml
config/powershell/profile.ps1    -> both PS 5.1 and PS 7 profiles
caelestia-shell/                 upstream clone, reference only (gitignored)
```

## Requirements

Windows 10 1809+ or Windows 11, `winget`, and an internet connection on first
run. PowerShell 5.1 is enough to bootstrap; the installer pulls PowerShell 7.

## Credits

Palette and design from [caelestia-dots/shell](https://github.com/caelestia-dots/shell).
