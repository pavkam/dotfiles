---@class buffer # The buffer details.
---@field window_ids integer[] # the window IDs that display this buffer.
---@field is_pinned_to_window fun(window_id: integer): boolean # whether the buffer is pinned to a window.

local get_win_local_option_value = function(buffer_id, window_id)
    local window_ids = vim.fn.getbufinfo(buffer_id)[1].windows
    for _, id in ipairs(window_ids) do
        if id == window_id then
            local v = vim.api.nvim_get_option_value('winfixbuf', { win = window_id })
            dbg('is_pinned_to_window', buffer_id, window_id, v)
            return v
        end
    end

    return false
end

-- Buffer API.
---@type table<integer, buffer>
local M = table.smart {
    enumerate = function()
        return vim.api.nvim_list_bufs()
    end,
    properties = {
        window_ids = {
            get = function(buffer_id)
                return vim.fn.getbufinfo(buffer_id)[1].windows
            end,
        },
    },
    functions = {
        is_pinned_to_window = function(buffer_id, window_id)
            return get_win_local_option_value(buffer_id, window_id)
        end,
    },
}

return M
