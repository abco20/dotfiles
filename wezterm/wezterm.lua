local wezterm = require 'wezterm'
local launch_menu = require 'launch'
local mouce = require 'mouse'

require 'format'

return {
    window_decorations = "INTEGRATED_BUTTONS|RESIZE",
    color_scheme = 'Vs Code Dark+ (Gogh)',
    default_prog = {'pwsh'},
    font = wezterm.font_with_fallback {'HackGen Console NF'},
    font_size = 12.0,
    window_frame = {
        font_size = 12.0
    },
    launch_menu = launch_menu,
    mouse_bindings = mouce
}
