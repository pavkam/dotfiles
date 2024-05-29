local utils = require 'core.utils'
local icons = require 'ui.icons'
local settings = require 'core.settings'

---@class core.session
local M = {}
local session_dir = utils.join_paths(vim.fn.stdpath 'data' --[[@as string]], 'sessions') --[[@as string]]

---@type string
local setting_name = 'current_session_name'

--- Check if the session support is enabled
--- @return boolean # true if enabled, false otherwise
local function enabled()
    return vim.fn.argc() == 0
end

--- Get the current session name
---@return string
local function get_session_name()
    local git_root = vim.trim(vim.fn.system 'git rev-parse --show-toplevel')
    local full_name = vim.v.shell_error == 0 and git_root or vim.fn.getcwd()

    local git_branch = vim.trim(vim.fn.system 'git branch --show-current')
    full_name = vim.v.shell_error == 0 and full_name .. '-' .. git_branch or full_name

    return full_name
end

--- Encode the session name as file paths
---@param name string # the name of the session
---@return string, string, string # the session file paths
local function encode_session_name(name)
    assert(type(name) == 'string')

    -- escape special characters in full name (URL encoding)
    name = string.gsub(name, '([^%w %-%_%.%~])', function(c)
        return string.format('_%02X', string.byte(c))
    end)
    name = string.gsub(name, ' ', '+')

    local res = utils.join_paths(session_dir, name)
    ---@cast res string

    return res .. '.vim', res .. '.shada', res .. '.json'
end

--- Save the current session
---@param name string # the name of the session
function M.save_session(name)
    assert(type(name) == 'string')

    local session_file, shada_file, settings_file = encode_session_name(name)

    vim.fn.mkdir(session_dir, 'p')

    vim.cmd('mks! ' .. session_file)
    vim.cmd('wshada! ' .. shada_file)
    vim.fn.writefile({ settings.serialize_to_json() }, settings_file, 'bs')

    utils.hint(string.format('%s Saved session `%s`', icons.UI.SessionSave, name))
end

--- Restore a session
---@param name string # the name of the session
function M.restore_session(name)
    assert(type(name) == 'string')

    local session_file, shada_file, settings_file = encode_session_name(name)

    if vim.fn.filereadable(session_file) == 1 and vim.fn.filereadable(shada_file) == 1 and vim.fn.filereadable(settings_file) == 1 then
        -- close all windows, tabs and buffers
        vim.cmd [[silent! tabonly!]]
        vim.cmd [[silent! %bd!]]
        vim.cmd [[silent! %bw!]]

        vim.schedule(function()
            local ok, data = pcall(vim.fn.readfile, settings_file, 'b')
            if not ok then
                utils.error(string.format('%s Failed to restore settings for session `%s`', icons.UI.SessionSave, name))
            end

            settings.deserialize_from_json(data[1])

            ok = pcall(vim.cmd.source, session_file)
            if not ok then
                utils.error(string.format('%s Failed to restore vim session `%s`', icons.UI.SessionSave, name))
            end

            ok = pcall(vim.cmd.rshada, shada_file)
            if not ok then
                utils.error(string.format('%s Failed to restore shada for session `%s`', icons.UI.SessionSave, name))
            end

            vim.schedule(function()
                utils.refresh_ui()
                utils.hint(string.format('%s Restored session `%s`', icons.UI.SessionSave, name))
            end)
        end)
    end
end

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

utils.on_event('VimLeavePre', function()
    if enabled() then
        M.save_session(get_session_name())
    end
end)

utils.on_user_event('LazyDone', function()
    swap_sessions(nil, get_session_name())
end)

utils.on_focus_gained(function()
    swap_sessions(settings.get(setting_name, { scope = 'instance' }), get_session_name())
end)

utils.register_function('Session', 'Manage session', {
    restore = function()
        swap_sessions(nil, get_session_name())
    end,
    save = function()
        swap_sessions(get_session_name(), nil)
    end,
    delete = function()
        local name = get_session_name()
        local session_file, shada_file, settings_file = encode_session_name(name)

        local deleted = vim.fn.delete(session_file) - vim.fn.delete(shada_file) - vim.fn.delete(settings_file)

        if deleted == 0 then
            utils.warn(string.format('%s Deleted session `%s`', icons.UI.SessionSave, name))
        else
            utils.error(string.format('%s Error(s) occurred while deleting session `%s`', icons.UI.SessionSave, name))
        end
    end,
})

-- save session on a timer
vim.defer_fn(function()
    swap_sessions(get_session_name(), nil)
end, 60000)

return M
