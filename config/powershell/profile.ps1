# Caelestia PowerShell profile.
# Deployed by install.ps1 to both Windows PowerShell 5.1 and PowerShell 7.
# The goal here is the fish-like *feel* of the caelestia shell: inline
# autosuggestion, fuzzy history, and a prompt that renders instantly.

# --------------------------------------------------------------- PSReadLine
# Predictive IntelliSense is the closest thing to fish autosuggest. It needs
# PSReadLine 2.2+, which ships with PS7 but NOT with Windows PowerShell 5.1.
$psrl = Get-Module PSReadLine -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($psrl -and $psrl.Version -ge [version]'2.2.0') {
    Import-Module PSReadLine -MinimumVersion 2.2.0
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
}

if (Get-Module PSReadLine) {
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd

    # Caelestia palette applied to syntax highlighting.
    Set-PSReadLineOption -Colors @{
        Command                = '#ffb0ca'  # m3primary
        Parameter              = '#e2bdc7'  # m3secondary
        Operator               = '#f0bc95'  # m3tertiary
        Variable               = '#ffd1c0'  # term14
        String                 = '#ffbbb7'  # term2
        Number                 = '#b3a2d5'  # term4
        Type                   = '#f9a8c2'  # term13
        Comment                = '#9e8c91'  # m3outline
        Keyword                = '#e98fb0'  # term5
        Error                  = '#ffb4ab'  # m3error
        InlinePrediction       = '#6f5b5f'
        ListPrediction         = '#9e8c91'
        Selection              = "$([char]27)[48;2;111;51;74m"
    }

    # Up/Down search history by what is already typed.
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key RightArrow -Function ForwardWord
}

# ----------------------------------------------------------------- Starship
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $env:STARSHIP_CONFIG = Join-Path $env:USERPROFILE '.config\starship.toml'
    Invoke-Expression (& starship init powershell)
}

# -------------------------------------------------------------------- misc
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'  # let starship own the venv segment

Set-Alias ll Get-ChildItem
Set-Alias which Get-Command

function .. { Set-Location .. }
function ... { Set-Location ../.. }

# Greeting, caelestia style. Skipped in non-interactive/agent sessions.
if ($Host.UI.SupportsVirtualTerminal -and -not $env:CLAUDECODE -and (Get-Command fastfetch -ErrorAction SilentlyContinue)) {
    fastfetch
}
