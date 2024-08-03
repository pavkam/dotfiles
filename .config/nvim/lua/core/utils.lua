local icons = require 'ui.icons'

---@class core.utils
local M = {}

---@type table<integer, uv_timer_t>
local deferred_buffer_timers = {}

require('core.events').on_event('BufDelete', function(evt)
    local timer = deferred_buffer_timers[evt.buf]
    if timer then
        timer:stop()
        deferred_buffer_timers[evt.buf] = nil
    end
end)

--- Defers a function call for buffer in LIFO mode. If the function is called again before the timeout, the
--- timer is reset.
---@param buffer integer|nil # the buffer to defer the function for or the current buffer if 0 or nil
---@param fn fun(buffer: integer) # the function to call
---@param timeout integer # the timeout in milliseconds
function M.defer_unique(buffer, fn, timeout)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local timer = deferred_buffer_timers[buffer]
    if not timer then
        timer = vim.uv.new_timer()
        deferred_buffer_timers[buffer] = timer
    else
        timer:stop()
    end

    local res = timer:start(
        timeout,
        0,
        vim.schedule_wrap(function()
            timer:stop()
            fn(buffer)
        end)
    )

    if res ~= 0 then
        require('core.logging').error(string.format('Failed to start defer timer for buffer %d', buffer))
    end
end

---@alias core.utils.Target string|integer|nil # the target buffer or path or auto-detect

--- Expands a target of any command to a buffer and a path
---@param target core.utils.Target # the target to expand
---@return integer, string # the buffer and the path
function M.expand_target(target)
    if type(target) == 'number' or target == nil then
        target = target or vim.api.nvim_get_current_buf()
        return target, vim.api.nvim_buf_get_name(target)
    else
        local path = vim.fn.expand(target --[[@as string]])
        return vim.api.nvim_get_current_buf(), vim.uv.fs_realpath(vim.fn.expand(path)) or path
    end
end

--- Helper function that calculates folds
function M.fold_text()
    local ok = pcall(vim.treesitter.get_parser, vim.api.nvim_get_current_buf())
    ---@diagnostic disable-next-line: undefined-field
    local ret = ok and vim.treesitter.foldtext and vim.treesitter.foldtext() or nil
    if not ret then
        ret = {
            {
                vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1],
                {},
            },
        }
    end

    table.insert(ret, { ' ' .. icons.TUI.Ellipsis })
    return ret
end

--- Confirms an operation that requires the buffer to be saved
---@param buffer integer|nil # the buffer to confirm for or the current buffer if 0 or nil
---@param reason string|nil # the reason for the confirmation
---@return boolean # true if the buffer was saved or false if the operation was cancelled
function M.confirm_saved(buffer, reason)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if vim.bo[buffer].modified then
        local message = reason and 'Save changes to "%q" before %s?' or 'Save changes to "%q"?'
        local choice = vim.fn.confirm(
            string.format(message, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t'), reason),
            '&Yes\n&No\n&Cancel'
        )

        if choice == 0 or choice == 3 then -- Cancel
            return false
        end

        if choice == 1 then -- Yes
            vim.api.nvim_buf_call(buffer, vim.cmd.write)
        end
    end

    return true
end

--- Gets the selected text from the current buffer in visual mode
---@return string # the selected text
function M.get_selected_text()
    if not vim.fn.is_visual_mode() then
        error 'Not in visual mode'
    end

    local old = vim.fn.getreg 'a'
    vim.cmd [[silent! normal! "aygv]]

    local original_selection = vim.fn.getreg 'a'
    vim.fn.setreg('a', old)

    local res, _ = original_selection:gsub('/', '\\/'):gsub('\n', '\\n')
    return res
end

--- Checks if a plugin is available
---@param name string # the name of the plugin
---@return boolean # true if the plugin is available, false otherwise
function M.has_plugin(name)
    assert(type(name) == 'string' and name ~= '')

    if package.loaded['lazy'] then
        return require('lazy.core.config').spec.plugins[name] ~= nil
    end

    return false
end

--- Runs a function with the current visual selection
---@param buffer integer|nil # the buffer to run the function for or the current buffer if 0 or nil
---@param callback fun(restore_callback: fun(command?: string)) # the callback to call with the selection
function M.run_with_visual_selection(buffer, callback)
    assert(type(callback) == 'function')

    if not vim.fn.is_visual_mode() then
        error 'Not in visual mode'
    end

    buffer = buffer or vim.api.nvim_get_current_buf()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes([[<esc>]], true, false, true), 'n', false)

    vim.schedule(function()
        local sel_start = vim.api.nvim_buf_get_mark(buffer, '<')
        local sel_end = vim.api.nvim_buf_get_mark(buffer, '>')

        local restore_callback = function(command)
            vim.api.nvim_buf_set_mark(buffer, '<', sel_start[1], sel_start[2], {})
            vim.api.nvim_buf_set_mark(buffer, '>', sel_end[1], sel_end[2], {})

            vim.api.nvim_feedkeys([[gv]], 'n', false)

            if command then
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes(string.format(':%s<cr>', command), true, false, true),
                    'n',
                    false
                )
            end
        end

        callback(restore_callback)
    end)
end

--- Refreshes the UI
function M.refresh_ui()
    vim.cmd.resize()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
    vim.cmd 'redraw!'
end

local undo_command = vim.api.nvim_replace_termcodes('<c-G>u', true, true, true)

--- Creates an undo point if in insert mode
function M.create_undo_point()
    assert(vim.api.nvim_get_mode().mode == 'i')

    vim.api.nvim_feedkeys(undo_command, 'n', false)
end

return M
