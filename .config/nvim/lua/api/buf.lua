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
---@field is_normal boolean # whether the buffer is a normal buffer.
---@field cursor position # the cursor position in the buffer.
---@field height integer # the height of the buffer.
---@field lines fun(start: integer|nil, end_: integer|nil): string[] # get the lines of the buffer.
---@field confirm_saved fun(reason: string|nil): boolean # confirm if the buffer is saved.
---@field remove fun(opts: remove_buffer_options|nil)  # remove the buffer.
---@field remove_others fun(opts: remove_buffer_options|nil) # remove all other buffers.

---@class (exact) create_buffer_options # Options for creating a buffer.
---@field listed boolean|nil # whether the buffer is listed.
---@field scratch boolean|nil # whether the buffer is a scratch buffer.

---@class (exact) buf # Provides information about buffers.
---@field [integer] buffer|nil # the details for a given buffer.
---@field alternate buffer|nil # the alternate buffer.
---@field current buffer # the current buffer.
---@field new fun(opts: create_buffer_options|nil): buffer # create a new buffer.
---@field load fun(file_path: string): buffer|nil # load a buffer from a file.

-- The buffer API.
---@type buf
local M = table.smart {
    entity_ids = vim.api.nvim_list_bufs,
    entity_id_valid = function(id)
        xassert {
            id = { id, { 'nil', 'integer' } },
        }

        return id and vim.api.nvim_buf_is_valid(id) or false
    end,
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
                return vim.fn.getbufinfo(buffer.id)[1].hidden == 1
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
        is_normal = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.api.nvim_buf_is_valid(buffer.id) and vim.bo[buffer.id].buftype == '' and not buffer.is_hidden
            end,
        },
        file_path = {
            ---@param buffer buffer
            ---@return string|nil
            get = function(_, buffer)
                if buffer.is_normal then
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

                local row, col = unpack(vim.api.nvim_buf_get_mark(buffer.id, [["]]))

                return { row, col + 1 }
            end,
        },
        height = {
            ---@param buffer buffer
            ---@return integer
            get = function(_, buffer)
                return vim.api.nvim_buf_line_count(buffer.id)
            end,
        },
    },
    entity_functions = {
        ---@param buffer buffer
        ---@param start integer|nil
        ---@param end_ integer|nil
        ---@return string[]
        lines = function(_, buffer, start, end_)
            local height = buffer.height
            xassert {
                start = {
                    start,
                    {
                        'nil',
                        {
                            'integer',
                            ['>'] = 0,
                            ['<'] = height,
                        },
                    },
                },
                end_ = {
                    end_,
                    {
                        'nil',
                        {
                            'integer',
                            ['>'] = 0,
                            ['<'] = height,
                        },
                    },
                },
            }

            return vim.api.nvim_buf_get_lines(buffer.id, start or 0, end_ and (end_ + 1) or -1, true)
        end,

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

            for _, window in ipairs(buffer.windows or {}) do
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
        current = {
            ---@param t buf
            ---@return buffer
            get = function(t)
                return t[vim.api.nvim_get_current_buf()]
            end,
        },
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
        ---@param t buf
        ---@param file_path string
        load = function(t, file_path)
            xassert {
                file_path = { file_path, { 'string', ['>'] = 0 } },
            }

            if not fs.file_exists(file_path) then
                return nil
            end

            local buffer = t[vim.fn.bufadd(file_path)]
            if buffer then
                vim.fn.bufload(buffer.id)
            end

            return buffer
        end,
    },
}

return M
