local wezterm = require 'wezterm'

local function BaseName(s)
    s = string.gsub(s, '(.*[/\\])(.*)', '%2')
    s = string.gsub(s, '(.*)(%.%w+)', '%1')
    return s
end

local HEADER = '' -- 文字化けしちゃってるかもしれませんが、アイコンフォント入ってます。

local SYMBOL_COLOR = {'#ffb2cc', '#a4a4a4'}
local FONT_COLOR = {'#dddddd', '#888888'}
local BACK_COLOR = {'#1e1e1e', '#2d2d2d'}
local HOVER_COLOR = {'#1e1e1e', '#434343'}

wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
    local index = tab.is_active and 1 or 2

    local bg = hover and HOVER_COLOR or BACK_COLOR
    local zoomed = tab.active_pane.is_zoomed and '🔎 ' or '  '

    local text = BaseName(tab.active_pane.title)
    if #text > max_width then
        text = string.sub(text, 1, max_width - 4) .. '…'
    else
        text = text .. string.rep(' ', max_width - #text)
    end

    return {{
        Foreground = {
            Color = SYMBOL_COLOR[index]
        }
    }, {
        Background = {
            Color = bg[index]
        }
    }, {
        Text = HEADER .. zoomed
    }, {
        Foreground = {
            Color = FONT_COLOR[index]
        }
    }, {
        Background = {
            Color = bg[index]
        }
    }, {
        Text = text

    }}
end)
