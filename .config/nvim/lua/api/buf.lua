---@class buffer # The buffer details.
---@field window_ids integer[] # the window IDs that display this buffer.
---@field is_pinned_to_window fun(window_id: integer): boolean # whether the buffer is pinned to a window.

-- Get the value of a window-local option.
---@param buffer_id integer # The buffer id.
---@param window_id integer # The window id.
---@param option string # The option name.
local get_win_local_option_value = function(buffer_id, window_id, option)
    xassert {
        buffer_id = { buffer_id, { 'integer', ['>'] = 0 } },
        window_id = { window_id, { 'integer', ['>'] = 0 } },
        option = { option, { 'string', ['>'] = 0 } },
    }

    local window_ids = vim.fn.getbufinfo(buffer_id)[1].windows
    for _, id in ipairs(window_ids) do
        if id == window_id then
            local v = vim.api.nvim_get_option_value(option, { win = window_id })
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
            return get_win_local_option_value(buffer_id, window_id, 'winfixbuf')
        end,
    },
}

return M
