@{
    # Caelestia palette — single source of truth.
    #
    # Every value below was extracted from the upstream shell, not hand-picked:
    #   ANSI 0-15      caelestia-shell/services/Colours.qml   (term0 .. term15)
    #   surface/text   caelestia-shell/services/Colours.qml   (m3* Material 3 roles)
    #   font + opacity caelestia-shell/plugin/src/Caelestia/Config/appearanceconfig.hpp
    #
    # This is caelestia's *default* scheme. Upstream regenerates it from the
    # wallpaper via Material You; see README "Re-theming from a wallpaper".

    Name = 'Caelestia'

    # Material 3 surface roles -> terminal chrome
    Background          = '#191114'   # m3surface
    Foreground          = '#efdfe2'   # m3onSurface
    Cursor              = '#ffb0ca'   # m3primary
    SelectionBackground = '#6f334a'   # m3primaryContainer

    # ANSI 0-7 (term0 .. term7)
    Black   = '#353434'
    Red     = '#ff4c8a'
    Green   = '#ffbbb7'
    Yellow  = '#ffdedf'
    Blue    = '#b3a2d5'
    Purple  = '#e98fb0'
    Cyan    = '#ffba93'
    White   = '#eed1d2'

    # ANSI 8-15 (term8 .. term15)
    BrightBlack  = '#b39e9e'
    BrightRed    = '#ff80a3'
    BrightGreen  = '#ffd3d0'
    BrightYellow = '#fff1f0'
    BrightBlue   = '#dcbc93'
    BrightPurple = '#f9a8c2'
    BrightCyan   = '#ffd1c0'
    BrightWhite  = '#ffffff'

    # appearanceconfig.hpp: mono family, mono.medium size, transparency.base.
    # FontFace is the GDI family name, which is 'CaskaydiaCove NF' -- not the
    # 'CaskaydiaCoveNerdFont' spelling used for the TTF filenames. install.ps1
    # resolves this against the installed families and falls back if missing.
    FontFace   = 'CaskaydiaCove NF'
    FontSize   = 12

    # Upstream's transparency.base is 0.85, but upstream also ships
    # transparency.enabled = false, so there is no upstream value to match for
    # a terminal that actually wants the blur visible.
    #
    # Measured on Windows 11 with acrylic on: 0.85 and 0.75 are both
    # indistinguishable from opaque against a dark background -- the blur is
    # there, it just reads as flat. Blur only becomes legible around 0.6 and
    # below. 0.65 keeps text crisp while the backdrop is clearly blurred.
    # Raise to 0.85 for exact upstream parity (and effectively no visible blur).
    Opacity    = 0.65
}
