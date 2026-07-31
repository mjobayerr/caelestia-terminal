@{
    # ===================================================================
    # Everything configurable lives here. install.ps1 reads this file and
    # nothing else -- no colour, size, keybinding or toggle is hardcoded in
    # the installer.
    #
    # Apply changes with:
    #   .\install.ps1 -SkipPackages
    #
    # Any key you delete falls back to the default in install.ps1's
    # $Defaults table, so a trimmed-down config file is still valid.
    # ===================================================================

    # Which scheme in Schemes below to use.
    Active = 'overdrive'

    # ------------------------------------------------------------------
    # Window chrome. See "Minimising the top bar" in the README.
    # ------------------------------------------------------------------
    Window = @{
        # 0.0 = invisible, 1.0 = opaque. Acrylic blur only reads as blur
        # below about 0.6 against a dark background.
        Opacity = 0.55
        Acrylic = $true          # $false = plain transparency, no blur

        Padding = '16,12,16,12'  # left,top,right,bottom

        # --- top bar ---
        # ShowTabsInTitlebar $true puts tabs INTO the title bar: one row
        # instead of two. $false gives a separate tab strip below a normal
        # Windows title bar, which is the tallest option.
        ShowTabsInTitlebar = $true
        # AlwaysShowTabs $false hides the tab strip entirely while only one
        # tab is open, leaving just the thin title bar.
        AlwaysShowTabs = $false
        # Hides the "Windows PowerShell" text, leaving the bar emptier.
        ShowTitleInTitlebar = $false
        TabWidthMode = 'compact'      # equal | titleLength | compact
        AcrylicInTabRow = $true

        # 'focus' launches with NO title bar and NO tabs at all -- the most
        # minimal it gets. Toggle at runtime with Keys.ToggleFocusMode.
        LaunchMode = 'default'        # default | maximized | focus | fullscreen | maximizedFocus

        CenterOnLaunch     = $true
        SnapToGridOnResize = $true
        FocusFollowMouse   = $false

        # Inactive panes flatten and dim so the focused one reads as focused.
        UnfocusedOpacity = 85
    }

    # ------------------------------------------------------------------
    # Terminal behaviour
    # ------------------------------------------------------------------
    Terminal = @{
        CursorShape      = 'bar'        # bar | vintage | underscore | filledBox | emptyBox | doubleUnderscore
        AntialiasingMode = 'grayscale'  # grayscale | cleartype | aliased
        ScrollbarState   = 'hidden'     # visible | hidden | always
        BellStyle        = 'none'       # audible | window | taskbar | all | none
        ScrollbackLines  = 10000

        # Nudges palette colours that would be unreadable against the
        # background. 'indexed' touches only the 16 ANSI slots and leaves
        # 24-bit colour from programs alone.
        AdjustIndistinguishableColors = 'indexed'  # never | indexed | always

        # A tick on the scrollbar per prompt, and Keys.ScrollTo* to jump.
        AutoMarkPrompts      = $true
        ShowMarksOnScrollbar = $true

        # Point Terminal's defaultProfile at PowerShell 7. Terminal keeps
        # Windows PowerShell 5.1 as default even after PS7 is installed.
        UsePowerShell7AsDefault = $true
    }

    # ------------------------------------------------------------------
    # Keybindings. Set any value to $null to leave that chord alone.
    # Existing bindings you have set yourself are never touched unless
    # they use the same chord.
    # ------------------------------------------------------------------
    Keybindings = @{
        Enabled = $true

        ScrollToPreviousMark = 'ctrl+up'
        ScrollToNextMark     = 'ctrl+down'

        SplitDown  = 'alt+shift+minus'
        SplitRight = 'alt+shift+plus'
        FocusLeft  = 'alt+left'
        FocusRight = 'alt+right'
        FocusUp    = 'alt+up'
        FocusDown  = 'alt+down'
        ZoomPane   = 'ctrl+shift+z'

        # Hides/shows the title bar and tabs at runtime.
        ToggleFocusMode = 'alt+shift+f'

        # Quake dropdown: slides a terminal down from the top of the screen
        # from anywhere. Needs Terminal already running. win+sc(41) is the
        # backtick key by scan code, which is layout-independent.
        QuakeSummon      = 'win+sc(41)'
        QuakeDropdownMs  = 150
        QuakeMonitor     = 'toMouse'   # any | toCurrent | toMouse
    }

    # ------------------------------------------------------------------
    # Font. Face is the GDI family name -- 'CaskaydiaCove NF', NOT the
    # 'CaskaydiaCoveNerdFont' spelling used for the TTF filenames. The
    # installer resolves this against installed families and falls back to
    # JetBrainsMono NF, then Consolas, if it is missing.
    # ------------------------------------------------------------------
    Font = @{
        Face      = 'CaskaydiaCove NF'
        Size      = 12
        Weight    = 'normal'
        Ligatures = $true
    }

    # ------------------------------------------------------------------
    # Shell / prompt
    # ------------------------------------------------------------------
    Shell = @{
        Starship    = $true   # rounded pill prompt
        Fastfetch   = $true   # system summary on new interactive sessions
        Predictions = $true   # fish-style inline autosuggestion (PSReadLine 2.2+)
        HistorySearchOnArrows = $true
        DisableCondaPrompt    = $true   # conda's (base) prefix fights the theme
    }

    # ------------------------------------------------------------------
    # Nerd font download. Only used when the font is not already installed
    # system-wide.
    # ------------------------------------------------------------------
    NerdFont = @{
        Version    = 'v3.4.0'
        Archive    = 'CascadiaCode.zip'
        FilePrefix = 'CaskaydiaCoveNerdFont'
        Family     = 'CaskaydiaCove NF'
        Styles     = @('Regular', 'Bold', 'Italic', 'BoldItalic')
    }

    # ==================================================================
    # Schemes. Copy a block to add your own; every key is required and
    # must be #rrggbb. The installer validates before writing anything.
    #
    # Active drives THREE consumers -- Windows Terminal, the starship
    # prompt palette, and PSReadLine syntax colours -- so changing it
    # restyles all of them.
    # ==================================================================
    Schemes = @{

        # High-contrast dark, cyberpunk / anime action. Cool near-black
        # base, saturated primaries, neon orange cursor. Every hue is
        # separated far enough that the 16 ANSI slots carry real meaning.
        overdrive = @{
            Background          = '#0d1017'
            Foreground          = '#c8d3f5'
            Cursor              = '#ff5f1f'
            SelectionBackground = '#2a3352'

            Black   = '#1b2030'; Red    = '#ff3d5a'; Green = '#3ddc84'; Yellow = '#ffb340'
            Blue    = '#4d9fff'; Purple = '#bd6bff'; Cyan  = '#22e0d0'; White  = '#aab4d0'

            BrightBlack  = '#4a5268'; BrightRed    = '#ff6b81'
            BrightGreen  = '#6ef2a6'; BrightYellow = '#ffd166'
            BrightBlue   = '#7cc0ff'; BrightPurple = '#d99bff'
            BrightCyan   = '#5df2e4'; BrightWhite  = '#eef2ff'

            TabBackground    = '#161b28'
            TabRowBackground = '#0a0d13'
            TabRowUnfocused  = '#0d1017'

            PromptPrimary     = '#4d9fff'
            PromptOnPrimary   = '#08101f'
            PromptContainer   = '#233a5e'
            PromptOnContainer = '#cfe3ff'
            PromptSecondary   = '#22e0d0'
            PromptTertiary    = '#ffb340'
            PromptError       = '#ff3d5a'
            PromptSuccess     = '#3ddc84'
            PromptSurface     = '#0d1017'
            PromptSurfaceHigh = '#1c2333'
            PromptOutline     = '#6b7694'
        }

        # Upstream caelestia, with its four unusable ANSI slots repaired
        # using upstream's own m3success / m3tertiary roles. Only Cyan and
        # BrightBlue are invented -- upstream has no cool accent to borrow.
        caelestia = @{
            Background          = '#191114'   # m3surface
            Foreground          = '#efdfe2'   # m3onSurface
            Cursor              = '#ffb0ca'   # m3primary
            SelectionBackground = '#6f334a'   # m3primaryContainer

            Black   = '#353434'; Red    = '#ff4c8a'
            Green   = '#b5ccba'                # m3success  (was #ffbbb7 pink)
            Yellow  = '#f0bc95'                # m3tertiary (was #ffdedf near-white)
            Blue    = '#b3a2d5'; Purple = '#e98fb0'
            Cyan    = '#8fbfba'                # invented muted teal
            White   = '#eed1d2'

            BrightBlack  = '#b39e9e'; BrightRed    = '#ff80a3'
            BrightGreen  = '#cfe3d4'; BrightYellow = '#ffd9a8'
            BrightBlue   = '#c9bce8'; BrightPurple = '#f9a8c2'
            BrightCyan   = '#b8dbd6'; BrightWhite  = '#ffffff'

            TabBackground    = '#261d20'
            TabRowBackground = '#130c0e'
            TabRowUnfocused  = '#191114'

            PromptPrimary     = '#ffb0ca'
            PromptOnPrimary   = '#541d34'
            PromptContainer   = '#6f334a'
            PromptOnContainer = '#ffd9e3'
            PromptSecondary   = '#e2bdc7'
            PromptTertiary    = '#f0bc95'
            PromptError       = '#ffb4ab'
            PromptSuccess     = '#b5ccba'
            PromptSurface     = '#191114'
            PromptSurfaceHigh = '#31282a'
            PromptOutline     = '#9e8c91'
        }

        # term0..term15 exactly as upstream ships them. Kept for parity.
        # Upstream derives these from a pink wallpaper, so six of eight hues
        # land in one pink-to-peach band: Green #ffbbb7 is pink and matches
        # Yellow, Yellow #ffdedf and BrightYellow #fff1f0 sit within a few
        # percent of the foreground so warnings do not look like warnings,
        # and BrightBlue #dcbc93 is tan and collides with Cyan #ffba93.
        'caelestia-faithful' = @{
            Background          = '#191114'
            Foreground          = '#efdfe2'
            Cursor              = '#ffb0ca'
            SelectionBackground = '#6f334a'

            Black   = '#353434'; Red    = '#ff4c8a'; Green = '#ffbbb7'; Yellow = '#ffdedf'
            Blue    = '#b3a2d5'; Purple = '#e98fb0'; Cyan  = '#ffba93'; White  = '#eed1d2'

            BrightBlack  = '#b39e9e'; BrightRed    = '#ff80a3'
            BrightGreen  = '#ffd3d0'; BrightYellow = '#fff1f0'
            BrightBlue   = '#dcbc93'; BrightPurple = '#f9a8c2'
            BrightCyan   = '#ffd1c0'; BrightWhite  = '#ffffff'

            TabBackground    = '#261d20'
            TabRowBackground = '#130c0e'
            TabRowUnfocused  = '#191114'

            PromptPrimary     = '#ffb0ca'
            PromptOnPrimary   = '#541d34'
            PromptContainer   = '#6f334a'
            PromptOnContainer = '#ffd9e3'
            PromptSecondary   = '#e2bdc7'
            PromptTertiary    = '#f0bc95'
            PromptError       = '#ffb4ab'
            PromptSuccess     = '#b5ccba'
            PromptSurface     = '#191114'
            PromptSurfaceHigh = '#31282a'
            PromptOutline     = '#9e8c91'
        }
    }
}
