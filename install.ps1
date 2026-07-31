<#
.SYNOPSIS
    Deploys the Caelestia terminal theme to Windows Terminal + WezTerm.

.DESCRIPTION
    Idempotent. Safe to re-run. Never overwrites Windows Terminal's
    settings.json wholesale — it merges, and backs up first.

    Runs on Windows PowerShell 5.1 or PowerShell 7. No admin rights needed:
    packages and fonts install to user scope.

.PARAMETER Only
    Run a subset: Packages, Font, Terminal, WezTerm, Starship, Profile.

.PARAMETER SkipPackages
    Deploy configs only; assume the toolchain is already installed.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Only Terminal,WezTerm
    .\install.ps1 -SkipPackages -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Packages', 'Font', 'Terminal', 'WezTerm', 'Starship', 'Profile')]
    [string[]]$Only,

    [switch]$SkipPackages
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Theme = Import-PowerShellDataFile (Join-Path $Root 'theme\caelestia.psd1')

$NerdFontVersion = 'v3.4.0'
$NerdFontFamily  = 'CaskaydiaCove Nerd Font'
$FontStyles      = @('Regular', 'Bold', 'Italic', 'BoldItalic')

function Write-Step { param($m) Write-Host "==> $m" -ForegroundColor Magenta }
function Write-Ok   { param($m) Write-Host "    $m" -ForegroundColor DarkGray }
function Write-Warn2{ param($m) Write-Host "  ! $m" -ForegroundColor Yellow }

function Test-Stage {
    param([string]$Name)
    if ($Only) { return $Only -contains $Name }
    if ($SkipPackages -and $Name -in @('Packages', 'Font')) { return $false }
    return $true
}

function Get-InstalledFontFamilies {
    Add-Type -AssemblyName System.Drawing
    (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
}

function Set-JsonProperty {
    # PS 5.1's ConvertFrom-Json yields PSCustomObject, which has no indexer
    # assignment. This adds-or-updates a property on one.
    param($Object, [string]$Name, $Value)
    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

# ------------------------------------------------------------------ packages
function Install-Toolchain {
    Write-Step 'Installing toolchain via winget'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
    }

    # CaskaydiaCove NF is not in winget; it is handled by Install-NerdFont.
    $packages = @(
        @{ Id = 'Microsoft.PowerShell';       Name = 'PowerShell 7' }
        @{ Id = 'Starship.Starship';          Name = 'Starship' }
        @{ Id = 'wez.wezterm';                Name = 'WezTerm' }
        @{ Id = 'Fastfetch-cli.Fastfetch';    Name = 'Fastfetch' }
        @{ Id = 'DEVCOM.JetBrainsMonoNerdFont'; Name = 'JetBrainsMono NF (fallback font)' }
    )

    foreach ($p in $packages) {
        $installed = winget list --id $p.Id --exact --accept-source-agreements 2>&1 | Out-String
        if ($installed -match [regex]::Escape($p.Id)) {
            Write-Ok "$($p.Name) already installed"
            continue
        }
        if ($PSCmdlet.ShouldProcess($p.Name, 'winget install')) {
            Write-Ok "installing $($p.Name)..."
            winget install --id $p.Id --exact --silent `
                --accept-package-agreements --accept-source-agreements `
                --disable-interactivity 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Warn2 "$($p.Name) returned exit $LASTEXITCODE (may need manual install)"
            }
        }
    }
}

# ---------------------------------------------------------------- nerd font
function Install-NerdFont {
    Write-Step "Installing $NerdFontFamily"

    if ((Get-InstalledFontFamilies) -contains $NerdFontFamily) {
        Write-Ok 'already installed'
        return
    }
    if (-not $PSCmdlet.ShouldProcess($NerdFontFamily, 'download and install')) { return }

    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$NerdFontVersion/CascadiaCode.zip"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "caelestia-font-$(Get-Random)"
    $zip = "$tmp.zip"

    try {
        Write-Ok 'downloading (~52 MB)...'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

        Expand-Archive -Path $zip -DestinationPath $tmp -Force

        # User-scope font install: copy to the per-user font dir and register
        # under HKCU. No elevation required (Windows 10 1809+).
        $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
        New-Item -ItemType Directory -Force -Path $regPath | Out-Null

        $wanted = $FontStyles | ForEach-Object { "CaskaydiaCoveNerdFont-$_.ttf" }
        $files = Get-ChildItem $tmp -Filter '*.ttf' -Recurse |
                 Where-Object { $wanted -contains $_.Name }

        if (-not $files) {
            throw "No matching TTFs in the archive (expected e.g. CaskaydiaCoveNerdFont-Regular.ttf)."
        }

        foreach ($f in $files) {
            $dest = Join-Path $fontDir $f.Name
            Copy-Item $f.FullName $dest -Force
            New-ItemProperty -Path $regPath -Name "$($f.BaseName) (TrueType)" `
                -Value $dest -PropertyType String -Force | Out-Null
            Write-Ok "registered $($f.Name)"
        }
        Write-Warn2 'Restart Windows Terminal for the new font to appear.'
    }
    finally {
        Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-FontFace {
    # Fall back gracefully so the configs never point at a missing family.
    $families = Get-InstalledFontFamilies
    foreach ($c in @($NerdFontFamily, 'JetBrainsMono Nerd Font', 'JetBrainsMono NFM', 'Cascadia Mono')) {
        if ($families -contains $c) { return $c }
    }
    return 'Consolas'
}

# --------------------------------------------------------- windows terminal
function Deploy-WindowsTerminal {
    Write-Step 'Configuring Windows Terminal'

    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $found = $candidates | Where-Object { Test-Path $_ }
    if (-not $found) { Write-Warn2 'Windows Terminal settings.json not found; skipping.'; return }

    $face = Resolve-FontFace

    foreach ($settingsPath in $found) {
        if (-not $PSCmdlet.ShouldProcess($settingsPath, 'merge caelestia theme')) { continue }

        $backup = "$settingsPath.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item $settingsPath $backup -Force
        Write-Ok "backup -> $(Split-Path -Leaf $backup)"

        $json = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # -- colour scheme (replace any existing entry of the same name) -----
        $scheme = [ordered]@{
            name                = $Theme.Name
            background          = $Theme.Background
            foreground          = $Theme.Foreground
            cursorColor         = $Theme.Cursor
            selectionBackground = $Theme.SelectionBackground
            black               = $Theme.Black
            red                 = $Theme.Red
            green               = $Theme.Green
            yellow              = $Theme.Yellow
            blue                = $Theme.Blue
            purple              = $Theme.Purple
            cyan                = $Theme.Cyan
            white               = $Theme.White
            brightBlack         = $Theme.BrightBlack
            brightRed           = $Theme.BrightRed
            brightGreen         = $Theme.BrightGreen
            brightYellow        = $Theme.BrightYellow
            brightBlue          = $Theme.BrightBlue
            brightPurple        = $Theme.BrightPurple
            brightCyan          = $Theme.BrightCyan
            brightWhite         = $Theme.BrightWhite
        }
        $schemes = @()
        if ($json.PSObject.Properties.Name -contains 'schemes' -and $json.schemes) {
            $schemes = @($json.schemes | Where-Object { $_.name -ne $Theme.Name })
        }
        Set-JsonProperty $json 'schemes' (@($schemes) + [pscustomobject]$scheme)

        # -- window theme (tab row tinted to m3surfaceContainerLowest) -------
        $wtTheme = [pscustomobject]@{
            name   = 'caelestia'
            tab    = [pscustomobject]@{ background = '#261d20FF' }
            tabRow = [pscustomobject]@{
                background            = '#130c0eFF'
                unfocusedBackground   = '#191114FF'
            }
            window = [pscustomobject]@{ applicationTheme = 'dark' }
        }
        $themes = @()
        if ($json.PSObject.Properties.Name -contains 'themes' -and $json.themes) {
            $themes = @($json.themes | Where-Object { $_.name -ne 'caelestia' })
        }
        Set-JsonProperty $json 'themes' (@($themes) + $wtTheme)
        Set-JsonProperty $json 'theme' 'caelestia'

        # -- profile defaults ------------------------------------------------
        if ($json.PSObject.Properties.Name -notcontains 'profiles') {
            Set-JsonProperty $json 'profiles' ([pscustomobject]@{})
        }
        if ($json.profiles.PSObject.Properties.Name -notcontains 'defaults') {
            Set-JsonProperty $json.profiles 'defaults' ([pscustomobject]@{})
        }
        $d = $json.profiles.defaults

        Set-JsonProperty $d 'colorScheme' $Theme.Name
        Set-JsonProperty $d 'font' ([pscustomobject]@{
            face     = $face
            size     = $Theme.FontSize
            weight   = 'normal'
            features = [pscustomobject]@{ calt = 1; liga = 1 }
        })
        # Acrylic is the only blur Windows exposes; radius is not tunable.
        Set-JsonProperty $d 'useAcrylic'       $true
        Set-JsonProperty $d 'opacity'          ([int]($Theme.Opacity * 100))
        Set-JsonProperty $d 'padding'          '16,12,16,12'
        Set-JsonProperty $d 'cursorShape'      'bar'
        Set-JsonProperty $d 'antialiasingMode' 'grayscale'
        Set-JsonProperty $d 'scrollbarState'   'hidden'
        Set-JsonProperty $d 'bellStyle'        'none'

        $json | ConvertTo-Json -Depth 32 |
            Set-Content $settingsPath -Encoding UTF8
        Write-Ok "themed $(Split-Path (Split-Path $settingsPath -Parent) -Leaf) (font: $face)"
    }
}

# ------------------------------------------------------------------ wezterm
function Deploy-WezTerm {
    Write-Step 'Configuring WezTerm'
    $src  = Join-Path $Root 'config\wezterm\wezterm.lua'
    $dest = Join-Path $env:USERPROFILE '.wezterm.lua'
    if ($PSCmdlet.ShouldProcess($dest, 'write wezterm.lua')) {
        if ((Test-Path $dest) -and -not (Get-Item $dest).LinkType) {
            Copy-Item $dest "$dest.bak" -Force
        }
        Copy-Item $src $dest -Force
        Write-Ok "-> $dest"
    }
}

# ----------------------------------------------------------------- starship
function Deploy-Starship {
    Write-Step 'Configuring Starship'
    $src  = Join-Path $Root 'config\starship\starship.toml'
    $dir  = Join-Path $env:USERPROFILE '.config'
    $dest = Join-Path $dir 'starship.toml'
    if ($PSCmdlet.ShouldProcess($dest, 'write starship.toml')) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Copy-Item $src $dest -Force
        [Environment]::SetEnvironmentVariable('STARSHIP_CONFIG', $dest, 'User')
        Write-Ok "-> $dest"
    }
}

# ------------------------------------------------------------------ profile
function Deploy-Profile {
    Write-Step 'Installing PowerShell profile'
    $src = Join-Path $Root 'config\powershell\profile.ps1'

    $targets = @(
        Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
        Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    )
    # OneDrive-redirected Documents is common; honour the real profile path too.
    if ($PROFILE.CurrentUserCurrentHost -and $targets -notcontains $PROFILE.CurrentUserCurrentHost) {
        $targets += $PROFILE.CurrentUserCurrentHost
    }

    foreach ($t in ($targets | Select-Object -Unique)) {
        if (-not $PSCmdlet.ShouldProcess($t, 'write profile')) { continue }
        New-Item -ItemType Directory -Force -Path (Split-Path $t -Parent) | Out-Null
        if (Test-Path $t) { Copy-Item $t "$t.bak" -Force }
        Copy-Item $src $t -Force
        Write-Ok "-> $t"
    }

    # conda's own prompt prefix fights the starship theme.
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess('conda', 'set changeps1 false')) {
            conda config --set changeps1 false 2>&1 | Out-Null
            Write-Ok 'conda changeps1 disabled'
        }
    }
}

# --------------------------------------------------------------------- main
Write-Host ''
Write-Host '  caelestia -> windows' -ForegroundColor Magenta
Write-Host '  ------------------------------------' -ForegroundColor DarkGray

if (Test-Stage 'Packages') { Install-Toolchain }
if (Test-Stage 'Font')     { Install-NerdFont }
if (Test-Stage 'Terminal') { Deploy-WindowsTerminal }
if (Test-Stage 'WezTerm')  { Deploy-WezTerm }
if (Test-Stage 'Starship') { Deploy-Starship }
if (Test-Stage 'Profile')  { Deploy-Profile }

Write-Host ''
Write-Step 'Done'
Write-Ok 'Restart your terminal to load the font, profile and prompt.'
Write-Host ''
