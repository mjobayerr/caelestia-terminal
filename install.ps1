<#
.SYNOPSIS
    Deploys the Caelestia terminal theme to Windows Terminal.

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
    Run a subset: Packages, Font, Terminal, Starship, Profile.

.PARAMETER SkipPackages
    Deploy configs only; assume the toolchain is present.

.PARAMETER Yes
    Never prompt. Elevation, if needed, is requested without asking first.

.PARAMETER NoElevate
    Never elevate. Packages needing admin are reported and skipped.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -WhatIf
    .\install.ps1 -Only Terminal,Starship
    .\install.ps1 -SkipPackages
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Packages', 'Font', 'Terminal', 'Starship', 'Profile')]
    [string[]]$Only,

    [switch]$SkipPackages,
    [switch]$Yes,
    [switch]$NoElevate,

    # Leave Windows Terminal's defaultProfile alone instead of switching it to
    # PowerShell 7.
    [switch]$KeepDefaultProfile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Defaults for every setting. The config file is merged over this, so deleting
# a key from config.psd1 falls back here instead of erroring or writing $null.
$Defaults = @{
    Active = 'overdrive'
    Window = @{
        Opacity = 0.55; Acrylic = $true; Padding = '16,12,16,12'
        ShowTabsInTitlebar = $true; AlwaysShowTabs = $false
        ShowTitleInTitlebar = $false; TabWidthMode = 'compact'
        AcrylicInTabRow = $true; LaunchMode = 'default'
        CenterOnLaunch = $true; SnapToGridOnResize = $true
        FocusFollowMouse = $false; UnfocusedOpacity = 85
    }
    Terminal = @{
        CursorShape = 'bar'; AntialiasingMode = 'grayscale'
        ScrollbarState = 'hidden'; BellStyle = 'none'; ScrollbackLines = 10000
        AdjustIndistinguishableColors = 'indexed'
        AutoMarkPrompts = $true; ShowMarksOnScrollbar = $true
        UsePowerShell7AsDefault = $true
    }
    Keybindings = @{
        Enabled = $true
        ScrollToPreviousMark = 'ctrl+up'; ScrollToNextMark = 'ctrl+down'
        SplitDown = 'alt+shift+minus'; SplitRight = 'alt+shift+plus'
        FocusLeft = 'alt+left'; FocusRight = 'alt+right'
        FocusUp = 'alt+up'; FocusDown = 'alt+down'
        ZoomPane = 'ctrl+shift+z'; ToggleFocusMode = 'alt+shift+f'
        QuakeSummon = 'win+sc(41)'; QuakeDropdownMs = 150; QuakeMonitor = 'toMouse'
    }
    Font  = @{ Face = 'CaskaydiaCove NF'; Size = 12; Weight = 'normal'; Ligatures = $true }
    Shell = @{
        Starship = $true; Fastfetch = $true; Predictions = $true
        HistorySearchOnArrows = $true; DisableCondaPrompt = $true
    }
    NerdFont = @{
        Version = 'v3.4.0'; Archive = 'CascadiaCode.zip'
        FilePrefix = 'CaskaydiaCoveNerdFont'; Family = 'CaskaydiaCove NF'
        Styles = @('Regular', 'Bold', 'Italic', 'BoldItalic')
    }
}

function Merge-Config {
    # One level of nesting is all the config has, so a shallow per-section
    # merge is enough. User values win; anything absent falls back.
    param([hashtable]$Base, [hashtable]$Override)
    $out = @{}
    foreach ($k in $Base.PSBase.Keys) {
        if ($Base[$k] -is [hashtable] -and $Override.ContainsKey($k) -and $Override[$k] -is [hashtable]) {
            $section = $Base[$k].Clone()
            foreach ($sk in $Override[$k].PSBase.Keys) { $section[$sk] = $Override[$k][$sk] }
            $out[$k] = $section
        } elseif ($Override.ContainsKey($k)) {
            $out[$k] = $Override[$k]
        } else {
            $out[$k] = $Base[$k]
        }
    }
    # Sections present only in the user's file (e.g. Schemes).
    foreach ($k in $Override.PSBase.Keys) { if (-not $out.ContainsKey($k)) { $out[$k] = $Override[$k] } }
    return $out
}

$ConfigPath = Join-Path $Root 'config.psd1'
if (-not (Test-Path $ConfigPath)) { throw "config.psd1 not found at $ConfigPath" }
$ThemeFile = Merge-Config -Base $Defaults -Override (Import-PowerShellDataFile $ConfigPath)

$Cfg = $ThemeFile   # shorthand used throughout

# Resolve the active scheme up front and fail loudly on a typo or a missing key,
# rather than writing a half-styled settings.json and leaving it to be noticed
# by eye later.
$ActivePaletteName = $ThemeFile.Active
if (-not $ThemeFile.Schemes.ContainsKey($ActivePaletteName)) {
    throw "config.psd1: Active = '$ActivePaletteName' but no such scheme. Available: $($ThemeFile.Schemes.PSBase.Keys -join ', ')"
}
$ActivePalette = $ThemeFile.Schemes[$ActivePaletteName]

$RequiredKeys = @(
    'Background','Foreground','Cursor','SelectionBackground'
    'Black','Red','Green','Yellow','Blue','Purple','Cyan','White'
    'BrightBlack','BrightRed','BrightGreen','BrightYellow'
    'BrightBlue','BrightPurple','BrightCyan','BrightWhite'
    'TabBackground','TabRowBackground','TabRowUnfocused'
    'PromptPrimary','PromptOnPrimary','PromptContainer','PromptOnContainer'
    'PromptSecondary','PromptTertiary','PromptError','PromptSuccess'
    'PromptSurface','PromptSurfaceHigh','PromptOutline'
)
$missingKeys = @($RequiredKeys | Where-Object { -not $ActivePalette.ContainsKey($_) })
if ($missingKeys) {
    throw "scheme '$ActivePaletteName' is missing: $($missingKeys -join ', ')"
}
$badHex = @($RequiredKeys | Where-Object { $ActivePalette[$_] -notmatch '^#[0-9a-fA-F]{6}$' })
if ($badHex) {
    throw "scheme '$ActivePaletteName' has non-#rrggbb values: $($badHex -join ', ')"
}

$Theme = @{
    Name     = 'Caelestia'
    FontFace = $Cfg.Font.Face
    FontSize = $Cfg.Font.Size
    Opacity  = $Cfg.Window.Opacity
}

# NerdFont.Family is the family the patched Cascadia reports to GDI
# ('CaskaydiaCove NF'). NerdFont.FilePrefix is the TTF filename stem
# ('CaskaydiaCoveNerdFont-*.ttf'), which is NOT the family name -- using the
# filename spelling as the family makes every detection miss, so the font
# re-downloads on every run and configs fall back to another family.
$NerdFontVersion = $Cfg.NerdFont.Version
$NerdFontFamily  = $Cfg.NerdFont.Family
$FontFilePrefix  = $Cfg.NerdFont.FilePrefix
$FontStyles      = $Cfg.NerdFont.Styles

# Work that needs admin, collected across stages and flushed in one elevated
# child process so the run costs at most a single UAC prompt.
$script:ElevatedActions = [System.Collections.Generic.List[object]]::new()
$script:PendingVerify   = @()
function Add-ElevatedAction {
    param([string]$Label, [string]$Command)
    $script:ElevatedActions.Add([pscustomobject]@{ Label = $Label; Command = $Command })
}

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

function Register-FontWithSession {
    # Copying a TTF into the per-user font dir and adding the HKCU entry makes
    # the font persist across logon, but Windows will not surface it to running
    # or newly launched apps until AddFontResourceW loads it and WM_FONTCHANGE
    # is broadcast. Without this the font is invisible until sign-out.
    param([string[]]$Paths)

    if (-not ('CaelestiaFontLoader' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CaelestiaFontLoader {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int AddFontResourceW(string lpFileName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
'@
    }

    $added = 0
    foreach ($p in $Paths) { $added += [CaelestiaFontLoader]::AddFontResourceW($p) }

    $result = [UIntPtr]::Zero
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_FONTCHANGE  = 0x001D
    $SMTO_ABORTIFHUNG = 2
    [void][CaelestiaFontLoader]::SendMessageTimeout(
        $HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero,
        $SMTO_ABORTIFHUNG, 1000, [ref]$result)

    return $added
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
        # 'auto', not 'machine': winget installs PS7 per-user without any UAC
        # prompt. Forcing machine scope elevates for no reason.
        Id = 'Microsoft.PowerShell'; Name = 'PowerShell 7'; Scope = 'auto'
        Test = {
            (Get-Command pwsh -ErrorAction SilentlyContinue) -or
            (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") -or
            (Test-Path "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe") -or
            (Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe")
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

    # ---- 3. queue for the single elevated pass ---------------------------
    # Deferred, not run here: the Font stage also needs admin, and running both
    # immediately would mean two UAC prompts. Both are flushed together later.
    foreach ($p in $needsAdmin) {
        Add-ElevatedAction -Label $p.Name -Command @"
winget install --id $($p.Id) --exact --silent ``
    --accept-package-agreements --accept-source-agreements --disable-interactivity
"@
        $script:PendingVerify += $p
    }
}

function Invoke-ElevatedQueue {
    # Everything that needs admin -- winget machine-scope installs and the
    # system-wide font install -- is collected first and run here in one child
    # process, so the user sees exactly one UAC prompt for the whole run.
    if (-not $script:ElevatedActions.Count) { return }

    $names = ($script:ElevatedActions | ForEach-Object { $_.Label }) -join ', '
    $body  = ($script:ElevatedActions | ForEach-Object {
        "Write-Host '--- $($_.Label)'`n$($_.Command)"
    }) -join "`n"

    Write-Host ''
    Write-Step 'Elevation'

    if (Test-IsAdmin) {
        Write-Info "already elevated; running: $names"
        if ($PSCmdlet.ShouldProcess($names, 'run elevated actions')) {
            Invoke-Expression $body
        }
        $script:ElevatedActions.Clear()
        return
    }

    if ($NoElevate) {
        Write-Warn2 "-NoElevate set; these need admin and were skipped: $names"
        foreach ($a in $script:ElevatedActions) { Add-Result $a.Label 'skipped' 'needs admin' }
        $script:ElevatedActions.Clear()
        return
    }

    Write-Warn2 "These require administrator rights: $names"
    Write-Warn2 'You will get ONE UAC prompt covering all of them.'

    if (-not $Yes -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        $answer = Read-Host '    Elevate now? [Y/n]'
        if ($answer -and $answer -notmatch '^(y|yes)$') {
            Write-Warn2 'Declined.'
            foreach ($a in $script:ElevatedActions) { Add-Result $a.Label 'skipped' 'elevation declined' }
            $script:ElevatedActions.Clear()
            return
        }
    }
    if (-not $PSCmdlet.ShouldProcess($names, 'run elevated (one UAC prompt)')) { return }

    $log = Join-Path ([IO.Path]::GetTempPath()) "caelestia-elevated-$(Get-Date -Format yyyyMMddHHmmss).log"
    $inner = @"
`$ErrorActionPreference = 'Continue'
Start-Transcript -Path '$log' -Force | Out-Null
$body
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
        foreach ($a in $script:ElevatedActions) { Add-Result $a.Label 'skipped' 'elevation cancelled' }
    }
    $script:ElevatedActions.Clear()

    Update-PathFromRegistry
    foreach ($p in $script:PendingVerify) {
        if (& $p.Test) {
            Add-Result $p.Name 'installed' 'elevated'
        } else {
            Add-Result $p.Name 'failed' 'still missing after elevated install'
        }
    }
    $script:PendingVerify = @()
}

# ================================================================ nerd font
function Test-FontInstalledForAllUsers {
    # GDI (InstalledFontCollection) reports per-user fonts too, so it is NOT a
    # valid check here -- see the comment in Install-NerdFont. Ask HKLM instead.
    param([string]$FilePrefix)
    $hklm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $props = (Get-ItemProperty $hklm -ErrorAction Ignore)
    if (-not $props) { return $false }
    [bool]($props.PSObject.Properties.Name | Where-Object { $_ -match [regex]::Escape($FilePrefix) })
}

function Remove-PerUserFontInstall {
    # A per-user copy left over from an earlier run shadows nothing useful and
    # only confuses diagnosis, since it is visible to GDI but not to Terminal.
    param([string]$FilePrefix)
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $removed = 0

    if (Test-Path $regPath) {
        (Get-ItemProperty $regPath).PSObject.Properties |
            Where-Object { $_.Name -match [regex]::Escape($FilePrefix) } |
            ForEach-Object {
                Remove-ItemProperty -Path $regPath -Name $_.Name -ErrorAction Ignore
                $removed++
            }
    }
    Get-ChildItem $fontDir -Filter "$FilePrefix*" -ErrorAction Ignore |
        Remove-Item -Force -ErrorAction Ignore

    if ($removed) { Write-Ok "removed $removed stale per-user font entr(ies)" }
}

function Install-NerdFont {
    Write-Step "Font - $NerdFontFamily"

    # MUST be a system-wide install. Windows Terminal is a packaged (MSIX) app
    # and cannot see fonts installed for the current user only -- it silently
    # falls back to another family, which looks exactly like "the theme did not
    # apply", with no error anywhere. Unpackaged apps DO see per-user fonts, so
    # checking with any normal tool makes it look installed. Hence:
    # C:\Windows\Fonts + HKLM, which needs admin.
    if (Test-FontInstalledForAllUsers -FilePrefix $FontFilePrefix) {
        Write-Ok 'already installed for all users'
        Add-Result $NerdFontFamily 'present'
        return
    }
    if (-not $PSCmdlet.ShouldProcess($NerdFontFamily, 'download and install for all users')) { return }

    Remove-PerUserFontInstall -FilePrefix $FontFilePrefix

    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$NerdFontVersion/$($Cfg.NerdFont.Archive)"
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
        Remove-Item $zip -Force -ErrorAction SilentlyContinue

        $wanted = $FontStyles | ForEach-Object { "$FontFilePrefix-$_.ttf" }
        $files = Get-ChildItem $tmp -Filter '*.ttf' -Recurse |
                 Where-Object { $wanted -contains $_.Name }

        if (-not $files) {
            throw "no matching TTFs in archive (expected $FontFilePrefix-Regular.ttf)"
        }

        # Stage just the four faces we want, then hand the copy+register to the
        # shared elevated pass. $tmp is intentionally NOT cleaned up here -- the
        # elevated child still needs it, and removes it when done.
        $stage = Join-Path $tmp 'staged'
        New-Item -ItemType Directory -Force -Path $stage | Out-Null
        foreach ($f in $files) { Copy-Item $f.FullName (Join-Path $stage $f.Name) -Force }
        Write-Ok "staged $($files.Count) faces for system-wide install"

        Add-ElevatedAction -Label "$NerdFontFamily (system font)" -Command @"
`$fontDir = Join-Path `$env:WINDIR 'Fonts'
`$reg = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
Get-ChildItem '$stage' -Filter '*.ttf' | ForEach-Object {
    Copy-Item `$_.FullName (Join-Path `$fontDir `$_.Name) -Force
    # For fonts inside %WINDIR%\Fonts the value is the bare filename.
    New-ItemProperty -Path `$reg -Name "`$(`$_.BaseName) (TrueType)" ``
        -Value `$_.Name -PropertyType String -Force | Out-Null
    Write-Host "  installed `$(`$_.Name)"
}
Remove-Item '$tmp' -Recurse -Force -ErrorAction SilentlyContinue
"@
        Add-Result $NerdFontFamily 'installed' 'system-wide (queued for elevation)'
    }
    catch {
        Write-Bad "font install failed: $($_.Exception.Message.Trim())"
        Write-Warn2 'JetBrainsMono NF will be used as fallback.'
        Add-Result $NerdFontFamily 'failed' $_.Exception.Message.Trim()
        Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-FontFace {
    # Never point a config at a family that is not installed.
    $families = Get-InstalledFontFamilies
    # Only offer the Nerd Font if it is installed for ALL users. A per-user
    # install shows up in GDI here but is invisible to Windows Terminal, so
    # trusting GDI alone writes a font name Terminal cannot resolve.
    if (($families -contains $NerdFontFamily) -and
        -not (Test-FontInstalledForAllUsers -FilePrefix $FontFilePrefix)) {
        Write-Warn2 "$NerdFontFamily is per-user only; Windows Terminal cannot see it"
        $families = $families | Where-Object { $_ -ne $NerdFontFamily }
    }

    # These are GDI family names as reported by InstalledFontCollection, which
    # differ from the TTF filenames. Verify with:
    #   [Drawing.Text.InstalledFontCollection]::new().Families.Name
    foreach ($c in @($NerdFontFamily, 'JetBrainsMono NF', 'JetBrainsMono NFM',
                     'Cascadia Mono', 'Consolas')) {
        if ($families -contains $c) { return $c }
    }
    return 'Consolas'
}

function Test-TerminalSettings {
    <#
        Windows Terminal validates settings.json against a schema, and ONE bad
        enum value rejects the entire file -- Terminal then silently reverts to
        stock defaults behind a single dialog. ConvertFrom-Json succeeding proves
        only that the JSON is well-formed, not that Terminal will accept it, so
        it is not sufficient verification on its own.

        This checks every enum-valued setting the installer writes. Extend the
        table when adding a new one.
    #>
    param($Json)

    $enums = @{
        'profiles.defaults.cursorShape'      = @('bar','vintage','underscore','filledBox','emptyBox','doubleUnderscore')
        'profiles.defaults.antialiasingMode' = @('grayscale','cleartype','aliased')
        'profiles.defaults.scrollbarState'   = @('visible','hidden','always')
        'profiles.defaults.bellStyle'        = @('audible','window','taskbar','all','none')
        'profiles.defaults.adjustIndistinguishableColors' = @('never','indexed','always')
        'tabWidthMode'                       = @('equal','titleLength','compact')
        'launchMode'                         = @('default','maximized','focus','fullscreen','maximizedFocus')
    }
    $actionEnums = @{
        'globalSummon.monitor'   = @('any','toCurrent','toMouse')
        'moveFocus.direction'    = @('left','right','up','down','previous','nextInOrder','previousInOrder','first','parent','child')
        'splitPane.split'        = @('up','down','left','right','auto')
        'splitPane.splitMode'    = @('duplicate')
        'scrollToMark.direction' = @('previous','next','first','last')
    }

    $bad = @()

    foreach ($path in $enums.Keys) {
        $node = $Json
        foreach ($part in $path.Split('.')) {
            if ($null -eq $node -or $node.PSObject.Properties.Name -notcontains $part) { $node = $null; break }
            $node = $node.$part
        }
        if ($null -ne $node -and $enums[$path] -notcontains $node) {
            $bad += "$path = '$node' (allowed: $($enums[$path] -join ' | '))"
        }
    }

    if ($Json.PSObject.Properties.Name -contains 'keybindings') {
        foreach ($kb in $Json.keybindings) {
            if ($kb.PSObject.Properties.Name -notcontains 'command') { continue }
            $c = $kb.command
            if ($c -is [string]) { continue }
            if ($c.PSObject.Properties.Name -notcontains 'action') { continue }
            foreach ($key in $actionEnums.Keys) {
                $act, $prop = $key.Split('.')
                if ($c.action -ne $act) { continue }
                if ($c.PSObject.Properties.Name -notcontains $prop) { continue }
                if ($actionEnums[$key] -notcontains $c.$prop) {
                    $bad += "keybinding '$($kb.keys)' $key = '$($c.$prop)' (allowed: $($actionEnums[$key] -join ' | '))"
                }
            }
        }
    }

    # A theme reference that names no defined theme is also rejected.
    if ($Json.PSObject.Properties.Name -contains 'theme') {
        $builtin = @('system','light','dark')
        $defined = @()
        if ($Json.PSObject.Properties.Name -contains 'themes' -and $Json.themes) {
            $defined = @($Json.themes.name)
        }
        if ($Json.theme -notin ($builtin + $defined)) {
            $bad += "theme = '$($Json.theme)' but no such theme is defined"
        }
    }

    return $bad
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
            $json = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            # Round-trip the untouched object so the comparison below is against
            # our own serialiser, not the file's hand-formatted whitespace.
            $before = $json | ConvertTo-Json -Depth 32

            # -- colour scheme ---------------------------------------------
            $scheme = [ordered]@{
                name                = $Theme.Name
                background          = $ActivePalette.Background
                foreground          = $ActivePalette.Foreground
                cursorColor         = $ActivePalette.Cursor
                selectionBackground = $ActivePalette.SelectionBackground
                black        = $ActivePalette.Black;        red          = $ActivePalette.Red
                green        = $ActivePalette.Green;        yellow       = $ActivePalette.Yellow
                blue         = $ActivePalette.Blue;         purple       = $ActivePalette.Purple
                cyan         = $ActivePalette.Cyan;         white        = $ActivePalette.White
                brightBlack  = $ActivePalette.BrightBlack;  brightRed    = $ActivePalette.BrightRed
                brightGreen  = $ActivePalette.BrightGreen;  brightYellow = $ActivePalette.BrightYellow
                brightBlue   = $ActivePalette.BrightBlue;   brightPurple = $ActivePalette.BrightPurple
                brightCyan   = $ActivePalette.BrightCyan;   brightWhite  = $ActivePalette.BrightWhite
            }
            $schemes = @()
            if ($json.PSObject.Properties.Name -contains 'schemes' -and $json.schemes) {
                $schemes = @($json.schemes | Where-Object { $_.name -ne $Theme.Name })
            }
            Set-JsonProperty $json 'schemes' (@($schemes) + [pscustomobject]$scheme)

            # -- window theme ----------------------------------------------
            $wtTheme = [pscustomobject]@{
                name   = 'caelestia'
                # Terminal wants #rrggbbaa here, so the scheme's #rrggbb gains FF.
                tab    = [pscustomobject]@{ background = "$($ActivePalette.TabBackground)FF" }
                tabRow = [pscustomobject]@{
                    background          = "$($ActivePalette.TabRowBackground)FF"
                    unfocusedBackground = "$($ActivePalette.TabRowUnfocused)FF"
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

            $lig = if ($Cfg.Font.Ligatures) { 1 } else { 0 }
            Set-JsonProperty $d 'colorScheme' $Theme.Name
            Set-JsonProperty $d 'font' ([pscustomobject]@{
                face     = $face
                size     = $Cfg.Font.Size
                weight   = $Cfg.Font.Weight
                features = [pscustomobject]@{ calt = $lig; liga = $lig }
            })
            # Acrylic is the only blur Windows exposes; radius is not tunable.
            Set-JsonProperty $d 'useAcrylic'       ([bool]$Cfg.Window.Acrylic)
            Set-JsonProperty $d 'opacity'          ([int]($Cfg.Window.Opacity * 100))
            Set-JsonProperty $d 'padding'          $Cfg.Window.Padding
            Set-JsonProperty $d 'cursorShape'      $Cfg.Terminal.CursorShape
            Set-JsonProperty $d 'antialiasingMode' $Cfg.Terminal.AntialiasingMode
            Set-JsonProperty $d 'scrollbarState'   $Cfg.Terminal.ScrollbarState
            Set-JsonProperty $d 'bellStyle'        $Cfg.Terminal.BellStyle
            Set-JsonProperty $d 'historySize'      ([int]$Cfg.Terminal.ScrollbackLines)

            # Nudges palette colours that would be unreadable against the
            # background. 'indexed' touches only the 16 ANSI slots and leaves
            # 24-bit colour from programs alone.
            Set-JsonProperty $d 'adjustIndistinguishableColors' $Cfg.Terminal.AdjustIndistinguishableColors

            # Shell integration marks: a tick per prompt on the scrollbar, and
            # ctrl+up/down to jump between commands. Costs nothing to render.
            Set-JsonProperty $d 'autoMarkPrompts'      ([bool]$Cfg.Terminal.AutoMarkPrompts)
            Set-JsonProperty $d 'showMarksOnScrollbar' ([bool]$Cfg.Terminal.ShowMarksOnScrollbar)

            # Inactive panes flatten and dim so the focused one reads as focused.
            Set-JsonProperty $d 'unfocusedAppearance' ([pscustomobject]@{
                opacity     = [int]$Cfg.Window.UnfocusedOpacity
                cursorColor = $ActivePalette.PromptOutline
            })

            # Deliberately NOT set: experimental.pixelShaderPath and
            # backgroundImage. Both are per-frame GPU work for pure decoration
            # and measurably cost render time.

            # -- global window settings ------------------------------------
            # showTabsInTitlebar + alwaysShowTabs are what actually shrink the
            # top bar; see "Minimising the top bar" in the README.
            Set-JsonProperty $json 'showTabsInTitlebar'          ([bool]$Cfg.Window.ShowTabsInTitlebar)
            Set-JsonProperty $json 'alwaysShowTabs'              ([bool]$Cfg.Window.AlwaysShowTabs)
            Set-JsonProperty $json 'showTerminalTitleInTitlebar' ([bool]$Cfg.Window.ShowTitleInTitlebar)
            Set-JsonProperty $json 'tabWidthMode'       $Cfg.Window.TabWidthMode
            Set-JsonProperty $json 'useAcrylicInTabRow' ([bool]$Cfg.Window.AcrylicInTabRow)
            Set-JsonProperty $json 'launchMode'         $Cfg.Window.LaunchMode
            Set-JsonProperty $json 'centerOnLaunch'     ([bool]$Cfg.Window.CenterOnLaunch)
            Set-JsonProperty $json 'snapToGridOnResize' ([bool]$Cfg.Window.SnapToGridOnResize)
            Set-JsonProperty $json 'focusFollowMouse'   ([bool]$Cfg.Window.FocusFollowMouse)

            # -- keybindings -----------------------------------------------
            # Merged by key chord: any existing binding for the same keys is
            # replaced, everything else the user has set is left alone. These
            # use the legacy `command` form, which Terminal still honours
            # alongside the newer `id` entries already in the file.
            # A chord set to $null in config.psd1 is skipped entirely.
            if ($Cfg.Keybindings.Enabled) {
                $k = $Cfg.Keybindings
                $wanted = @(
                    @{ Key = $k.ScrollToPreviousMark; Cmd = [pscustomobject]@{ action = 'scrollToMark'; direction = 'previous' } }
                    @{ Key = $k.ScrollToNextMark;     Cmd = [pscustomobject]@{ action = 'scrollToMark'; direction = 'next' } }
                    @{ Key = $k.SplitDown;  Cmd = [pscustomobject]@{ action = 'splitPane'; split = 'down';  splitMode = 'duplicate' } }
                    @{ Key = $k.SplitRight; Cmd = [pscustomobject]@{ action = 'splitPane'; split = 'right'; splitMode = 'duplicate' } }
                    @{ Key = $k.FocusLeft;  Cmd = [pscustomobject]@{ action = 'moveFocus'; direction = 'left' } }
                    @{ Key = $k.FocusRight; Cmd = [pscustomobject]@{ action = 'moveFocus'; direction = 'right' } }
                    @{ Key = $k.FocusUp;    Cmd = [pscustomobject]@{ action = 'moveFocus'; direction = 'up' } }
                    @{ Key = $k.FocusDown;  Cmd = [pscustomobject]@{ action = 'moveFocus'; direction = 'down' } }
                    @{ Key = $k.ZoomPane;        Cmd = 'togglePaneZoom' }
                    @{ Key = $k.ToggleFocusMode; Cmd = 'toggleFocusMode' }
                    # Quake dropdown. monitor must be any | toCurrent | toMouse;
                    # an invalid value rejects the ENTIRE settings file and drops
                    # Terminal to stock defaults behind one dialog.
                    @{ Key = $k.QuakeSummon; Cmd = [pscustomobject]@{
                        action = 'globalSummon'; name = '_quake'
                        dropdownDuration = [int]$k.QuakeDropdownMs
                        toggleVisibility = $true; monitor = $k.QuakeMonitor } }
                )
                $caelestiaKeys = @(
                    $wanted | Where-Object { $_.Key } |
                        ForEach-Object { [pscustomobject]@{ keys = $_.Key; command = $_.Cmd } }
                )
                $existing = @()
                if ($json.PSObject.Properties.Name -contains 'keybindings' -and $json.keybindings) {
                    $mine = @($caelestiaKeys.keys)
                    $existing = @($json.keybindings | Where-Object {
                        -not ($_.PSObject.Properties.Name -contains 'keys' -and $mine -contains $_.keys)
                    })
                }
                Set-JsonProperty $json 'keybindings' (@($existing) + $caelestiaKeys)
            }

            # -- default profile -------------------------------------------
            # Windows Terminal keeps Windows PowerShell 5.1 as the default even
            # after PS7 is installed, so none of the PS7-only behaviour (predictive
            # IntelliSense, faster startup) is ever seen. Point it at PowerShell 7
            # when Terminal has generated a profile for it. -KeepDefaultProfile
            # opts out.
            if ($Cfg.Terminal.UsePowerShell7AsDefault -and -not $KeepDefaultProfile) {
                $ps7 = $json.profiles.list | Where-Object {
                    $_.PSObject.Properties.Name -contains 'source' -and
                    $_.source -eq 'Windows.Terminal.PowershellCore'
                } | Select-Object -First 1

                if ($ps7 -and $json.defaultProfile -ne $ps7.guid) {
                    Set-JsonProperty $json 'defaultProfile' $ps7.guid
                    Write-Ok "default profile -> $($ps7.name) (PowerShell 7)"
                } elseif (-not $ps7) {
                    Write-Warn2 'no PowerShell 7 profile found; leaving default as-is'
                }
            }

            # Validate BEFORE writing. One bad enum makes Terminal reject the
            # entire file and silently revert to stock defaults, so refusing to
            # write beats leaving a broken settings.json behind.
            $problems = Test-TerminalSettings -Json $json
            if ($problems) {
                Write-Bad "refusing to write $label - invalid settings:"
                $problems | ForEach-Object { Write-Bad "    $_" }
                Add-Result "Windows Terminal ($label)" 'failed' 'schema validation'
                continue
            }

            $after = $json | ConvertTo-Json -Depth 32
            if ($before -eq $after) {
                Write-Ok "already themed (font: $face)"
                Add-Result "Windows Terminal ($label)" 'present' "font: $face"
            } else {
                Backup-File $settingsPath
                $after | Set-Content $settingsPath -Encoding UTF8
                Write-Ok "themed $label (font: $face)"
                Add-Result "Windows Terminal ($label)" 'done' "font: $face"
            }
        }
        catch {
            Write-Bad "failed on $label`: $($_.Exception.Message.Trim())"
            Add-Result "Windows Terminal ($label)" 'failed' $_.Exception.Message.Trim()
        }
    }
}

# ================================================================ starship
function Deploy-Starship {
    Write-Step 'Starship'
    $src  = Join-Path $Root 'config\starship\starship.toml'
    $dir  = Join-Path $env:USERPROFILE '.config'
    $dest = Join-Path $dir 'starship.toml'

    if (-not $PSCmdlet.ShouldProcess($dest, 'write starship.toml')) { return }

    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    # The prompt palette is generated from the active scheme rather than copied,
    # so switching Active in the psd1 restyles the prompt too instead of leaving
    # it on the previous scheme's colours.
    $toml = [IO.File]::ReadAllText($src)
    $palette = @"
[palettes.caelestia]
m3_primary              = "$($ActivePalette.PromptPrimary)"
m3_on_primary           = "$($ActivePalette.PromptOnPrimary)"
m3_primary_container    = "$($ActivePalette.PromptContainer)"
m3_on_primary_container = "$($ActivePalette.PromptOnContainer)"
m3_secondary            = "$($ActivePalette.PromptSecondary)"
m3_tertiary             = "$($ActivePalette.PromptTertiary)"
m3_on_tertiary          = "$($ActivePalette.PromptOnPrimary)"
m3_error                = "$($ActivePalette.PromptError)"
m3_success              = "$($ActivePalette.PromptSuccess)"
m3_surface              = "$($ActivePalette.PromptSurface)"
m3_surface_low          = "$($ActivePalette.TabRowUnfocused)"
m3_surface_container    = "$($ActivePalette.TabBackground)"
m3_surface_high         = "$($ActivePalette.PromptSurfaceHigh)"
m3_on_surface           = "$($ActivePalette.Foreground)"
m3_outline              = "$($ActivePalette.PromptOutline)"

"@
    # Replace the whole palette table, up to the next table header.
    $pattern = '(?ms)^\[palettes\.caelestia\]\r?\n.*?(?=^\[)'
    if ($toml -notmatch $pattern) {
        throw 'starship.toml: [palettes.caelestia] table not found; cannot inject scheme'
    }
    $toml = [regex]::Replace($toml, $pattern, { $palette })

    $changed = $false
    $current = if (Test-Path $dest) { [IO.File]::ReadAllText($dest) } else { '' }
    if ($current -ne $toml) {
        Backup-File $dest
        [IO.File]::WriteAllText($dest, $toml, (New-Object Text.UTF8Encoding $false))
        Write-Ok "-> $dest  (palette: $ActivePaletteName)"
        $changed = $true
    } else {
        Write-Ok 'already current'
    }

    if ([Environment]::GetEnvironmentVariable('STARSHIP_CONFIG', 'User') -ne $dest) {
        [Environment]::SetEnvironmentVariable('STARSHIP_CONFIG', $dest, 'User')
        Write-Ok 'STARSHIP_CONFIG set'
        $changed = $true
    }
    Add-Result 'Starship config' $(if ($changed) { 'done' } else { 'present' }) $dest
}

# ================================================================= profile
function Write-SchemeColors {
    # PSReadLine's syntax colours live in a .ps1 that is copied verbatim, so they
    # cannot be templated the way starship.toml is. Emit them as data instead and
    # let the profile read it, keeping the scheme the single source of truth.
    $dir  = Join-Path $env:LOCALAPPDATA 'caelestia'
    $dest = Join-Path $dir 'colors.psd1'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $body = @"
# GENERATED by install.ps1 from config.psd1 (scheme: $ActivePaletteName).
# Edits here are overwritten on the next run -- change config.psd1 instead.
@{
    # Shell toggles, read by the profile.
    Starship              = `$$($Cfg.Shell.Starship)
    Fastfetch             = `$$($Cfg.Shell.Fastfetch)
    Predictions           = `$$($Cfg.Shell.Predictions)
    HistorySearchOnArrows = `$$($Cfg.Shell.HistorySearchOnArrows)

    Command          = '$($ActivePalette.PromptPrimary)'
    Parameter        = '$($ActivePalette.PromptSecondary)'
    Operator         = '$($ActivePalette.PromptTertiary)'
    Variable         = '$($ActivePalette.BrightCyan)'
    String           = '$($ActivePalette.Green)'
    Number           = '$($ActivePalette.BrightPurple)'
    Type             = '$($ActivePalette.Cyan)'
    Comment          = '$($ActivePalette.PromptOutline)'
    Keyword          = '$($ActivePalette.Purple)'
    Error            = '$($ActivePalette.PromptError)'
    InlinePrediction = '$($ActivePalette.BrightBlack)'
    ListPrediction   = '$($ActivePalette.PromptOutline)'
    SelectionRgb     = '$($ActivePalette.SelectionBackground)'
}
"@
    [IO.File]::WriteAllText($dest, $body, (New-Object Text.UTF8Encoding $false))
    Write-Ok "-> $dest  (scheme: $ActivePaletteName)"
}

function Deploy-Profile {
    Write-Step 'PowerShell profile'
    Write-SchemeColors
    $src = Join-Path $Root 'config\powershell\profile.ps1'

    $targets = @(
        Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
        Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    )
    # Documents is often redirected to OneDrive; honour the real profile path.
    if ($PROFILE.CurrentUserCurrentHost -and $targets -notcontains $PROFILE.CurrentUserCurrentHost) {
        $targets += $PROFILE.CurrentUserCurrentHost
    }

    $changed = $false
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
        $changed = $true
    }
    Add-Result 'PowerShell profile' $(if ($changed) { 'done' } else { 'present' })

    # conda's own prompt prefix fights the starship theme.
    if ($Cfg.Shell.DisableCondaPrompt -and (Get-Command conda -ErrorAction SilentlyContinue)) {
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

    # Packages and Font both queue admin work. Flush once, after both have had
    # their say, so the run costs a single UAC prompt -- and before Terminal,
    # which needs to know the final font name.
    $lastQueueingStage = if (Test-Stage 'Font') { 'Font' } else { 'Packages' }
    if ($name -eq $lastQueueingStage) {
        try {
            Invoke-ElevatedQueue

            # Load the newly installed faces so this session (and anything
            # launched from it) resolves them without a sign-out.
            $sysFonts = Get-ChildItem (Join-Path $env:WINDIR 'Fonts') `
                -Filter "$FontFilePrefix*.ttf" -ErrorAction Ignore
            if ($sysFonts) {
                [void](Register-FontWithSession -Paths $sysFonts.FullName)
            }
        } catch {
            Write-Bad "elevation stage failed: $($_.Exception.Message.Trim())"
        }
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
