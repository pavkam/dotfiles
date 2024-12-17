local icons = require 'icons'
local qf = require 'qf'

---@class core.session
local M = {}
local session_dir = ide.fs.join_paths(ide.fs.DATA_DIRECTORY, 'sessions')
local enabled = not ide.process.is_headless and vim.fn.argc() == 0

--- Get the current session name.
---@return string|nil # the current session name or nil if not enabled
function M.current()
    if not enabled then
        return nil
    end

    local git_root = vim.trim(vim.fn.system 'git rev-parse --show-toplevel')
    local full_name = vim.v.shell_error == 0 and git_root or vim.fn.getcwd()

    local git_branch = vim.trim(vim.fn.system 'git branch --show-current')
    full_name = vim.v.shell_error == 0 and full_name .. '-' .. git_branch or full_name

    return full_name
end

--- Encode the session name as file paths.
---@param name string # the name of the session.
---@return string, string, string # the session file paths.
function M.files(name)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
    }

    -- escape special characters in full name (URL encoding)
    name = string.gsub(name, '([^%w %-%_%.%~])', function(c)
        return string.format('_%02X', string.byte(c))
    end)
    name = string.gsub(name, ' ', '+')

    local res = ide.fs.join_paths(session_dir, name)
    return res .. '.vim', res .. '.shada', res .. '.json'
end

--- Call a function with error handling.
---@param what string # the name of the function.
---@param session string # the name of the session.
---@vararg any # the function and its arguments.
---@return boolean, any # the result of the function.
local function error_call(what, session, ...)
    -- TODO: this can be moved out
    local ok, res_or_error = pcall(...)
    if not ok then
        ide.tui.error(
            string.format('Failed to %s for session `%s`:\n```%s```', what, session, vim.inspect(res_or_error)),
            { prefix_icon = icons.UI.Error }
        )
    end

    return ok, res_or_error
end

---@class (exact) core.session.CustomData
---@field config config_persistent_data
---@field qf ui.qf.Exported

--- Save the current session
---@param name string # the name of the session
function M.save_session(name)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
    }

    local session_file, shada_file, custom_file = M.files(name)

    vim.fn.mkdir(session_dir, 'p')

    error_call('save vim session', name, vim.cmd, 'mks! ' .. session_file)
    error_call('save shada', name, vim.cmd, 'wshada! ' .. shada_file)

    ---@type core.session.CustomData
    local custom = {
        config = ide.config.export(),
        qf = qf.export(),
    }

    local json = vim.json.encode(custom) or '{}'
    error_call('save configuration', name, ide.fs.write_text_file, custom_file, json, { throw_errors = true })

    ide.tui.hint(string.format('Saved session `%s`', name), { prefix_icon = icons.UI.SessionSave })
end

--- Resets the UI
local function reset_ui()
    -- TODO: this can be moved out
    vim.cmd [[silent! tabonly!]]
    vim.cmd [[silent! %bd!]]
    vim.cmd [[silent! %bw!]]

    vim.args = {}
    enabled = true
end

--- Restore a session
---@param name string # the name of the session
function M.restore_session(name)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
    }

    if M.saved(name) then
        local session_file, shada_file, custom_file = M.files(name)

        -- close all windows, tabs and buffers
        reset_ui()

        vim.schedule(function()
            local ok, data = error_call('restore custom data', name, vim.fn.readfile, custom_file, 'b')
            if ok then
                ---@type boolean, core.session.CustomData
                ok, data = error_call('deserialize custom data', name, vim.json.decode, data[1])
                if ok then
                    error_call('apply configuration', name, ide.config.import, data.config)
                    error_call('apply quickfix', name, qf.import, data.qf)
                end
            end

            error_call('restore shada', name, vim.cmd.rshada, shada_file)
            error_call('restore vim session', name, vim.cmd.source, session_file)

            vim.schedule(function()
                ide.tui.redraw()
                ide.tui.hint(string.format('Restored session `%s`', name), { prefix_icon = icons.UI.SessionSave })
            end)
        end)
    end
end

--- Check if a session is saved
---@param name string # the name of the session
function M.saved(name)
    local session_file, shada_file, custom_file = M.files(name)

    return ide.fs.file_is_readable(session_file)
        and ide.fs.file_is_readable(shada_file)
        and ide.fs.file_is_readable(custom_file)
end

local option = ide.config.use('current_session', { persistent = false })

--- Swap sessions
---@param old_name string|nil # the name of the old session
---@param new_name string|nil # the name of the new session
local function swap_sessions(old_name, new_name)
    if enabled then
        if old_name ~= new_name then
            if old_name then
                M.save_session(old_name)
            end

            if new_name then
                M.restore_session(new_name)
                option.set(new_name)
            end
        end
    end
end

if enabled then
    -- TODO: this won't run on reset
    ide.process.on_exit(function(args)
        if not args.dying then
            swap_sessions(M.current(), nil)
        end
    end)

    ide.process.on_ready(function()
        swap_sessions(nil, M.current())
    end)

    ide.process.on_focus(function()
        swap_sessions(option.get(), M.current())
    end)

    -- TODO: this is incorrect (runs only once)
    vim.defer_fn(function()
        swap_sessions(M.current(), nil)
    end, 60000)
end

return M
