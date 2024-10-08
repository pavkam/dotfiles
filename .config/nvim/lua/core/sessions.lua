local events = require 'core.events'
local icons = require 'ui.icons'
local settings = require 'core.settings'
local qf = require 'ui.qf'

---@class core.session
local M = {}
local session_dir = vim.fs.joinpath(vim.fs.data_dir, 'sessions')

---@type string
local setting_name = 'current_session_name'

--- Check if the session support is enabled
--- @return boolean # true if enabled, false otherwise
local function enabled()
    return vim.fn.argc() == 0 and not vim.headless
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

    local res = vim.fs.joinpath(session_dir, name)

    return res .. '.vim', res .. '.shada', res .. '.json'
end

--- Call a function with error handling
---@param what string # the name of the function
---@param session string # the name of the session
---@vararg any # the function and its arguments
---@return boolean, any # the result of the function
local function error_call(what, session, ...)
    local ok, res_or_error = pcall(...)
    if not ok then
        vim.error(
            string.format('Failed to %s for session `%s`:\n```%s```', what, session, vim.inspect(res_or_error)),
            { prefix_icon = icons.UI.Error }
        )
    end

    return ok, res_or_error
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

    error_call('save vim session', name, vim.cmd, 'mks! ' .. session_file)
    error_call('save shada', name, vim.cmd, 'wshada! ' .. shada_file)

    ---@type core.session.CustomData
    local custom = {
        settings = settings.export(),
        qf = qf.export(),
    }

    local json = vim.json.encode(custom) or '{}'
    error_call('save settings', name, vim.fs.write_text_file, custom_file, json, { throw_errors = true })

    vim.hint(string.format('Saved session `%s`', name), { prefix_icon = icons.UI.SessionSave })
end

--- Resets the UI
local function reset_ui()
    vim.cmd [[silent! tabonly!]]
    vim.cmd [[silent! %bd!]]
    vim.cmd [[silent! %bw!]]

    vim.args = {}
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
            local ok, data = error_call('restore custom data', name, vim.fn.readfile, custom_file, 'b')
            if ok then
                ---@type boolean, core.session.CustomData
                ok, data = error_call('deserialize custom data', name, vim.json.decode, data[1])
                if ok then
                    error_call('apply settings', name, settings.import, data.settings)
                    error_call('apply quickfix', name, qf.import, data.qf)
                end
            end

            error_call('restore shada', name, vim.cmd.rshada, shada_file)
            error_call('restore vim session', name, vim.cmd.source, session_file)

            vim.schedule(function()
                vim.refresh_ui()
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

-- save session on a timer
if enabled() then
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

    vim.defer_fn(function()
        swap_sessions(M.current(), nil)
    end, 60000)
end

return M
