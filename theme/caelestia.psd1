@{
    # Colour schemes - single source of truth for Windows Terminal, the starship
    # prompt and PSReadLine syntax highlighting. install.ps1 reads Active and
    # regenerates all three, so changing one word here restyles everything.
    #
    # Add a scheme by copying a block and keeping every key: the installer
    # validates that a scheme defines all of them before writing anything.

    Active = 'overdrive'

    Schemes = @{

        # ================================================================
        # overdrive - high-contrast dark scheme, cyberpunk / anime action.
        # Cool near-black base, saturated primaries, neon orange cursor.
        # Every hue is separated far enough that the 16 ANSI slots carry
        # real meaning: green reads as green, warnings read as warnings.
        # ================================================================
        overdrive = @{
            Background          = '#0d1017'
            Foreground          = '#c8d3f5'
            Cursor              = '#ff5f1f'   # neon orange, the one warm accent
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

        # ================================================================
        # caelestia - upstream's default scheme, with the four unusable ANSI
        # slots repaired. Surface roles and font come from upstream source:
        #   services/Colours.qml  (m3* roles, term0..term15)
        #   plugin/src/Caelestia/Config/appearanceconfig.hpp
        # Green and Yellow are swapped to upstream's own m3success / m3tertiary;
        # Cyan and BrightBlue are invented, because upstream has no cool accent.
        # See caelestia-faithful for the untouched values and why they hurt.
        # ================================================================
        caelestia = @{
            Background          = '#191114'   # m3surface
            Foreground          = '#efdfe2'   # m3onSurface
            Cursor              = '#ffb0ca'   # m3primary
            SelectionBackground = '#6f334a'   # m3primaryContainer

            Black   = '#353434'; Red    = '#ff4c8a'
            Green   = '#b5ccba'                # m3success  (was #ffbbb7 pink)
            Yellow  = '#f0bc95'                # m3tertiary (was #ffdedf near-white)
            Blue    = '#b3a2d5'; Purple = '#e98fb0'
            Cyan    = '#8fbfba'                # invented muted teal (was peach)
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

        # ================================================================
        # caelestia-faithful - term0..term15 exactly as upstream ships them.
        # Kept for reference/parity. Upstream derives these from a pink
        # wallpaper, so six of eight hues land in one pink-to-peach band:
        # Green #ffbbb7 is pink and matches Yellow, Yellow #ffdedf and
        # BrightYellow #fff1f0 sit within a few percent of the foreground so
        # warnings do not look like warnings, and BrightBlue #dcbc93 is tan and
        # collides with Cyan #ffba93. A git diff is close to unreadable.
        # ================================================================
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

    # appearanceconfig.hpp: mono family, mono.medium size, transparency.base.
    # FontFace is the GDI family name, which is 'CaskaydiaCove NF' -- not the
    # 'CaskaydiaCoveNerdFont' spelling used for the TTF filenames. install.ps1
    # resolves this against the installed families and falls back if missing.
    FontFace   = 'CaskaydiaCove NF'
    FontSize   = 12

    # Measured on Windows 11 with acrylic on: 0.85 (upstream's transparency.base)
    # and 0.75 are both indistinguishable from opaque against a dark background
    # -- the blur is applied, it just reads as flat. It only becomes legible
    # around 0.6.
    #
    # 0.55 is about as low as this scheme goes while staying readable: overdrive
    # has a very dark base (#0d1017) and high-chroma foregrounds, so it tolerates
    # more transparency than the caelestia schemes do. Below ~0.45 bright content
    # behind the window starts bleeding through the glyphs.
    Opacity    = 0.55
}
