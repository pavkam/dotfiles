---@module 'api.buf'

---@alias position { [1]: integer, [2]: integer } # A position in the window.

---@class (exact) window # The window object.
---@field id integer # the window id.
---@field buffer buffer # the active buffer in the window.
---@field cursor position # the cursor position in the window.
---@field width integer # the width of the window.
---@field height integer # the height of the window.
---@field status_column_width integer # the width of the status column.
---@field selected_text string # the selected text in the window.
---@field toggle_fold fun(line: integer|nil): boolean|nil # toggles the fold at the line.
---@field is_folded fun(line: integer|nil): boolean|nil # whether the line is folded.
---@field is_pinned_to_buffer boolean # whether the window is pinned to the buffer.
---@field invoke_on_line fun(fn_or_cmd: fun()|string, line: integer) # invokes a function on a line.
---@field display_alternate_buffer fun() # selects the alternate buffer.
---@field close fun() # closes the window.

---@class (exact) win # Provides information about windows.
---@field [integer] window # the details of a window.

-- The window API.
---@type win
local M = table.smart {
    entity_ids = vim.api.nvim_list_wins,
    entity_id_valid = vim.api.nvim_win_is_valid,
    entity_properties = {
        buffer = {
            ---@param window window
            get = function(_, window)
                return require('api.buf')[vim.api.nvim_win_get_buf(window.id)]
            end,
            ---@param window window
            ---@param buffer buffer
            set = function(_, window, buffer)
                xassert {
                    buffer = {
                        buffer,
                        {
                            buffer_id = { 'integer', ['>'] = 0 }, -- TODO: add custom validators
                        },
                    },
                }

                vim.api.nvim_win_set_buf(window.id, buffer.id)
            end,
        },
        cursor = {
            ---@param window window
            ---@return position
            get = function(_, window)
                local row, col = unpack(vim.api.nvim_win_get_cursor(window.id))
                return { row, col + 1 }
            end,
            ---@param window window
            ---@param cursor position
            set = function(_, window, cursor)
                xassert {
                    cursor = {
                        cursor,
                        {
                            { 'integer', ['>'] = 0 },
                            { 'integer', ['>'] = 0 },
                        },
                    },
                }

                vim.api.nvim_win_set_cursor(window.id, { cursor[1], cursor[2] - 1 })
            end,
        },
        is_pinned_to_buffer = {
            ---@param window window
            ---@return boolean
            get = function(_, window)
                return vim.wo[window.id].winfixbuf
            end,
            ---@param window window
            ---@param value boolean
            set = function(_, window, value)
                xassert {
                    value = { value, 'boolean' },
                }

                vim.wo[window.id].winfixbuf = value
            end,
        },
        selected_text = {
            ---@param window window
            ---@return string
            get = function(_, window)
                if not vim.fn.in_visual_mode() then
                    return ''
                end

                return vim.api.nvim_win_call(window.id, function()
                    local old = vim.fn.getreg 'a'
                    vim.cmd [[silent! normal! "aygv]]

                    local original_selection = vim.fn.getreg 'a'
                    vim.fn.setreg('a', old)

                    return original_selection:gsub('/', '\\/'):gsub('\n', '\\n')
                end)
            end,
        },
        width = {
            ---@param window window
            ---@return integer
            get = function(_, window)
                return vim.api.nvim_win_get_width(window.id)
            end,
            ---@param window window
            ---@param value integer
            set = function(_, window, value)
                xassert {
                    value = { value, { 'integer', ['>'] = 0 } },
                }

                vim.api.nvim_win_set_width(window.id, value)
            end,
        },
        height = {
            ---@param window window
            ---@return integer
            get = function(_, window)
                return vim.api.nvim_win_get_height(window.id)
            end,
            ---@param window window
            ---@param value integer
            set = function(_, window, value)
                xassert {
                    value = { value, { 'integer', ['>'] = 0 } },
                }

                vim.api.nvim_win_set_height(window.id, value)
            end,
        },
        status_column_width = {
            get = function(_, window)
                return vim.fn.getwininfo(window.id)[1].textoff
            end,
        },
    },
    entity_functions = {
        ---@param window window
        close = function(_, window)
            vim.api.nvim_win_close(window.id, true)
        end,

        ---@param window window
        display_alternate_buffer = function(_, window)
            local alt_buffer = require('api.buf')[vim.fn.bufnr '#']
            local current_buffer = window.buffer

            if alt_buffer and alt_buffer.id ~= current_buffer.id and alt_buffer.is_listed then
                window.buffer = alt_buffer
            else
                local switched = vim.api.nvim_win_call(window.id, function()
                    return pcall(vim.cmd.bprevious, { silent = true }) and current_buffer.id ~= window.buffer.id
                end)

                if not switched then
                    window.buffer = require('api.buf').new()
                end
            end
        end,

        ---@param window window
        ---@param fn_or_cmd fun()|string
        ---@param line integer
        invoke_on_line = function(_, window, fn_or_cmd, line)
            xassert {
                fn_or_cmd = { fn_or_cmd, { 'callable', { 'string', ['>'] = 0 } } },
                line = { line, { 'integer', ['>'] = 0 } },
            }

            local current_cursor = window.cursor
            window.cursor = { line, 0 }

            local ok, err = vim.api.nvim_win_call(window.id, function()
                ---@type boolean, any
                local ok, err
                if type(fn_or_cmd) == 'string' then
                    ok, err = pcall(vim.cmd --[[@as function]], fn_or_cmd)
                else
                    ok, err = pcall(fn_or_cmd)
                end
                return ok, err
            end)

            vim.api.nvim_win_set_cursor(window.id, current_cursor)

            if not ok then
                error(err)
            end
        end,

        ---@param window window
        ---@param line integer|nil
        ---@return boolean|nil
        toggle_fold = function(_, window, line)
            xassert {
                line = { line, { 'nil', { 'integer', ['>'] = 0 } } },
            }

            line = line or window.cursor[1]

            return vim.api.nvim_win_call(window.id, function()
                if vim.fn.foldclosed(line) == line then
                    vim.cmd.foldopen { range = { line } }
                    return true
                elseif vim.fn.foldlevel(line) > 0 then
                    vim.cmd.foldclose { range = { line } }
                    return false
                end

                return nil
            end)
        end,

        ---@param window window
        ---@param line integer|nil
        ---@return boolean|nil
        is_folded = function(_, window, line)
            xassert {
                line = { line, { 'nil', { 'integer', ['>'] = 0 } } },
            }

            line = line or window.cursor[1]

            return vim.api.nvim_win_call(window.id, function()
                if vim.fn.foldclosed(line) >= 0 then
                    return true
                elseif tostring(vim.treesitter.foldexpr(line)):sub(1, 1) == '>' then
                    return false
                end

                return nil
            end)
        end,
    },
}

return M
