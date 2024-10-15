local Bar = require('ui.bars').Bar
local components = require 'ui.bars.components'
local events = require 'core.events'

---@type vim.fn.WindowType[]
local allowed_win_types = {
    'main',
    'split',
    'quick-fix',
    'location-list',
}

events.on_event({ 'BufWinEnter' }, function()
    local window = vim.api.nvim_get_current_win()

    if Bar.get(window) then
        return
    end

    if vim.list_contains(allowed_win_types, vim.fn.win_type(window)) and not vim.fn.win_in_diff_mode(window) then
        local bar = Bar.create {
            active_hl_group = 'WinBar',
            inactive_hl_group = 'WinBarNC',
            components = {
                components.fill(),
                components.buffer_name(),
            },
        }

        bar:attach(window)
    end
end)

events.on_event('WinClosed', function(evt)
    local window = tonumber(evt.match)
    if not window then
        return
    end

    local bar = Bar.get(window)
    if bar then
        bar:detach(window)
    end
end)
