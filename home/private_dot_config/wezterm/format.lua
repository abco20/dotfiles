local wezterm = require 'wezterm'

local function basename(value)
  value = string.gsub(value, '(.*[/\\])(.*)', '%2')
  return string.gsub(value, '(.*)(%.%w+)', '%1')
end

local symbol_color = { '#ffb2cc', '#a4a4a4' }
local font_color = { '#dddddd', '#888888' }
local back_color = { '#1e1e1e', '#2d2d2d' }
local hover_color = { '#1e1e1e', '#434343' }

wezterm.on('format-tab-title', function(tab, _, _, _, hover, max_width)
  local index = tab.is_active and 1 or 2
  local bg = hover and hover_color or back_color
  local zoomed = tab.active_pane.is_zoomed and '🔎 ' or '  '
  local title = basename(tab.active_pane.title)

  if #title > max_width then
    title = string.sub(title, 1, max_width - 4) .. '…'
  else
    title = title .. string.rep(' ', max_width - #title)
  end

  return {
    { Foreground = { Color = symbol_color[index] } },
    { Background = { Color = bg[index] } },
    { Text = '' .. zoomed },
    { Foreground = { Color = font_color[index] } },
    { Background = { Color = bg[index] } },
    { Text = title },
  }
end)
