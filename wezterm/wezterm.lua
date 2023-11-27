local wezterm = require 'wezterm'
require 'format'
local launch_menu = require 'launch'

return {
    window_decorations = "INTEGRATED_BUTTONS|RESIZE",
    color_scheme = 'Vs Code Dark+ (Gogh)',
    default_prog = {'pwsh'},
    font = wezterm.font_with_fallback {'HackGen Console NF'},
    font_size = 12.0,
    window_frame = {
        font_size = 12.0
    },
    launch_menu = launch_menu
}
