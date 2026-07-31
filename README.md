# caelestia → windows

Port of the [caelestia](https://github.com/caelestia-dots/shell) look to Windows
Terminal. One command on a fresh machine.

```powershell
git clone <this-repo> caelestia-windows
cd caelestia-windows
.\install.ps1
```

Idempotent — re-run it any time. Costs exactly one UAC prompt on a fresh
machine (fonts must be installed system-wide), and none on later runs.

---

## What this actually is

Caelestia is a **Quickshell desktop shell for Hyprland**: bar, launcher,
notification popups, dashboard, lockscreen, plus Material You theming driven by
your wallpaper. It is not a terminal.

So this repo ports the part that *can* cross over — the color scheme, font,
prompt, and surface treatment — onto Windows Terminal. The bar, launcher and
dashboard have no Windows equivalent and are out of scope.

Every value is extracted from upstream source, not eyeballed:

| What | Upstream file |
|---|---|
| ANSI 0–15 | `services/Colours.qml` → `term0`..`term15` |
| Surface / text / cursor | `services/Colours.qml` → `m3*` Material 3 roles |
| Font family + size | `plugin/src/Caelestia/Config/appearanceconfig.hpp` |
| Opacity | same file → `transparency.base` (see deviation below) |

`theme/caelestia.psd1` is the single source of truth for the Windows Terminal
side. `config/starship/starship.toml` carries the
same values inline so they stay readable and hand-editable.

---

## What you get

- **Windows Terminal** — `overdrive` scheme, acrylic at 55%, CaskaydiaCove NF,
  neon cursor, tinted tab row, hidden scrollbar, PowerShell 7 as default profile.
- **Dimmed inactive panes** via `unfocusedAppearance`, so the focused pane reads
  as focused.
- **Prompt marks** — a tick on the scrollbar per command, <kbd>Ctrl</kbd>+<kbd>↑</kbd>/<kbd>↓</kbd> to jump between them.
- **Quake dropdown** — <kbd>Win</kbd>+<kbd>`</kbd> slides a terminal down from the top of the screen
  from anywhere. Needs Terminal already running.
- **Panes** — <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>-</kbd>/<kbd>+</kbd> to split, <kbd>Alt</kbd>+arrows to move focus,
  <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd> to zoom.
- **Starship** — rounded Material 3 pill prompt.
- **PowerShell profile** — fish-style inline autosuggestion, palette-matched
  syntax highlighting, history search on ↑/↓.

---

## Honest limitations

Read this before you are disappointed.

**Windows Terminal has no animations.** No pane transitions, no cursor easing,
no smooth scroll. Caelestia's "smooth" *is* the Hyprland + QML animation layer.
This is not a settings gap — the feature does not exist in Windows Terminal, and
no amount of configuration will add it.

**Acrylic ≠ Hyprland blur.** Windows exposes one fixed blur. No radius, no
passes, no noise, no vibrancy. It also desaturates when the window loses focus.

Opacity needs to be *low* for the blur to read at all. Measured on Windows 11:
at `0.85` (upstream's `transparency.base`) and `0.75`, acrylic is
indistinguishable from opaque against a dark background — the blur is applied,
it just looks flat. It only becomes legible around `0.6`. This repo ships
`0.65`, the one deliberate deviation from upstream values. Upstream also ships
`transparency.enabled = false`, so there is no "correct" value to match here.

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
GitHub release (~52 MB) and installed system-wide, which is what costs the UAC
prompt. `JetBrainsMono NF` is installed as an automatic fallback.

---

## Gotchas already handled

These cost real debugging time. They are fixed in the repo; documented so you
do not reintroduce them when editing.

**The font family is `CaskaydiaCove NF`, not `CaskaydiaCove Nerd Font`.** The
TTFs are named `CaskaydiaCoveNerdFont-Regular.ttf`, but the family GDI reports
is `CaskaydiaCove NF`. Using the filename spelling makes every detection miss —
the installer re-downloads 52 MB on every run and configs silently fall back to
another font. Verify a family name with:

```powershell
Add-Type -AssemblyName System.Drawing; (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
```

**Starship palette keys must be lowercase.** Starship lowercases colour names
while parsing a style string, so a camelCase key like `m3primaryCont` never
matches its own definition. There is no warning — the segment just renders
unstyled. This is why every key in `starship.toml` is snake_case.

**Windows Terminal cannot see per-user fonts at all.** It is a packaged (MSIX)
app, so a font installed only for the current user is invisible to it — Terminal
silently falls back to another family, which looks exactly like "the theme did
not apply", with no error anywhere. Unpackaged apps *do* see per-user fonts, so
every ordinary way of checking reports the font as installed. Fonts must go in
`C:\Windows\Fonts` + `HKLM`, which needs admin.

Critically, `InstalledFontCollection` reports per-user fonts too, so it **cannot**
answer "will Terminal see this?". Check `HKLM` instead:

```powershell
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts').PSObject.Properties.Name -match 'Caskaydia'
```

**A newly installed font is invisible until you sign out** unless you call
`AddFontResourceW` and broadcast `WM_FONTCHANGE`. Copying the TTF and adding the
registry entry is necessary but not sufficient. `install.ps1` does the P/Invoke
so the font is usable immediately.

**Valid JSON is not valid settings.** Windows Terminal checks `settings.json`
against a schema, and a single bad enum value makes it reject the *entire file*
and silently revert to stock defaults behind one dialog — your theme, font and
default profile all quietly disappear. `ConvertFrom-Json` succeeding proves only
that the JSON parses.

This bit already: `"monitor": "toCursor"` on a `globalSummon` binding is
well-formed JSON, but the allowed values are `any | toCurrent | toMouse`.
`install.ps1` now validates every enum it writes *before* touching the file and
refuses to write if anything is wrong. Extend the table in
`Test-TerminalSettings` when adding a new setting, and run:

```powershell
pwsh -NoProfile -File tests\Test-Settings.ps1
```

**Elevation is pooled.** Both the package stage and the font stage need admin.
They push their work into one queue that is flushed in a single elevated child
process between the Font and Terminal stages, so the run costs exactly one UAC
prompt rather than two. `-NoElevate` skips it; `-Yes` skips only the
confirmation, not the UAC dialog itself.

**PowerShell 7 installs per-user without UAC.** `winget install --scope user`
puts `pwsh.exe` in `WindowsApps` as an MSIX alias, *not* under Program Files —
so probe that path too, or you will elevate for nothing and then fail to find it.

**`.ps1` files must be ASCII.** Windows PowerShell reads scripts as ANSI when
there is no BOM, so a stray em dash in a comment breaks string parsing several
lines later with a baffling error.

**Use `-ErrorAction Ignore`, not `SilentlyContinue`, in a profile.**
`SilentlyContinue` still appends to `$Error`, so every new session opens with a
phantom exception.

---

## Colour schemes

`theme/caelestia.psd1` holds every scheme and one `Active` line selecting which
is used. It is the single source of truth for **three** consumers — Windows
Terminal, the starship prompt palette, and PSReadLine syntax colours — so
changing that one word restyles all of them on the next run:

```powershell
Active = 'overdrive'     # or 'caelestia' / 'caelestia-faithful'
.\install.ps1 -Only Terminal,Starship,Profile
```

| Scheme | What it is |
|---|---|
| `overdrive` | **Default.** High-contrast dark, cyberpunk/anime. Cool near-black base, saturated primaries, neon orange cursor. |
| `caelestia` | Upstream's scheme with its four unusable ANSI slots repaired. |
| `caelestia-faithful` | `term0`..`term15` exactly as upstream ships them. |

**Why `caelestia-faithful` is not the default.** Upstream derives its palette
from a pink wallpaper, so six of the eight hues land in one pink-to-peach band.
It is cohesive but carries almost no information: `green` (`#ffbbb7`) is pink and
reads the same as `yellow`; `yellow` (`#ffdedf`) and `brightYellow` (`#fff1f0`)
sit within a few percent of the foreground, so warnings do not look like
warnings; `brightBlue` (`#dcbc93`) is tan and collides with `cyan` (`#ffba93`).
A git diff is close to unreadable.

The `caelestia` scheme fixes that using upstream's *own* Material 3 roles where
they exist — `Green` becomes `m3success`, `Yellow` becomes `m3tertiary`. Only
`Cyan` and `BrightBlue` are genuinely invented, because upstream has no cool
accent to borrow.

Adding a scheme means copying a block and keeping every key. The installer
validates that a scheme defines all of them, and that each is `#rrggbb`, before
writing anything.

---

## Performance

Every setting here is config-only. Two things were deliberately left out
because they cost per-frame GPU work for pure decoration:
`experimental.pixelShaderPath` and `backgroundImage`.

Measured on this machine (minimum of 5 runs each):

| | |
|---|---|
| `pwsh -NoProfile` baseline | 170 ms |
| with this profile | 417 ms (was 454) |
| starship prompt render | ~86 ms per prompt |

What the profile does about it: PSReadLine is taken from the module the host has
already loaded instead of calling `Get-Module -ListAvailable` (~40 ms) and
re-importing it (~80 ms), and `starship init` output is cached to
`%LOCALAPPDATA%\caelestia\starship-init.ps1` and regenerated only when
`starship.exe` is newer.

Two honest limits on that:

The init cache saves less than it looks like it should. Spawning `starship.exe`
is only ~38 ms of the ~240 ms; the rest is *executing* the init script, which
builds a dynamic module, and caching the text does not avoid that.

The ~86 ms per prompt is starship's process-spawn cost, not configuration. An
empty `starship.toml` measures 85 ms against this repo's 86 ms — the whole
caelestia config is worth 1 ms. Trimming modules would buy nothing. If you want
that 86 ms back the only real option is dropping starship for a hand-written
PowerShell `prompt` function, which costs you git status and language versions.

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
.\install.ps1 -Only Terminal,Starship  # one or more stages
```

Stages: `Packages`, `Font`, `Terminal`, `Starship`, `Profile`.

### Safety

`settings.json` is **merged, never overwritten** — your profiles, keybindings
and conda entries survive. A timestamped `.bak` is written next to it before
every run. Existing PowerShell profiles are backed up to
`.bak` too.

To roll back, restore the newest `.bak` in
`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\`.

---

## Layout

```
install.ps1                      idempotent installer
theme/caelestia.psd1             palette, single source of truth
config/starship/starship.toml    -> ~/.config/starship.toml
config/powershell/profile.ps1    -> both PS 5.1 and PS 7 profiles
caelestia-shell/                 upstream clone, reference only (gitignored)
```

## Requirements

Windows 10 1809+ or Windows 11, `winget`, and an internet connection on first
run. PowerShell 5.1 is enough to bootstrap; the installer pulls PowerShell 7.

## Credits

Palette and design from [caelestia-dots/shell](https://github.com/caelestia-dots/shell).
