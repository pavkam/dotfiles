local utils = require 'core.utils'

local M = {}
local session_dir = utils.join_paths(vim.fn.stdpath 'data', 'sessions')

function get_session_file_prefix()
    local name = vim.fn.getcwd()
    local branch = vim.trim(vim.fn.system 'git branch --show-current')

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

    return utils.join_paths(session_dir, full_name)
end

function M.get_session_file_name()
    return get_session_file_prefix() .. '.vim'
end

function M.get_shada_file_name()
    return get_session_file_prefix() .. '.shada'
end

function M.save_session()
    vim.fn.mkdir(session_dir, 'p')
    vim.cmd('mks! ' .. M.get_session_file_name())
    vim.cmd('wshada! ' .. M.get_shada_file_name())
end

function M.restore_session()
    local session_file_name = M.get_session_file_name()
    local shada_file_name = M.get_shada_file_name()

    if vim.fn.filereadable(session_file_name) == 1 then
        vim.cmd('source ' .. session_file_name)
    end
    if vim.fn.filereadable(shada_file_name) == 1 then
        vim.cmd('rshada ' .. shada_file_name)
    end
end

utils.on_event('VimLeavePre', function()
    M.save_session()
end)

utils.on_event('User', function()
    vim.defer_fn(M.restore_session, 0)
end, 'LazyDone')

vim.api.nvim_create_user_command('SessionSave', function()
    M.save_session()
    utils.info 'Session saved'
end, {
    desc = 'Save session',
})

return M
