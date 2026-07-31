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

    # appearanceconfig.hpp: mono family, mono.medium size, transparency.base
    FontFace   = 'CaskaydiaCove Nerd Font'
    FontSize   = 12
    Opacity    = 0.85
}
