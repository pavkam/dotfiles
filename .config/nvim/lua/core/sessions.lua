local utils = require 'core.utils'
local events = require 'core.events'
local icons = require 'ui.icons'
local settings = require 'core.settings'
local qf = require 'ui.qf'

---@class core.session
local M = {}
local session_dir = vim.fs.join_paths(vim.fn.stdpath 'data' --[[@as string]], 'sessions') --[[@as string]]

---@type string
local setting_name = 'current_session_name'

--- Check if the session support is enabled
--- @return boolean # true if enabled, false otherwise
local function enabled()
    return vim.fn.argc() == 0
end

--- Get the current session name
---@return string|nil # the current session name or nil if not enabled
function M.current()
    if not enabled() then
        return nil
    end

    local git_root = vim.trim(vim.fn.system 'git rev-parse --show-toplevel')
    local full_name = vim.v.shell_error == 0 and git_root or vim.fn.getcwd()

    local git_branch = vim.trim(vim.fn.system 'git branch --show-current')
    full_name = vim.v.shell_error == 0 and full_name .. '-' .. git_branch or full_name

    return full_name
end

--- Encode the session name as file paths
---@param name string # the name of the session
---@return string, string, string # the session file paths
function M.files(name)
    assert(type(name) == 'string')

    -- escape special characters in full name (URL encoding)
    name = string.gsub(name, '([^%w %-%_%.%~])', function(c)
        return string.format('_%02X', string.byte(c))
    end)
    name = string.gsub(name, ' ', '+')

    local res = vim.fs.join_paths(session_dir, name)
    ---@cast res string

    return res .. '.vim', res .. '.shada', res .. '.json'
end

---@class (exact) core.session.CustomData
---@field settings core.settings.Exported
---@field qf ui.qf.Exported

--- Save the current session
---@param name string # the name of the session
function M.save_session(name)
    assert(type(name) == 'string')

    local session_file, shada_file, custom_file = M.files(name)

    vim.fn.mkdir(session_dir, 'p')

    vim.cmd('mks! ' .. session_file)
    vim.cmd('wshada! ' .. shada_file)

    ---@type core.session.CustomData
    local custom = {
        settings = settings.export(),
        qf = qf.export(),
    }

    local json = vim.json.encode(custom) or '{}'
    vim.fn.writefile({ json }, custom_file, 'bs')

    vim.hint(string.format('Saved session `%s`', name), { prefix_icon = icons.UI.SessionSave })
end

--- Resets the UI
local function reset_ui()
    vim.cmd [[silent! tabonly!]]
    vim.cmd [[silent! %bd!]]
    vim.cmd [[silent! %bw!]]

    vim.args = {}
end

--- Call a function with error handling
---@param name string # the name of the function
---@param session string # the name of the session
---@vararg any # the function and its arguments
---@return boolean, any # the result of the function
local function error_call(name, session, ...)
    local ok, res_or_error = pcall(...)
    if not ok then
        vim.error(
            string.format(
                '%s Failed to restore %s for session `%s`:\n```%s```',
                icons.UI.Disabled,
                name,
                session,
                vim.inspect(res_or_error)
            )
        )
    end

    return ok, res_or_error
end

--- Restore a session
---@param name string # the name of the session
function M.restore_session(name)
    assert(type(name) == 'string')

    if M.saved(name) then
        local session_file, shada_file, custom_file = M.files(name)

        -- close all windows, tabs and buffers
        reset_ui()

        vim.schedule(function()
            local ok, data = error_call('custom data', name, vim.fn.readfile, custom_file, 'b')
            if ok then
                ---@type boolean, core.session.CustomData
                ok, data = error_call('custom data', name, vim.json.decode, data[1])
                if ok then
                    error_call('settings', name, settings.import, data.settings)
                    error_call('quickfix', name, qf.import, data.qf)
                end
            end

            error_call('shada', name, vim.cmd.rshada, shada_file)
            -- URGENT: this session management is crap:  error_call('vim session', name, vim.cmd.source, session_file)

            vim.schedule(function()
                utils.refresh_ui()
                vim.hint(string.format('Restored session `%s`', name), { prefix_icon = icons.UI.SessionSave })
            end)
        end)
    end
end

--- Check if a session is saved
---@param name string # the name of the session
function M.saved(name)
    local session_file, shada_file, custom_file = M.files(name)

    return vim.fn.filereadable(session_file) == 1
        and vim.fn.filereadable(shada_file) == 1
        and vim.fn.filereadable(custom_file) == 1
end

--- Swap sessions
---@param old_name string|nil # the name of the old session
---@param new_name string|nil # the name of the new session
local function swap_sessions(old_name, new_name)
    if enabled() then
        if old_name ~= new_name then
            if old_name then
                M.save_session(old_name)
            end

            if new_name then
                M.restore_session(new_name)
                settings.set(setting_name, new_name, { scope = 'instance' })
            end
        end
    end
end

events.on_event('VimLeavePre', function()
    local current = M.current()
    if current then
        M.save_session(current)
    end
end)

events.on_user_event('LazyVimStarted', function()
    swap_sessions(nil, M.current())
end)

events.on_focus_gained(function()
    swap_sessions(settings.get(setting_name, { scope = 'instance' }), M.current())
end)

--- Get the current session with a warning if session management is disabled
---@return string|nil # the current session name or nil if not enabled
local function current_with_warning()
    local current = M.current()
    if not current then
        vim.warn('Session management is disabled in this instance.', { prefix_icon = icons.UI.SessionDelete })
    end

    return current
end

require('core.commands').register_command('Session', {
    restore = function()
        local current = current_with_warning()
        if current then
            swap_sessions(nil, current)
        end
    end,
    save = function()
        local current = current_with_warning()
        if current then
            swap_sessions(current, nil)
        end
    end,
    delete = function()
        local current = current_with_warning()
        if not current then
            return
        end

        if not M.saved(current) then
            vim.warn(string.format('Session `%s` does not exist', current), { prefix_icon = icons.UI.SessionDelete })
            return
        end

        local session_file, shada_file, custom_file = M.files(current)

        local deleted = vim.fn.delete(session_file) - vim.fn.delete(shada_file) - vim.fn.delete(custom_file)

        if deleted == 0 then
            vim.warn(string.format('Deleted session `%s`', current), { prefix_icon = icons.UI.SessionDelete })
        else
            vim.error(string.format('Error(s) occurred while deleting session `%s`', current), {
                prefix_icon = icons.UI.SessionSave,
            })
        end

        reset_ui()
    end,
}, { desc = 'Manages sessions' })

-- save session on a timer
vim.defer_fn(function()
    swap_sessions(M.current(), nil)
end, 60000)

return M
