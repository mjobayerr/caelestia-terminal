# Caelestia PowerShell profile.
# Deployed by install.ps1 to both Windows PowerShell 5.1 and PowerShell 7.
# The goal here is the fish-like *feel* of the caelestia shell: inline
# autosuggestion, fuzzy history, and a prompt that renders instantly.

# Everything below is guarded on a real interactive console. `pwsh -Command ...`,
# CI, and any redirected/piped session must load this file silently -- PSReadLine
# throws "the console output doesn't support virtual terminal processing or it's
# redirected" if configured outside a real TTY, which would spam every script run.
$script:IsInteractiveConsole = $false
try {
    $script:IsInteractiveConsole =
        [Environment]::UserInteractive -and
        $Host.Name -eq 'ConsoleHost' -and
        -not [Console]::IsOutputRedirected -and
        -not [Console]::IsInputRedirected
} catch { }

function Resolve-Tool {
    # winget does not refresh PATH for already-running shells, so a freshly
    # installed tool is missing until the next sign-in. Fall back to the known
    # install locations rather than silently skipping the prompt.
    param([string]$Name, [string[]]$Candidates)

    # 'Ignore', not 'SilentlyContinue': the latter still appends to $Error, so
    # every new session would open with a phantom CommandNotFoundException.
    $cmd = Get-Command $Name -ErrorAction Ignore
    if ($cmd) { return $cmd.Source }
    foreach ($c in $Candidates) { if (Test-Path $c) { return $c } }
    return $null
}

# --------------------------------------------------------------- PSReadLine
if ($script:IsInteractiveConsole) {
    # Predictive IntelliSense is the closest thing to fish autosuggest. It needs
    # PSReadLine 2.2+, which ships with PS7 but NOT with Windows PowerShell 5.1.
    #
    # Use the module the host has ALREADY loaded. `Get-Module -ListAvailable`
    # walks every directory on $env:PSModulePath and costs ~40ms per session,
    # and a redundant Import-Module costs ~80ms more -- both pure waste in PS7,
    # where the console host loads PSReadLine before the profile even runs.
    $psrl = Get-Module PSReadLine
    if (-not $psrl) {
        Import-Module PSReadLine -ErrorAction Ignore
        $psrl = Get-Module PSReadLine
    }

    try {
        if ($psrl -and $psrl.Version -ge [version]'2.2.0') {
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin
            Set-PSReadLineOption -PredictionViewStyle ListView
        }
    } catch {
        # Older PSReadLine or a host that cannot do prediction: not fatal.
    }

    if (Get-Module PSReadLine) {
        try {
            Set-PSReadLineOption -EditMode Windows
            Set-PSReadLineOption -HistoryNoDuplicates
            Set-PSReadLineOption -HistorySearchCursorMovesToEnd

            # Caelestia palette applied to syntax highlighting.
            Set-PSReadLineOption -Colors @{
                Command          = '#ffb0ca'  # m3primary
                Parameter        = '#e2bdc7'  # m3secondary
                Operator         = '#f0bc95'  # m3tertiary
                Variable         = '#ffd1c0'  # term14
                String           = '#ffbbb7'  # term2
                Number           = '#b3a2d5'  # term4
                Type             = '#f9a8c2'  # term13
                Comment          = '#9e8c91'  # m3outline
                Keyword          = '#e98fb0'  # term5
                Error            = '#ffb4ab'  # m3error
                InlinePrediction = '#6f5b5f'
                ListPrediction   = '#9e8c91'
                Selection        = "$([char]27)[48;2;111;51;74m"
            }

            # Up/Down search history by what is already typed.
            Set-PSReadLineKeyHandler -Key UpArrow    -Function HistorySearchBackward
            Set-PSReadLineKeyHandler -Key DownArrow  -Function HistorySearchForward
            Set-PSReadLineKeyHandler -Key Tab        -Function MenuComplete

            # RightArrow must stay ForwardChar (the default). Binding it to
            # ForwardWord swallows the whole next word of the inline prediction
            # in one press, which is indistinguishable from DownArrow pulling in
            # the next history entry -- two keys appearing to do the same thing.
            # ForwardChar still accepts the entire suggestion when the cursor is
            # already at the end of the line, which is the fish behaviour we want.
            Set-PSReadLineKeyHandler -Key RightArrow -Function ForwardChar
            # Word-at-a-time acceptance keeps its own chord.
            Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function AcceptNextSuggestionWord
        } catch { }
    }
}

# ----------------------------------------------------------------- Starship
$starship = Resolve-Tool -Name 'starship' -Candidates @(
    "$env:ProgramFiles\starship\bin\starship.exe"
    "$env:LOCALAPPDATA\Programs\starship\bin\starship.exe"
)
if ($starship) {
    $cfg = Join-Path $env:USERPROFILE '.config\starship.toml'
    if (Test-Path $cfg) { $env:STARSHIP_CONFIG = $cfg }

    # `starship init powershell` spawns starship.exe and costs ~240ms -- by far
    # the most expensive thing in this profile, paid on every single new tab.
    # Its output only changes when starship itself is upgraded, so cache it and
    # dot-source the cache instead. Re-generated automatically when the binary
    # is newer than the cache.
    $cacheDir  = Join-Path $env:LOCALAPPDATA 'caelestia'
    $cacheFile = Join-Path $cacheDir 'starship-init.ps1'
    try {
        $stale = -not (Test-Path $cacheFile) -or
                 (Get-Item $starship).LastWriteTime -gt (Get-Item $cacheFile).LastWriteTime
        if ($stale) {
            if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
            & $starship init powershell --print-full-init | Set-Content $cacheFile -Encoding UTF8
        }
        . $cacheFile
    } catch {
        # Cache unusable (first run, read-only disk, upgrade mid-write): fall
        # back to the slow path rather than losing the prompt entirely.
        try { Invoke-Expression (& $starship init powershell) }
        catch { Write-Warning "starship init failed: $($_.Exception.Message)" }
    }
}

# -------------------------------------------------------------------- misc
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'  # let starship own the venv segment

Set-Alias ll Get-ChildItem
Set-Alias which Get-Command

function .. { Set-Location .. }
function ... { Set-Location ../.. }

# Greeting, caelestia style. Interactive sessions only, and never under an
# agent harness where the banner is just noise in the transcript.
if ($script:IsInteractiveConsole -and -not $env:CLAUDECODE) {
    $fastfetch = Resolve-Tool -Name 'fastfetch' -Candidates @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\fastfetch.exe"
    )
    if ($fastfetch) { & $fastfetch }
}
