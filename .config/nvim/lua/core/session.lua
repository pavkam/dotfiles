local utils = require 'core.utils'
local icons = require 'ui.icons'

---@class core.session
local M = {}
local session_dir = utils.join_paths(vim.fn.stdpath 'data' --[[@as string]], 'sessions') --[[@as string]]
local current_session_name

--- Get the current session name
---@return string
local function get_session_name()
    local name = vim.fn.getcwd()
    local branch = vim.trim(vim.fn.system 'git branch --show-current')

    ---@type string
    local full_name

    if vim.v.shell_error == 0 then
        full_name = name .. '-' .. branch
    else
        full_name = name
    end

    -- escape special characters in full name (URL encoding)
    full_name = string.gsub(full_name, '([^%w %-%_%.%~])', function(c)
        return string.format('_%02X', string.byte(c))
    end)
    full_name = string.gsub(full_name, ' ', '+')

    local res = utils.join_paths(session_dir, full_name)
    ---@cast res string

    return res
end

--- Save the current session
---@param name string # the name of the session
function M.save_session(name)
    utils.info(icons.UI.SessionSave .. ' Saving current session')

    vim.fn.mkdir(session_dir, 'p')

    vim.cmd('mks! ' .. name .. '.vim')
    vim.cmd('wshada! ' .. name .. '.shada')
end

--- Restore a session
---@param name string # the name of the session
function M.restore_session(name)
    -- restore session and shada files
    local session_file_name = name .. '.vim'
    local shada_file_name = name .. '.shada'

    if vim.fn.filereadable(session_file_name) == 1 and vim.fn.filereadable(shada_file_name) == 1 then
        vim.schedule(function()
            -- close all windows, tabs and buffers
            vim.cmd [[silent! tabonly!]]
            vim.cmd [[silent! %bd!]]
            vim.cmd [[silent! %bw!]]

            vim.cmd('source ' .. session_file_name)
            vim.cmd('rshada ' .. shada_file_name)

            utils.refresh_ui()

            utils.info(string.format(icons.UI.SessionRestore .. ' Restored session', current_session_name))
        end)
    end
end

utils.on_event('VimLeavePre', function()
    M.save_session(get_session_name())
end)

utils.on_event('User', function()
    -- do not restore session if there is a file to open
    if vim.fn.argc() == 1 then
        return
    end

    current_session_name = get_session_name()
    M.restore_session(current_session_name)
end, 'LazyDone')

utils.on_event({ 'FocusGained', 'TermClose', 'TermLeave', 'DirChanged' }, function()
    local new_session_name = get_session_name()
    if current_session_name ~= new_session_name then
        M.save_session(current_session_name)
        M.restore_session(new_session_name)

        current_session_name = new_session_name
    end
end)

vim.api.nvim_create_user_command('SessionSave', function()
    M.save_session(current_session_name)
    utils.info 'Session saved'
end, {
    desc = 'Save session',
})

vim.api.nvim_create_user_command('SessionRestore', function()
    M.restore_session(current_session_name)
    utils.info 'Session restored'
end, {
    desc = 'Restore session',
})

-- save session on a timer
vim.defer_fn(function()
    M.save_session(current_session_name)
end, 60000)

return M
