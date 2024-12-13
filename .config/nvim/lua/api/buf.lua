local fs = require 'api.fs'

---@module 'api.win'

---@class (exact) remove_buffer_options # Options for removing a buffer.
---@field force boolean|nil # whether to force the removal of the buffer.

---@class (exact) buffer # The buffer details.
---@field id integer # the buffer ID.
---@field file_path string|nil # the file path of the buffer.
---@field file_type string # the file type of the buffer.
---@field windows window[] # the window IDs that display this buffer.
---@field is_modified boolean # whether the buffer is modified.
---@field is_listed boolean # whether the buffer is listed.
---@field is_hidden boolean # whether the buffer is hidden.
---@field is_loaded boolean # whether the buffer is loaded.
---@field cursor position # the cursor position in the buffer.
---@field confirm_saved fun(reason: string|nil): boolean # confirm if the buffer is saved.
---@field remove fun(opts: remove_buffer_options|nil)  # remove the buffer.
---@field remove_others fun(opts: remove_buffer_options|nil) # remove all other buffers.

---@class (exact) create_buffer_options # Options for creating a buffer.
---@field listed boolean|nil # whether the buffer is listed.
---@field scratch boolean|nil # whether the buffer is a scratch buffer.

---@class (exact) buf # Provides information about buffers.
---@field [integer] buffer|nil # the details for a given buffer.
---@field alternate buffer|nil # the alternate buffer.
---@field new fun(opts: create_buffer_options|nil): buffer # create a new buffer.

-- The buffer API.
---@type buf
local M = table.smart2 {
    entity_ids = vim.api.nvim_list_bufs,
    entity_id_valid = vim.api.nvim_buf_is_valid,
    entity_properties = {
        windows = {
            ---@param buffer buffer
            get = function(_, buffer)
                local window_ids = vim.fn.getbufinfo(buffer.id)[1].windows
                if not table.is_empty(window_ids) then
                    local win = require 'api.win'
                    return table.list_map(window_ids, function(window_id)
                        return win[window_id]
                    end)
                end
            end,
        },
        is_listed = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.bo[buffer.id].buflisted
            end,
            ---@param buffer buffer
            ---@param value boolean
            set = function(_, buffer, value)
                xassert {
                    value = { value, 'boolean' },
                }
                vim.bo[buffer.id].buflisted = value
            end,
        },
        is_hidden = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.fn.getbufinfo(buffer.id)[1].hidden
            end,
        },
        is_loaded = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.api.nvim_buf_is_loaded(buffer.id)
            end,
        },
        is_modified = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.bo[buffer.id].modified
            end,
        },
        file_path = {
            ---@param buffer buffer
            ---@return string|nil
            get = function(_, buffer)
                if vim.bo[buffer.id].buftype == '' then
                    return fs.expand_path(vim.api.nvim_buf_get_name(buffer.id))
                end

                return nil
            end,
        },
        file_type = {
            ---@param buffer buffer
            ---@return string
            get = function(_, buffer)
                return vim.bo[buffer.id].filetype
            end,
            ---@param buffer buffer
            ---@param value string
            set = function(_, buffer, value)
                xassert {
                    value = { value, { 'string', ['>'] = 0 } },
                }

                vim.bo[buffer.id].filetype = value
            end,
        },
        cursor = {
            ---@param buffer buffer
            ---@return position
            get = function(_, buffer)
                local window = require('api.win')[vim.fn.bufwinid(buffer.id)]
                if window then
                    return window.cursor
                end

                local row, col = vim.api.nvim_buf_get_mark(buffer.id, [["]])

                return { row, col + 1 }
            end,
        },
    },
    entity_functions = {
        ---@param buffer buffer
        ---@param reason string|nil
        confirm_saved = function(_, buffer, reason)
            xassert {
                reason = {
                    reason,
                    {
                        'nil',
                        { 'string', ['>'] = 0 },
                    },
                },
            }

            if buffer.is_modified then
                local message = reason and 'Save changes to "%q" before %s?' or 'Save changes to "%q"?'
                local choice = require('api.tui').confirm(
                    string.format(message, require('api.fs').base_name(buffer.file_path), reason)
                )

                if choice == nil then -- Cancel
                    return false
                end

                if choice then -- Yes
                    vim.api.nvim_buf_call(buffer.id, vim.cmd.write)
                end
            end

            return true
        end,

        ---@param buffer buffer
        ---@param opts remove_buffer_options|nil
        remove = function(_, buffer, opts)
            opts = table.merge(opts, { force = false })
            xassert {
                opts = {
                    opts,
                    {
                        force = { 'boolean' },
                    },
                },
            }

            local should_remove = opts.force or buffer.confirm_saved 'closing'
            if not should_remove then
                return
            end

            for _, window in ipairs(buffer.windows) do
                if window.is_pinned_to_buffer then
                    window.close()
                else
                    window.display_alternate_buffer()
                end
            end

            pcall(vim.cmd.bdelete, { args = { buffer.id }, bang = true })
        end,

        ---@param t buf
        ---@param buffer buffer
        ---@param opts remove_buffer_options|nil
        remove_others = function(t, buffer, opts)
            opts = table.merge(opts, { force = false })
            xassert {
                opts = {
                    opts,
                    {
                        force = { 'boolean' },
                    },
                },
            }

            for _, other_buffer in ipairs(t) do
                if other_buffer ~= buffer.id then
                    other_buffer.remove(opts)
                end
            end
        end,
    },
    properties = {
        alternate = {
            ---@param t buf
            ---@return buffer|nil
            get = function(t)
                local buffer = t[vim.fn.bufnr '#']
                if buffer and buffer.is_listed then
                    return buffer
                end

                return nil
            end,
        },
    },
    functions = {
        ---@param t buf
        ---@param opts create_buffer_options|nil
        ---@return buffer
        new = function(t, opts)
            opts = table.merge(opts, { listed = true, scratch = false })

            xassert {
                opts = {
                    opts,
                    {
                        listed = { 'boolean' },
                        scratch = { 'boolean' },
                    },
                },
            }

            return t[vim.api.nvim_create_buf(opts.listed, opts.scratch)]
        end,
    },
}

return M
