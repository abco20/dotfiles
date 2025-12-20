local wezterm = require 'wezterm'
local launch_menu = require 'launch'
local mouce = require 'mouse'

require 'format'

local default_prog = {'zsh', '-l'}
local font_size = 12.0
if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
    default_prog = {'pwsh'}
elseif wezterm.target_triple == 'aarch64-apple-darwin' then
else
end

return {
    window_decorations = "INTEGRATED_BUTTONS|RESIZE",
    color_scheme = 'GitHub Dark',
    default_prog = default_prog,
    font = wezterm.font_with_fallback {'HackGen Console NF'},
    font_size = font_size,
    window_frame = {
        font_size = font_size
    },
    launch_menu = launch_menu,
    mouse_bindings = mouce,
    enable_wayland = false
}
