local wezterm = require 'wezterm'
local launch_menu = {}

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
  table.insert(launch_menu, {
    label = 'PowerShell',
    args = { 'pwsh.exe' },
  })
  table.insert(launch_menu, {
    label = 'Ubuntu 24.04',
    args = { 'ubuntu2404.exe' },
  })
end

return launch_menu
