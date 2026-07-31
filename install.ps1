<#
.SYNOPSIS
    Deploys the Caelestia terminal theme to Windows Terminal + WezTerm.

.DESCRIPTION
    Idempotent and safe to re-run.

    Install policy:
      * Nothing is installed if it is already present. Detection is done by
        probing for the actual binary or font family, not by asking winget
        (which costs seconds per package and lies after a failed install).
      * User-scope installs are attempted first, so most runs never trigger UAC.
      * Anything that genuinely needs admin is queued and installed in a SINGLE
        elevated pass, so you see at most one UAC prompt for the whole run.

    Windows Terminal's settings.json is merged, never overwritten. Every file
    touched is backed up first.

.PARAMETER Only
    Run a subset: Packages, Font, Terminal, WezTerm, Starship, Profile.

.PARAMETER SkipPackages
    Deploy configs only; assume the toolchain is present.

.PARAMETER Yes
    Never prompt. Elevation, if needed, is requested without asking first.

.PARAMETER NoElevate
    Never elevate. Packages needing admin are reported and skipped.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -WhatIf
    .\install.ps1 -Only Terminal,WezTerm
    .\install.ps1 -SkipPackages
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Packages', 'Font', 'Terminal', 'WezTerm', 'Starship', 'Profile')]
    [string[]]$Only,

    [switch]$SkipPackages,
    [switch]$Yes,
    [switch]$NoElevate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Theme = Import-PowerShellDataFile (Join-Path $Root 'theme\caelestia.psd1')

$NerdFontVersion = 'v3.4.0'
$NerdFontFamily  = 'CaskaydiaCove Nerd Font'
$FontStyles      = @('Regular', 'Bold', 'Italic', 'BoldItalic')

# Results collected for the closing summary.
$script:Summary = [System.Collections.Generic.List[object]]::new()
function Add-Result {
    param([string]$Item, [ValidateSet('installed','present','skipped','failed','done')][string]$State, [string]$Note = '')
    $script:Summary.Add([pscustomobject]@{ Item = $Item; State = $State; Note = $Note })
}

function Write-Step { param($m) Write-Host "==> $m" -ForegroundColor Magenta }
function Write-Ok   { param($m) Write-Host "    $m" -ForegroundColor DarkGray }
function Write-Info { param($m) Write-Host "  - $m" -ForegroundColor Cyan }
function Write-Warn2{ param($m) Write-Host "  ! $m" -ForegroundColor Yellow }
function Write-Bad  { param($m) Write-Host "  x $m" -ForegroundColor Red }

function Test-Stage {
    param([string]$Name)
    if ($Only) { return $Only -contains $Name }
    if ($SkipPackages -and $Name -in @('Packages', 'Font')) { return $false }
    return $true
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Update-PathFromRegistry {
    # Installs performed in this session (or in the elevated child) do not
    # update the parent's PATH. Re-read it so later detection succeeds.
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
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

function Invoke-WithRetry {
    param([scriptblock]$Script, [int]$Retries = 2, [int]$DelaySeconds = 3, [string]$What = 'operation')
    for ($i = 0; $i -le $Retries; $i++) {
        try { return & $Script }
        catch {
            if ($i -eq $Retries) { throw }
            Write-Warn2 "$What failed ($($_.Exception.Message.Trim())); retrying $($i + 1)/$Retries..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

# ================================================================= packages
# Scope: 'user'    - installs per-user, never needs admin
#        'machine' - always needs admin, goes straight to the elevated batch
#        'auto'    - try user scope first, fall back to the elevated batch
$Packages = @(
    @{
        Id = 'Microsoft.PowerShell'; Name = 'PowerShell 7'; Scope = 'machine'
        Test = {
            (Get-Command pwsh -ErrorAction SilentlyContinue) -or
            (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe")
        }
    }
    @{
        Id = 'Starship.Starship'; Name = 'Starship'; Scope = 'auto'
        Test = {
            (Get-Command starship -ErrorAction SilentlyContinue) -or
            (Test-Path "$env:ProgramFiles\starship\bin\starship.exe")
        }
    }
    @{
        Id = 'wez.wezterm'; Name = 'WezTerm'; Scope = 'auto'
        Test = {
            (Get-Command wezterm -ErrorAction SilentlyContinue) -or
            (Test-Path "$env:ProgramFiles\WezTerm\wezterm-gui.exe") -or
            (Test-Path "$env:LOCALAPPDATA\Programs\WezTerm\wezterm-gui.exe")
        }
    }
    @{
        Id = 'Fastfetch-cli.Fastfetch'; Name = 'Fastfetch'; Scope = 'user'
        Test = { [bool](Get-Command fastfetch -ErrorAction SilentlyContinue) }
    }
    @{
        Id = 'DEVCOM.JetBrainsMonoNerdFont'; Name = 'JetBrainsMono NF (fallback font)'; Scope = 'auto'
        Test = { (Get-InstalledFontFamilies) -match 'JetBrainsMono\s*(Nerd Font|NF)' }
    }
)

function Invoke-Winget {
    param([string]$Id, [string]$Scope)
    $wingetArgs = @(
        'install', '--id', $Id, '--exact', '--silent',
        '--accept-package-agreements', '--accept-source-agreements',
        '--disable-interactivity'
    )
    if ($Scope -eq 'user') { $wingetArgs += @('--scope', 'user') }
    & winget @wingetArgs 2>&1 | Out-Null
    return $LASTEXITCODE
}

function Install-Toolchain {
    Write-Step 'Toolchain'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Bad 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
        Add-Result 'winget' 'failed' 'not present'
        return
    }

    Update-PathFromRegistry

    # ---- 1. detect ------------------------------------------------------
    $missing = @()
    foreach ($p in $Packages) {
        if (& $p.Test) {
            Write-Ok "$($p.Name) - already installed"
            Add-Result $p.Name 'present'
        } else {
            $missing += $p
        }
    }
    if (-not $missing) { return }

    # ---- 2. user-scope pass (no UAC) ------------------------------------
    $needsAdmin = @()
    foreach ($p in $missing) {
        if ($p.Scope -eq 'machine') { $needsAdmin += $p; continue }
        if (-not $PSCmdlet.ShouldProcess($p.Name, 'winget install (user scope)')) { continue }

        Write-Info "installing $($p.Name)..."
        $code = Invoke-Winget -Id $p.Id -Scope 'user'
        if ($code -eq 0) {
            Write-Ok "$($p.Name) installed"
            Add-Result $p.Name 'installed' 'user scope'
        } elseif ($p.Scope -eq 'auto') {
            Write-Ok "$($p.Name) needs admin - queued"
            $needsAdmin += $p
        } else {
            Write-Bad "$($p.Name) failed (exit $code)"
            Add-Result $p.Name 'failed' "winget exit $code"
        }
    }
    if (-not $needsAdmin) { Update-PathFromRegistry; return }

    # ---- 3. single elevated pass ----------------------------------------
    Install-Elevated -Packages $needsAdmin
    Update-PathFromRegistry

    # ---- 4. verify -------------------------------------------------------
    foreach ($p in $needsAdmin) {
        if (& $p.Test) {
            Add-Result $p.Name 'installed' 'elevated'
        } else {
            Add-Result $p.Name 'failed' 'still missing after elevated install'
        }
    }
}

function Install-Elevated {
    param([object[]]$Packages)

    $names = ($Packages | ForEach-Object { $_.Name }) -join ', '

    if (Test-IsAdmin) {
        Write-Info "already elevated; installing: $names"
        foreach ($p in $Packages) {
            if (-not $PSCmdlet.ShouldProcess($p.Name, 'winget install')) { continue }
            $code = Invoke-Winget -Id $p.Id -Scope 'default'
            if ($code -ne 0) { Write-Bad "$($p.Name) failed (exit $code)" }
        }
        return
    }

    if ($NoElevate) {
        Write-Warn2 "-NoElevate set; these need admin and were skipped: $names"
        foreach ($p in $Packages) { Add-Result $p.Name 'skipped' 'needs admin' }
        return
    }

    Write-Host ''
    Write-Warn2 "These require administrator rights: $names"
    Write-Warn2 'You will get ONE UAC prompt covering all of them.'

    if (-not $Yes -and [Environment]::UserInteractive) {
        $answer = Read-Host '    Elevate now? [Y/n]'
        if ($answer -and $answer -notmatch '^(y|yes)$') {
            Write-Warn2 'Declined. Skipping admin-scoped packages.'
            foreach ($p in $Packages) { Add-Result $p.Name 'skipped' 'elevation declined' }
            return
        }
    }
    if (-not $PSCmdlet.ShouldProcess($names, 'install elevated (one UAC prompt)')) { return }

    # One child process installs everything, so UAC is shown exactly once.
    $log = Join-Path ([IO.Path]::GetTempPath()) "caelestia-elevated-$(Get-Date -Format yyyyMMddHHmmss).log"
    $ids = ($Packages | ForEach-Object { "'$($_.Id)'" }) -join ','
    $inner = @"
`$ErrorActionPreference = 'Continue'
Start-Transcript -Path '$log' -Force | Out-Null
foreach (`$id in @($ids)) {
    Write-Host "installing `$id"
    winget install --id `$id --exact --silent ``
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    Write-Host "  exit=`$LASTEXITCODE"
}
Stop-Transcript | Out-Null
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner))

    try {
        $proc = Start-Process -FilePath 'powershell.exe' `
            -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded `
            -Verb RunAs -Wait -PassThru -WindowStyle Hidden
        Write-Ok "elevated pass finished (exit $($proc.ExitCode)); log: $log"
    } catch {
        # Most common cause: the user dismissed the UAC dialog.
        Write-Bad "elevation failed or was cancelled: $($_.Exception.Message.Trim())"
        foreach ($p in $Packages) { Add-Result $p.Name 'skipped' 'elevation cancelled' }
    }
}

# ================================================================ nerd font
function Install-NerdFont {
    Write-Step "Font - $NerdFontFamily"

    if ((Get-InstalledFontFamilies) -contains $NerdFontFamily) {
        Write-Ok 'already installed'
        Add-Result $NerdFontFamily 'present'
        return
    }
    if (-not $PSCmdlet.ShouldProcess($NerdFontFamily, 'download and install')) { return }

    # Per-user font install (Windows 10 1809+): copy into the user font dir and
    # register under HKCU. Deliberately avoids the system font dir so this
    # stage never contributes a UAC prompt.
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$NerdFontVersion/CascadiaCode.zip"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "caelestia-font-$(Get-Random)"
    $zip = "$tmp.zip"

    try {
        Write-Info 'downloading (~52 MB)...'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WithRetry -What 'font download' -Script {
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 300
        }

        Expand-Archive -Path $zip -DestinationPath $tmp -Force

        $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

        $wanted = $FontStyles | ForEach-Object { "CaskaydiaCoveNerdFont-$_.ttf" }
        $files = Get-ChildItem $tmp -Filter '*.ttf' -Recurse |
                 Where-Object { $wanted -contains $_.Name }

        if (-not $files) {
            throw 'no matching TTFs in archive (expected CaskaydiaCoveNerdFont-Regular.ttf)'
        }

        foreach ($f in $files) {
            $dest = Join-Path $fontDir $f.Name
            if (-not (Test-Path $dest)) { Copy-Item $f.FullName $dest -Force }
            New-ItemProperty -Path $regPath -Name "$($f.BaseName) (TrueType)" `
                -Value $dest -PropertyType String -Force | Out-Null
            Write-Ok "registered $($f.Name)"
        }
        Add-Result $NerdFontFamily 'installed' "$($files.Count) styles, user scope"
        Write-Warn2 'Restart your terminal for the font to appear.'
    }
    catch {
        Write-Bad "font install failed: $($_.Exception.Message.Trim())"
        Write-Warn2 'JetBrainsMono NF will be used as fallback.'
        Add-Result $NerdFontFamily 'failed' $_.Exception.Message.Trim()
    }
    finally {
        Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-FontFace {
    # Never point a config at a family that is not installed.
    $families = Get-InstalledFontFamilies
    foreach ($c in @($NerdFontFamily, 'JetBrainsMono Nerd Font', 'JetBrainsMono NF',
                     'JetBrainsMono NFM', 'Cascadia Mono', 'Consolas')) {
        if ($families -contains $c) { return $c }
    }
    return 'Consolas'
}

function Backup-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $backup = "$Path.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $Path $backup -Force
    Write-Ok "backup -> $(Split-Path -Leaf $backup)"
}

# ======================================================== windows terminal
function Deploy-WindowsTerminal {
    Write-Step 'Windows Terminal'

    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $found = @($candidates | Where-Object { Test-Path $_ })
    if (-not $found) {
        Write-Warn2 'settings.json not found; Windows Terminal not installed?'
        Add-Result 'Windows Terminal' 'skipped' 'settings.json not found'
        return
    }

    $face = Resolve-FontFace

    foreach ($settingsPath in $found) {
        if (-not $PSCmdlet.ShouldProcess($settingsPath, 'merge caelestia theme')) { continue }
        $label = Split-Path (Split-Path $settingsPath -Parent) -Leaf

        try {
            Backup-File $settingsPath
            $json = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

            # -- colour scheme ---------------------------------------------
            $scheme = [ordered]@{
                name                = $Theme.Name
                background          = $Theme.Background
                foreground          = $Theme.Foreground
                cursorColor         = $Theme.Cursor
                selectionBackground = $Theme.SelectionBackground
                black        = $Theme.Black;        red          = $Theme.Red
                green        = $Theme.Green;        yellow       = $Theme.Yellow
                blue         = $Theme.Blue;         purple       = $Theme.Purple
                cyan         = $Theme.Cyan;         white        = $Theme.White
                brightBlack  = $Theme.BrightBlack;  brightRed    = $Theme.BrightRed
                brightGreen  = $Theme.BrightGreen;  brightYellow = $Theme.BrightYellow
                brightBlue   = $Theme.BrightBlue;   brightPurple = $Theme.BrightPurple
                brightCyan   = $Theme.BrightCyan;   brightWhite  = $Theme.BrightWhite
            }
            $schemes = @()
            if ($json.PSObject.Properties.Name -contains 'schemes' -and $json.schemes) {
                $schemes = @($json.schemes | Where-Object { $_.name -ne $Theme.Name })
            }
            Set-JsonProperty $json 'schemes' (@($schemes) + [pscustomobject]$scheme)

            # -- window theme ----------------------------------------------
            $wtTheme = [pscustomobject]@{
                name   = 'caelestia'
                tab    = [pscustomobject]@{ background = '#261d20FF' }
                tabRow = [pscustomobject]@{
                    background          = '#130c0eFF'
                    unfocusedBackground = '#191114FF'
                }
                window = [pscustomobject]@{ applicationTheme = 'dark' }
            }
            $themes = @()
            if ($json.PSObject.Properties.Name -contains 'themes' -and $json.themes) {
                $themes = @($json.themes | Where-Object { $_.name -ne 'caelestia' })
            }
            Set-JsonProperty $json 'themes' (@($themes) + $wtTheme)
            Set-JsonProperty $json 'theme' 'caelestia'

            # -- profile defaults ------------------------------------------
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

            $json | ConvertTo-Json -Depth 32 | Set-Content $settingsPath -Encoding UTF8
            Write-Ok "themed $label (font: $face)"
            Add-Result "Windows Terminal ($label)" 'done' "font: $face"
        }
        catch {
            Write-Bad "failed on $label`: $($_.Exception.Message.Trim())"
            Add-Result "Windows Terminal ($label)" 'failed' $_.Exception.Message.Trim()
        }
    }
}

# ================================================================= wezterm
function Deploy-WezTerm {
    Write-Step 'WezTerm'
    $src  = Join-Path $Root 'config\wezterm\wezterm.lua'
    $dest = Join-Path $env:USERPROFILE '.wezterm.lua'

    if ((Test-Path $dest) -and
        ((Get-FileHash $src).Hash -eq (Get-FileHash $dest).Hash)) {
        Write-Ok 'already current'
        Add-Result 'WezTerm config' 'present'
        return
    }
    if (-not $PSCmdlet.ShouldProcess($dest, 'write wezterm.lua')) { return }

    Backup-File $dest
    Copy-Item $src $dest -Force
    Write-Ok "-> $dest"
    Add-Result 'WezTerm config' 'done' $dest
}

# ================================================================ starship
function Deploy-Starship {
    Write-Step 'Starship'
    $src  = Join-Path $Root 'config\starship\starship.toml'
    $dir  = Join-Path $env:USERPROFILE '.config'
    $dest = Join-Path $dir 'starship.toml'

    if (-not $PSCmdlet.ShouldProcess($dest, 'write starship.toml')) { return }

    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (-not ((Test-Path $dest) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dest).Hash))) {
        Backup-File $dest
        Copy-Item $src $dest -Force
        Write-Ok "-> $dest"
    } else {
        Write-Ok 'already current'
    }

    if ([Environment]::GetEnvironmentVariable('STARSHIP_CONFIG', 'User') -ne $dest) {
        [Environment]::SetEnvironmentVariable('STARSHIP_CONFIG', $dest, 'User')
        Write-Ok 'STARSHIP_CONFIG set'
    }
    Add-Result 'Starship config' 'done' $dest
}

# ================================================================= profile
function Deploy-Profile {
    Write-Step 'PowerShell profile'
    $src = Join-Path $Root 'config\powershell\profile.ps1'

    $targets = @(
        Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
        Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    )
    # Documents is often redirected to OneDrive; honour the real profile path.
    if ($PROFILE.CurrentUserCurrentHost -and $targets -notcontains $PROFILE.CurrentUserCurrentHost) {
        $targets += $PROFILE.CurrentUserCurrentHost
    }

    foreach ($t in ($targets | Select-Object -Unique)) {
        if ((Test-Path $t) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $t).Hash)) {
            Write-Ok "already current - $(Split-Path (Split-Path $t -Parent) -Leaf)"
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($t, 'write profile')) { continue }
        New-Item -ItemType Directory -Force -Path (Split-Path $t -Parent) | Out-Null
        Backup-File $t
        Copy-Item $src $t -Force
        Write-Ok "-> $t"
    }
    Add-Result 'PowerShell profile' 'done'

    # conda's own prompt prefix fights the starship theme.
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        $current = (conda config --show changeps1 2>&1 | Out-String)
        if ($current -notmatch 'changeps1:\s*False') {
            if ($PSCmdlet.ShouldProcess('conda', 'set changeps1 false')) {
                conda config --set changeps1 false 2>&1 | Out-Null
                Write-Ok 'conda changeps1 disabled'
            }
        } else {
            Write-Ok 'conda changeps1 already disabled'
        }
    }
}

# ==================================================================== main
Write-Host ''
Write-Host '  caelestia -> windows' -ForegroundColor Magenta
Write-Host '  ------------------------------------' -ForegroundColor DarkGray

$stages = [ordered]@{
    Packages = { Install-Toolchain }
    Font     = { Install-NerdFont }
    Terminal = { Deploy-WindowsTerminal }
    WezTerm  = { Deploy-WezTerm }
    Starship = { Deploy-Starship }
    Profile  = { Deploy-Profile }
}

foreach ($name in $stages.Keys) {
    if (-not (Test-Stage $name)) { continue }
    try { & $stages[$name] }
    catch {
        # One broken stage must not abort the rest of the run.
        Write-Bad "stage '$name' failed: $($_.Exception.Message.Trim())"
        Add-Result $name 'failed' $_.Exception.Message.Trim()
    }
}

Write-Host ''
Write-Step 'Summary'
if ($script:Summary.Count) {
    $script:Summary | ForEach-Object {
        $colour = switch ($_.State) {
            'installed' { 'Green' }  'done'    { 'Green' }
            'present'   { 'DarkGray' } 'skipped' { 'Yellow' }
            default     { 'Red' }
        }
        $note = if ($_.Note) { "  ($($_.Note))" } else { '' }
        Write-Host ("    {0,-34} {1}{2}" -f $_.Item, $_.State, $note) -ForegroundColor $colour
    }
}
$failed = @($script:Summary | Where-Object { $_.State -eq 'failed' })
Write-Host ''
if ($failed) {
    Write-Warn2 "$($failed.Count) item(s) failed - see above. Re-run to retry; nothing already done will be repeated."
} else {
    Write-Ok 'All good. Restart your terminal to load the font, profile and prompt.'
}
Write-Host ''
