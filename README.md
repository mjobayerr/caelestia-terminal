# caelestia-terminal

A themed Windows Terminal setup: colour scheme, Nerd Font, acrylic blur, a
starship prompt, and a tuned PowerShell profile. One command on a fresh machine,
everything driven by a single config file.

Ported from [caelestia](https://github.com/caelestia-dots/shell), a Quickshell
desktop shell for Hyprland.

---

## Install

On a brand-new machine, from **Windows PowerShell** (`powershell`, not `pwsh` —
PowerShell 7 is one of the things this installs):

```powershell
git clone https://github.com/mjobayerr/caelestia-terminal.git
```

```powershell
cd caelestia-terminal
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

### Why the `-ExecutionPolicy Bypass`

Windows blocks script execution by default (`Restricted` on a fresh client
install), so plain `.\install.ps1` fails with *"running scripts is disabled on
this system"*. The command above applies `Bypass` to that one process only — it
changes nothing permanently and needs no admin rights.

If you prefer to set it yourself instead:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

That lasts until you close the window. Use `-Scope CurrentUser -ExecutionPolicy
RemoteSigned` to make it permanent, which is the usual developer setting.

Two things that can still bite:

- **Downloaded the ZIP instead of cloning?** Files from the internet carry a
  Mark of the Web, which `RemoteSigned` blocks even after you change the policy.
  Clear it: `Get-ChildItem -Recurse | Unblock-File`. (`-ExecutionPolicy Bypass`
  ignores MOTW, so the command above is unaffected.)
- **On a managed/work machine**, Group Policy can pin the policy. `Bypass` on
  the command line cannot override `MachinePolicy` or `UserPolicy`. Check with
  `Get-ExecutionPolicy -List`.

### What it does

Installs PowerShell 7, Starship, Fastfetch and CaskaydiaCove NF, then writes the
Terminal theme, prompt and profile.

**One UAC prompt** on a fresh machine — fonts must be installed system-wide, and
both the package and font stages are pooled into a single elevated pass. Later
runs need none.

Re-run any time. It is idempotent: already-installed things are detected and
skipped, `settings.json` is merged rather than overwritten, and every file it
touches is backed up with a timestamp first.

```powershell
.\install.ps1                          # everything
.\install.ps1 -WhatIf                  # dry run, changes nothing
.\install.ps1 -SkipPackages            # configs only, after editing config.psd1
.\install.ps1 -Only Terminal,Starship  # one or more stages
.\install.ps1 -NoElevate               # skip anything needing admin
```

Stages: `Packages`, `Font`, `Terminal`, `Starship`, `Profile`.

---

## What you get

- **Windows Terminal** — `overdrive` scheme, acrylic at 55%, CaskaydiaCove NF,
  minimal top bar, hidden scrollbar, PowerShell 7 as the default profile.
- **Quake dropdown** — <kbd>Win</kbd>+<kbd>`</kbd> drops a terminal down from
  the top of the screen from anywhere.
- **Panes** — <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>-</kbd>/<kbd>+</kbd> split,
  <kbd>Alt</kbd>+arrows move focus, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd>
  zooms. Inactive panes dim.
- **Prompt marks** — a tick per command on the scrollbar,
  <kbd>Ctrl</kbd>+<kbd>↑</kbd>/<kbd>↓</kbd> to jump between them.
- **Starship prompt** — rounded pill segments, git status, language versions.
- **PowerShell profile** — fish-style inline autosuggestion, palette-matched
  syntax highlighting, prefix history search on <kbd>↑</kbd>/<kbd>↓</kbd>.

---

## Configuration

Everything lives in [`config.psd1`](config.psd1) — nothing is hardcoded in the
installer. Edit it, then:

```powershell
.\install.ps1 -SkipPackages
```

| Section | Covers |
|---|---|
| `Active` | Which scheme in `Schemes` to use |
| `Window` | Opacity, acrylic, padding, top bar, launch mode |
| `Terminal` | Cursor, antialiasing, scrollbar, bell, scrollback, prompt marks |
| `Keybindings` | Every chord. `$null` on one leaves that chord alone |
| `Font` | Face, size, weight, ligatures |
| `Shell` | Starship, fastfetch, predictions, history search, conda prompt |
| `NerdFont` | Which Nerd Font to fetch when missing |
| `Schemes` | The palettes themselves |

Delete any key and it falls back to the `$Defaults` table in `install.ps1`, so a
trimmed-down config file is still valid.

`Active` drives **three** consumers — Terminal, the starship palette, and
PSReadLine syntax colours. The latter two are generated from it at install time,
so they cannot drift out of sync.

### Minimising the top bar

Four levels, smallest last, all under `Window`:

| Setting | Effect |
|---|---|
| `ShowTabsInTitlebar = $true` | Tabs sit *in* the title bar — one row, not two |
| `AlwaysShowTabs = $false` | Tab strip disappears while only one tab is open |
| `ShowTitleInTitlebar = $false` | Drops the title text |
| `LaunchMode = 'focus'` | **No title bar and no tabs at all** |

The first three are on by default, giving one thin bar that collapses to just
the window controls. For the fourth you don't have to commit —
<kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>F</kbd> toggles all chrome at runtime.

With no tab bar, the command palette
(<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>) becomes your only way to reach
other tabs.

### Colour schemes

```powershell
Active = 'overdrive'   # or 'caelestia' / 'caelestia-faithful'
```

| Scheme | What it is |
|---|---|
| `overdrive` | **Default.** High-contrast dark, cyberpunk/anime. Cool near-black base, saturated primaries, neon orange cursor. |
| `caelestia` | Upstream's scheme with its four unusable ANSI slots repaired. |
| `caelestia-faithful` | `term0`..`term15` exactly as upstream ships them. |

**Why `caelestia-faithful` is not the default.** Upstream derives its palette
from a pink wallpaper, so six of the eight hues land in one pink-to-peach band.
It looks cohesive but carries almost no information: `green` (`#ffbbb7`) is pink
and reads the same as `yellow`; `yellow` and `brightYellow` sit within a few
percent of the foreground, so warnings don't look like warnings; `brightBlue`
(`#dcbc93`) is tan and collides with `cyan`. A git diff is close to unreadable.

The `caelestia` scheme fixes that using upstream's *own* Material 3 roles —
`Green` becomes `m3success`, `Yellow` becomes `m3tertiary`. Only `Cyan` and
`BrightBlue` are invented, because upstream has no cool accent to borrow.

To add a scheme, copy a block and keep every key. The installer checks that a
scheme defines all of them, and that each is `#rrggbb`, before writing anything.

### Re-theming from a wallpaper

To reproduce upstream's wallpaper-driven Material You behaviour:

```powershell
cargo install matugen
```

```powershell
matugen image "C:\path\to\wallpaper.jpg" --json hex
```

Map the output into a scheme (`primary` → `Cursor`, `surface` → `Background`,
`onSurface` → `Foreground`) and re-run. The ANSI 0–15 slots are caelestia's own
derivation, not standard Material You output.

---

## Honest limitations

**No animations.** No pane transitions, no cursor easing, no smooth scroll.
Caelestia's "smooth" *is* the Hyprland + QML animation layer. This isn't a
settings gap — the feature doesn't exist in Windows Terminal.

**Acrylic ≠ Hyprland blur.** Windows exposes one fixed blur: no radius, no
passes, no noise, no vibrancy. It also desaturates when the window loses focus.

Opacity has to be *low* for the blur to read at all. Measured on Windows 11: at
`0.85` and `0.75`, acrylic is indistinguishable from opaque against a dark
background — the blur is applied, it just looks flat. It only becomes legible
around `0.6`. This ships `0.55` (`Window.Opacity`).

**No custom corner radius or coloured border.** You get Windows 11's default
rounding. Caelestia's thick corners and accent borders are compositor features.

**The scheme is static.** Upstream regenerates the palette from your wallpaper
on every change; there's no equivalent daemon here.

**Glyphs need the font.** Until it installs and you restart Terminal, the
starship prompt renders as tofu boxes. Expected, not a broken config.

---

## Gotchas already handled

Documented so you don't reintroduce them when editing.

**Windows Terminal cannot see per-user fonts.** It's a packaged (MSIX) app, so a
font installed for the current user only is invisible to it — Terminal silently
falls back to another family, which looks exactly like "the theme didn't apply",
with no error anywhere. Unpackaged apps *do* see per-user fonts, so every
ordinary check reports the font as installed. Fonts must go in
`C:\Windows\Fonts` + `HKLM`, which is what needs admin.

`InstalledFontCollection` reports per-user fonts too, so it **cannot** answer
"will Terminal see this?". Ask `HKLM` instead:

```powershell
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts').PSObject.Properties.Name -match 'Caskaydia'
```

**The font family is `CaskaydiaCove NF`, not `CaskaydiaCove Nerd Font`.** The
TTFs are named `CaskaydiaCoveNerdFont-*.ttf`, which is *not* the family name.
Using the filename spelling makes every detection miss, so the installer
re-downloads 52 MB every run and configs fall back to another font.

**A newly installed font is invisible until you sign out** unless you call
`AddFontResourceW` and broadcast `WM_FONTCHANGE`. Copying the TTF and adding the
registry entry is necessary but not sufficient.

**Valid JSON is not valid settings.** Terminal validates `settings.json` against
a schema, and one bad enum makes it reject the *entire file* and revert to stock
defaults behind a single dialog. `ConvertFrom-Json` succeeding proves only that
the JSON parses. This bit already: `"monitor": "toCursor"` is well-formed JSON,
but the allowed values are `any | toCurrent | toMouse`.

`install.ps1` validates every enum it writes *before* touching the file. Extend
the table in `Test-TerminalSettings` when adding a setting, and run:

```powershell
pwsh -NoProfile -File tests\Test-Settings.ps1
```

**`.Keys` on a hashtable is ambiguous.** A hashtable entry named `Keys` shadows
the `ICollection.Keys` property, so `$config.Keys` returns your data instead of
the key names. Use `.PSBase.Keys` when you mean the collection.

**Starship palette keys must be lowercase.** Starship lowercases colour names
while parsing a style string, so a camelCase key never matches its own
definition — no warning, the segment just renders unstyled.

**`.ps1` files must be ASCII.** Windows PowerShell reads scripts as ANSI when
there's no BOM, so a stray em dash in a comment breaks string parsing several
lines later with a baffling error.

**PowerShell 7 installs per-user without UAC.** `winget install --scope user`
puts `pwsh.exe` in `WindowsApps` as an MSIX alias, *not* under Program Files —
probe that path too, or you'll elevate for nothing and still not find it.

**Use `-ErrorAction Ignore`, not `SilentlyContinue`, in a profile.**
`SilentlyContinue` still appends to `$Error`, so every session opens with a
phantom exception.

---

## Performance

Every setting here is config-only. `experimental.pixelShaderPath` and
`backgroundImage` are deliberately left out: per-frame GPU work for pure
decoration.

Measured (minimum of 5 runs):

| | |
|---|---|
| `pwsh -NoProfile` baseline | 170 ms |
| with this profile | 417 ms (was 454) |
| starship prompt render | ~86 ms per prompt |

The profile takes PSReadLine from the already-loaded module instead of calling
`Get-Module -ListAvailable` (~40 ms) and re-importing it (~80 ms), and caches
`starship init` output to `%LOCALAPPDATA%\caelestia\starship-init.ps1`.

Two limits worth stating plainly:

The init cache saves less than it looks like it should. Spawning `starship.exe`
is only ~38 ms of the ~240 ms; the rest is *executing* the init, which builds a
dynamic module, and caching the text doesn't avoid that.

The ~86 ms per prompt is starship's process-spawn cost, not configuration — an
empty `starship.toml` measures 85 ms against this repo's 86 ms. Trimming modules
would buy nothing. The only real lever is dropping starship for a hand-written
`prompt` function, at the cost of git status and language versions.

---

## Layout

```
install.ps1                    idempotent installer
config.psd1                    all settings: colours, font, keys, toggles
config/starship/starship.toml  -> ~/.config/starship.toml (palette generated)
config/powershell/profile.ps1  -> both PS 5.1 and PS 7 profiles
tests/Test-Settings.ps1        settings-validation unit tests
```

`settings.json` is **merged, never overwritten** — your profiles, keybindings
and conda entries survive, and keybindings are merged by chord so only
same-chord entries are replaced. To roll back, restore the newest `.bak` in
`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\`.

## Requirements

Windows 10 1809+ or Windows 11, `winget` (ships as *App Installer*), and an
internet connection on first run. Windows PowerShell 5.1 is enough to bootstrap.

## Credits

Palette and design from
[caelestia-dots/shell](https://github.com/caelestia-dots/shell).
