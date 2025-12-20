local wezterm = require 'wezterm'

launch_menu = {}

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
    table.insert(launch_menu, {
        label = 'PowerShell',
        args = {'pwsh.exe'}
    })
    table.insert(launch_menu, {
        label = 'Ubuntu 22.04',
        args = {'ubuntu2204.exe'}
    })

end

return launch_menu
