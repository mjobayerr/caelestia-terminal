-- Caelestia theme for WezTerm.
-- Palette source: theme/caelestia.psd1 (extracted from caelestia-dots/shell).
--
-- WezTerm is the half of this setup that can actually do the *feel* part:
-- GPU renderer, eased cursor animation, real acrylic backdrop, no title bar.

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---------------------------------------------------------------- colours --
config.colors = {
  background = '#191114', -- m3surface
  foreground = '#efdfe2', -- m3onSurface

  cursor_bg = '#ffb0ca',  -- m3primary
  cursor_fg = '#191114',
  cursor_border = '#ffb0ca',

  selection_bg = '#6f334a', -- m3primaryContainer
  selection_fg = '#ffd9e3', -- m3onPrimaryContainer

  ansi = {
    '#353434', '#ff4c8a', '#ffbbb7', '#ffdedf',
    '#b3a2d5', '#e98fb0', '#ffba93', '#eed1d2',
  },
  brights = {
    '#b39e9e', '#ff80a3', '#ffd3d0', '#fff1f0',
    '#dcbc93', '#f9a8c2', '#ffd1c0', '#ffffff',
  },

  tab_bar = {
    background = '#130c0e', -- m3surfaceContainerLowest
    active_tab       = { bg_color = '#261d20', fg_color = '#ffb0ca' },
    inactive_tab     = { bg_color = '#191114', fg_color = '#9e8c91' },
    inactive_tab_hover = { bg_color = '#22191c', fg_color = '#d5c2c6' },
    new_tab          = { bg_color = '#130c0e', fg_color = '#9e8c91' },
    new_tab_hover    = { bg_color = '#261d20', fg_color = '#ffb0ca' },
  },
}

-- ------------------------------------------------------------------ font --
-- Family name is 'CaskaydiaCove NF' -- that is what the patched Cascadia
-- actually reports, NOT 'CaskaydiaCove Nerd Font'. Getting this wrong makes
-- WezTerm silently fall through to the next entry.
config.font = wezterm.font_with_fallback {
  'CaskaydiaCove NF',
  'JetBrainsMono NF',
  'Cascadia Code',
}
config.font_size = 12.0
config.line_height = 1.1
config.harfbuzz_features = { 'calt=1', 'liga=1', 'ss01=1' }

-- --------------------------------------------------------------- surface --
-- Acrylic is the closest Windows gets to Hyprland blur. Radius is not
-- tunable; 0.85 is upstream's transparency.base and stays readable.
config.window_background_opacity = 0.85
config.win32_system_backdrop = 'Acrylic'
config.window_decorations = 'RESIZE' -- drop the title bar, keep resize grips
config.window_padding = { left = 16, right = 16, top = 12, bottom = 12 }
config.window_close_confirmation = 'NeverPrompt'

-- ------------------------------------------------------------ the "feel" --
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'
config.max_fps = 120
config.animation_fps = 60

config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 650
config.cursor_blink_ease_in = 'EaseOut'   -- the smooth pulse, not a hard toggle
config.cursor_blink_ease_out = 'EaseOut'

config.scrollback_lines = 10000
config.audible_bell = 'Disabled'

-- -------------------------------------------------------------- tab bar --
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.tab_max_width = 28

-- ---------------------------------------------------------------- shell --
-- Prefer PowerShell 7; fall back to Windows PowerShell 5.1 if absent.
-- winget installs PS7 per-user by default, which lands in WindowsApps as an
-- MSIX execution alias -- not under Program Files. Probe every known layout.
local function first_existing(paths)
  for _, p in ipairs(paths) do
    local f = io.open(p, 'r')
    if f then f:close() return p end
  end
  return nil
end

local home = os.getenv('USERPROFILE') or ''
local pwsh = first_existing {
  home .. '/AppData/Local/Microsoft/WindowsApps/pwsh.exe',
  home .. '/AppData/Local/Programs/PowerShell/7/pwsh.exe',
  'C:/Program Files/PowerShell/7/pwsh.exe',
}

if pwsh then
  config.default_prog = { pwsh, '-NoLogo' }
else
  pwsh = 'powershell.exe'
  config.default_prog = { 'powershell.exe', '-NoLogo' }
end

config.launch_menu = {
  { label = 'PowerShell 7',       args = { pwsh, '-NoLogo' } },
  { label = 'Windows PowerShell', args = { 'powershell.exe', '-NoLogo' } },
  { label = 'Command Prompt',     args = { 'cmd.exe' } },
  { label = 'Ubuntu (WSL)',       args = { 'wsl.exe', '~' } },
}

-- ------------------------------------------------------------- keybinds --
-- Mirrors the Windows Terminal bindings already in settings.json.
local act = wezterm.action
config.keys = {
  { key = 'd', mods = 'ALT|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'D', mods = 'ALT|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'f', mods = 'CTRL|SHIFT', action = act.Search 'CurrentSelectionOrEmptyString' },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  -- Copy only when there is a selection, otherwise pass Ctrl+C through as SIGINT.
  { key = 'c', mods = 'CTRL', action = wezterm.action_callback(function(window, pane)
      if window:get_selection_text_for_pane(pane) ~= '' then
        window:perform_action(act.CopyTo 'ClipboardAndPrimarySelection', pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
      end
    end) },
}

return config
