local fs = require 'api.fs'

---@module 'api.win'

---@class (exact) remove_buffer_options # Options for removing a buffer.
---@field force boolean|nil # whether to force the removal of the buffer.

---@class (exact) buffer # The buffer details.
---@field buffer_id integer # the buffer ID.
---@field file_path string|nil # the file path of the buffer.
---@field file_type string # the file type of the buffer.
---@field windows window[] # the window IDs that display this buffer.
---@field is_pinned_to_window fun(window_id: integer): boolean # whether the buffer is pinned to a window.
---@field is_modified boolean # whether the buffer is modified.
---@field is_listed boolean # whether the buffer is listed.
---@field is_hidden boolean # whether the buffer is hidden.
---@field is_loaded boolean # whether the buffer is loaded.
---@field cursor position # the cursor position in the buffer.
---@field confirm_saved fun(reason: string|nil): boolean # confirm if the buffer is saved.
---@field remove fun(opts: remove_buffer_options|nil)  # remove the buffer.
---@field remove_others fun(opts: remove_buffer_options|nil) # remove all other buffers.

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

local get_buf_info = function(buffer_id)
    return vim.fn.getbufinfo(buffer_id)[1]
end

---@param buffer_id integer
---@param reason string|nil
local function confirm_saved(buffer_id, reason)
    xassert {
        buffer_id = { buffer_id, 'integer' },
        reason = {
            reason,
            {
                'nil',
                { 'string', ['>'] = 0 },
            },
        },
    }

    if vim.bo[buffer_id].modified then
        local message = reason and 'Save changes to "%q" before %s?' or 'Save changes to "%q"?'
        local choice = require('api.tui').confirm(
            string.format(message, require('api.fs').base_name(vim.api.nvim_buf_get_name(buffer_id)), reason)
        )

        if choice == nil then -- Cancel
            return false
        end

        if choice then -- Yes
            vim.api.nvim_buf_call(buffer_id, vim.cmd.write)
        end
    end

    return true
end

---@param buffer_id integer
---@param opts remove_buffer_options|nil
local function remove(buffer_id, opts)
    opts = table.merge(opts, { force = false })
    xassert {
        buffer_id = { buffer_id, 'integer' },
        opts = {
            opts,
            {
                force = { 'boolean' },
            },
        },
    }

    local should_remove = opts.force or confirm_saved(buffer_id, 'closing')
    if not should_remove then
        return
    end

    for _, window_id in ipairs(get_buf_info(buffer_id).windows) do
        if vim.wo[window_id].winfixbuf then
            vim.api.nvim_win_close(window_id, true)
        end
    end

    for _, window_id in ipairs(get_buf_info(buffer_id).windows) do
        if vim.api.nvim_win_is_valid(window_id) and vim.api.nvim_win_get_buf(window_id) == buffer_id then
            local alt_buffer_id = vim.fn.bufnr '#'
            if alt_buffer_id ~= buffer_id and vim.fn.buflisted(alt_buffer_id) == 1 then
                vim.api.nvim_win_set_buf(window_id, alt_buffer_id)
            else
                local switched = vim.api.nvim_win_call(window_id, function()
                    local has_previous = pcall(vim.cmd --[[@as function]], 'bprevious')
                    if has_previous and buffer_id ~= vim.api.nvim_win_get_buf(window_id) then
                        return true
                    end
                end)

                if not switched then
                    local new_buffer_id = vim.api.nvim_create_buf(true, false)
                    vim.api.nvim_win_set_buf(window_id, new_buffer_id)
                end
            end
        end
    end

    if vim.api.nvim_buf_is_valid(buffer_id) then
        pcall(vim.cmd --[[@as function]], 'bdelete! ' .. buffer_id)
    end
end

---@param buffer_id integer|nil # the buffer to keep or the current buffer if 0 or nil
---@param opts remove_buffer_options|nil # the options for deleting the buffer
local function remove_others(buffer_id, opts)
    for _, b in ipairs(vim.buf.get_listed_buffers { loaded = false }) do
        if b ~= buffer_id then
            remove(b, opts)
        end
    end
end

---@class (exact) buf # Provides information about buffers.
---@field [integer] buffer # the details for a given buffer.

-- The buffer API.
---@type buf
local M = table.smart {
    entities = function()
        return vim.api.nvim_list_bufs()
    end,
    ---@param buffer_id integer
    valid_entity = function(buffer_id)
        return vim.api.nvim_buf_is_valid(buffer_id)
    end,
    properties = {
        buffer_id = {
            ---@param buffer_id integer
            ---@return integer
            get = function(buffer_id)
                return buffer_id
            end,
        },
        windows = {
            ---@param buffer_id integer
            get = function(buffer_id)
                local window_ids = get_buf_info(buffer_id).windows
                if not table.is_empty(window_ids) then
                    local win = require 'api.win'
                    return table.list_map(window_ids, function(window_id)
                        if not vim.api.nvim_win_is_valid(window_id) then
                            return nil
                        end

                        return win[window_id]
                    end)
                end
            end,
        },
        is_listed = {
            ---@param buffer_id integer
            ---@return boolean
            get = function(buffer_id)
                return vim.bo[buffer_id].buflisted
            end,
            ---@param buffer_id integer
            ---@param value boolean
            set = function(buffer_id, value)
                xassert {
                    value = { value, 'boolean' },
                }
                vim.bo[buffer_id].buflisted = value
            end,
        },
        is_hidden = {
            ---@param buffer_id integer
            ---@return boolean
            get = function(buffer_id)
                return get_buf_info(buffer_id).hidden
            end,
        },
        is_loaded = {
            ---@param buffer_id integer
            ---@return boolean
            get = function(buffer_id)
                return vim.api.nvim_buf_is_loaded(buffer_id)
            end,
        },
        is_modified = {
            ---@param buffer_id integer
            ---@return boolean
            get = function(buffer_id)
                return vim.bo[buffer_id].modified
            end,
        },
        file_path = {
            ---@param buffer_id integer
            ---@return string|nil
            get = function(buffer_id)
                if vim.bo[buffer_id].buftype == '' then
                    return fs.expand_path(vim.api.nvim_buf_get_name(buffer_id))
                end

                return nil
            end,
        },
        file_type = {
            ---@param buffer_id integer
            ---@return string
            get = function(buffer_id)
                return vim.bo[buffer_id].filetype
            end,
            ---@param buffer_id integer
            ---@param value string
            set = function(buffer_id, value)
                xassert {
                    value = { value, { 'string', ['>'] = 0 } },
                }

                vim.bo[buffer_id].filetype = value
            end,
        },
        cursor = {
            ---@param buffer_id integer
            ---@return position
            get = function(buffer_id)
                local window_id = vim.fn.bufwinid(buffer_id)

                local row, col = unpack(
                    vim.api.nvim_win_is_valid(window_id) and vim.api.nvim_win_get_cursor(window_id)
                        or vim.api.nvim_buf_get_mark(buffer_id, [["]])
                )

                return { row, col + 1 }
            end,
        },
    },
    functions = {
        ---@param buffer_id integer
        ---@param window_id integer
        is_pinned_to_window = function(buffer_id, window_id)
            return get_win_local_option_value(buffer_id, window_id, 'winfixbuf')
        end,
        confirm_saved = confirm_saved,
        remove = remove,
        remove_others = remove_others,
    },
}

return M
