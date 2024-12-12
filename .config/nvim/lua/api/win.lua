---@module 'api.buf'

---@alias position { [1]: integer, [2]: integer } # A position in the window.

---@class (exact) window # The window object.
---@field window_id integer # the window id.
---@field buffer buffer # the active buffer in the window.
---@field cursor position # the cursor position in the window.
---@field selected_text string # the selected text in the window.
---@field is_pinned_to_buffer boolean # whether the window is pinned to the buffer.
---@field invoke_on_line fun(fn_or_cmd: fun()|string, line: integer) # invokes a function on a line.

---@class (exact) win # Provides information about windows.
---@field [integer] window # the details of a window.

-- The window API.
---@type win
local M = table.smart {
    entities = function()
        return vim.api.nvim_list_wins()
    end,
    ---@param window_id integer
    valid_entity = function(window_id)
        return vim.api.nvim_win_is_valid(window_id)
    end,
    properties = {
        window_id = {
            ---@param window_id integer
            ---@return integer
            get = function(window_id)
                return window_id
            end,
        },
        buffer = {
            ---@param window_id integer
            get = function(window_id)
                local buffer_id = vim.api.nvim_win_get_buf(window_id)
                return vim.api.nvim_buf_is_valid(buffer_id) and require('api.buf')[buffer_id] or nil
            end,
            ---@param window_id integer
            ---@param buffer buffer
            set = function(window_id, buffer)
                xassert {
                    buffer = {
                        buffer,
                        {
                            buffer_id = { 'integer', ['>'] = 0 }, -- TODO: add custom validators
                        },
                    },
                }

                vim.api.nvim_win_set_buf(window_id, buffer.buffer_id)
            end,
        },
        cursor = {
            ---@param window_id integer
            ---@return position
            get = function(window_id)
                local row, col = unpack(vim.api.nvim_win_get_cursor(window_id))
                return { row, col + 1 }
            end,
            ---@param window_id integer
            ---@param cursor position
            set = function(window_id, cursor)
                xassert {
                    cursor = {
                        cursor,
                        {
                            { 'integer', ['>'] = 0 },
                            { 'integer', ['>'] = 0 },
                        },
                    },
                }

                vim.api.nvim_win_set_cursor(window_id, { cursor[1], cursor[2] - 1 })
            end,
        },
        is_pinned_to_buffer = {
            ---@param window_id integer
            ---@return boolean
            get = function(window_id)
                return vim.wo[window_id].winfixbuf
            end,
            ---@param window_id integer
            ---@param value boolean
            set = function(window_id, value)
                xassert {
                    value = { value, 'boolean' },
                }

                vim.wo[window_id].winfixbuf = value
            end,
        },
        selected_text = {
            ---@param window_id integer
            ---@return string
            get = function(window_id)
                if not vim.fn.in_visual_mode() then
                    return ''
                end

                return vim.api.nvim_win_call(window_id, function()
                    local old = vim.fn.getreg 'a'
                    vim.cmd [[silent! normal! "aygv]]

                    local original_selection = vim.fn.getreg 'a'
                    vim.fn.setreg('a', old)

                    return original_selection:gsub('/', '\\/'):gsub('\n', '\\n')
                end)
            end,
        },
    },
    functions = {
        ---@param window_id integer
        ---@param fn_or_cmd fun()|string
        ---@param line integer
        invoke_on_line = function(window_id, fn_or_cmd, line)
            xassert {
                fn_or_cmd = { fn_or_cmd, { 'callable', { 'string', ['>'] = 0 } } },
                line = { line, { 'integer', ['>'] = 0 } },
            }

            local ok, err = vim.api.nvim_win_call(window_id, function()
                local current_pos = vim.api.nvim_win_get_cursor(window_id)
                vim.api.nvim_win_set_cursor(window_id, { line, 0 })

                ---@type boolean, any
                local ok, err
                if type(fn_or_cmd) == 'string' then
                    ok, err = pcall(vim.cmd --[[@as function]], fn_or_cmd)
                else
                    ok, err = pcall(fn_or_cmd)
                end

                vim.api.nvim_win_set_cursor(window_id, current_pos)
                return ok, err
            end)

            if not ok then
                error(err)
            end
        end,
    },
}

return M
