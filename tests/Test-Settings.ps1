# Unit tests for Test-TerminalSettings in install.ps1.
#
# Why this exists: shipping monitor='toCursor' (valid JSON, invalid per Terminal's
# schema) made Windows Terminal reject the ENTIRE settings file and silently fall
# back to stock defaults behind one dialog. ConvertFrom-Json succeeding proves
# nothing about whether Terminal will accept the file.
#
# Run:  pwsh -NoProfile -File tests\Test-Settings.ps1
$installer = Join-Path (Split-Path -Parent $PSScriptRoot) 'install.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($installer, [ref]$null, [ref]$null)
$fn = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                     $args[0].Name -eq 'Test-TerminalSettings' }, $true) | Select-Object -First 1
Invoke-Expression $fn.Extent.Text

$pass = 0; $fail = 0
function Check($label, $obj, [switch]$ExpectBad) {
    $r = @(Test-TerminalSettings -Json $obj)
    $ok = if ($ExpectBad) { $r.Count -gt 0 } else { $r.Count -eq 0 }
    if ($ok) { $script:pass++ } else { $script:fail++ }
    "{0,-44} {1}" -f $label, $(if ($ok) { 'PASS' } else { 'FAIL' })
    if ($r) { $r | ForEach-Object { "      caught: $_" } }
}

# Minimal well-formed settings object, mirroring what the installer produces.
function New-Settings {
    [pscustomobject]@{
        theme  = 'caelestia'
        themes = @([pscustomobject]@{ name = 'caelestia' })
        tabWidthMode = 'compact'
        profiles = [pscustomobject]@{
            defaults = [pscustomobject]@{
                cursorShape = 'bar'; antialiasingMode = 'grayscale'
                scrollbarState = 'hidden'; bellStyle = 'none'
                adjustIndistinguishableColors = 'indexed'
            }
        }
        keybindings = @(
            [pscustomobject]@{ id = 'Terminal.CopyToClipboard'; keys = 'ctrl+c' }   # no command
            [pscustomobject]@{ keys = 'ctrl+shift+z'; command = 'togglePaneZoom' }  # string command
            [pscustomobject]@{ keys = 'alt+left';  command = [pscustomobject]@{ action='moveFocus'; direction='left' } }
            [pscustomobject]@{ keys = 'ctrl+up';   command = [pscustomobject]@{ action='scrollToMark'; direction='previous' } }
            [pscustomobject]@{ keys = 'alt+shift+plus'; command = [pscustomobject]@{ action='splitPane'; split='right'; splitMode='duplicate' } }
            [pscustomobject]@{ keys = 'win+sc(41)'; command = [pscustomobject]@{
                action='globalSummon'; name='_quake'; dropdownDuration=150; toggleVisibility=$true; monitor='toMouse' } }
        )
    }
}

Check 'clean settings' (New-Settings)

$s = New-Settings; ($s.keybindings | Where-Object { $_.keys -eq 'win+sc(41)' }).command.monitor = 'toCursor'
Check 'monitor=toCursor  <-- the shipped bug' $s -ExpectBad

$s = New-Settings; ($s.keybindings | Where-Object { $_.keys -eq 'alt+left' }).command.direction = 'sideways'
Check 'moveFocus direction=sideways' $s -ExpectBad

$s = New-Settings; ($s.keybindings | Where-Object { $_.keys -eq 'ctrl+up' }).command.direction = 'upwards'
Check 'scrollToMark direction=upwards' $s -ExpectBad

$s = New-Settings; ($s.keybindings | Where-Object { $_.keys -eq 'alt+shift+plus' }).command.split = 'sideways'
Check 'splitPane split=sideways' $s -ExpectBad

$s = New-Settings; $s.profiles.defaults.cursorShape = 'beam'
Check 'cursorShape=beam' $s -ExpectBad

$s = New-Settings; $s.profiles.defaults.adjustIndistinguishableColors = 'auto'
Check 'adjustIndistinguishableColors=auto' $s -ExpectBad

$s = New-Settings; $s.tabWidthMode = 'tiny'
Check 'tabWidthMode=tiny' $s -ExpectBad

$s = New-Settings; $s.theme = 'nope'
Check 'theme references undefined theme' $s -ExpectBad

$s = New-Settings; $s.theme = 'dark'
Check 'theme=dark (builtin, must be allowed)' $s

Write-Host ''
"$pass passed, $fail failed"
