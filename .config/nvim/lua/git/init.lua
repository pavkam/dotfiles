local shell = require 'core.shell'
local icons = require 'ui.icons'
local utils = require 'core.utils'

---@class git
local M = {}

--- Checks if a file is under git
---@param file_name string # the name of the file to check
---@param callback fun(under_git: boolean) # the callback to call when the command finishes
function M.check_tracked(file_name, callback)
    assert(type(file_name) == 'string' and file_name ~= '')

    if vim.fn.filereadable(file_name) == 0 then
        callback(false)
        return
    end

    shell.async_cmd('git', { 'ls-files', '--error-unmatch', file_name }, nil, function(_, code)
        callback(code == 0)
    end, { ignore_codes = { 0, 1, 128 }, cwd = vim.fn.fnamemodify(file_name, ':h') })
end

--- Returns the files that are under git
---@param dir string # the path under which to check the git status
---@param callback fun(paths: string[]) # the callback to call for each file
function M.tracked(dir, callback)
    assert(type(dir) == 'string' and dir ~= '')

    shell.async_cmd('git', { 'ls-files' }, nil, function(res, code)
        if code == 0 then
            local paths = {}
            for _, path in ipairs(res) do
                path = utils.join_paths(dir, path) --[[@as string]]
                if vim.fn.filereadable(path) == 1 then
                    table.insert(paths, path)
                end
            end

            callback(paths)
        end
    end, { ignore_codes = { 0, 1, 128 }, cwd = dir })
end

--- Gets the current git branch for a given directory
---@param dir string # the path under which to check the git branch
---@param callback fun(branch: string|nil) # the callback to call when the command finishes
function M.current_branch(dir, callback)
    assert(type(dir) == 'string' and dir ~= '')

    shell.async_cmd('git', { 'branch', '--show-current' }, nil, function(output, code)
        callback(code == 0 and output[1] or nil)
    end, { ignore_codes = { 0, 1, 128 }, cwd = dir })
end

--- Gets the current git root for a given directory
---@param dir string # the path under which to check the git branch
---@param callback fun(branch: string|nil) # the callback to call when the command finishes
function M.root(dir, callback)
    assert(type(dir) == 'string' and dir ~= '')

    shell.async_cmd('git', { 'rev-parse', '--show-toplevel' }, nil, function(output, code)
        callback(code == 0 and output[1] or nil)
    end, { ignore_codes = { 0, 1, 128 }, cwd = dir })
end

-- Add a command to run lazygit
if vim.fn.executable 'lazygit' == 1 then
    vim.api.nvim_create_user_command('Lazygit', function()
        shell.floating 'lazygit'
    end, { desc = 'Run Lazygit', nargs = 0 })

    vim.keymap.set('n', '<leader>g', function()
        vim.cmd 'Lazygit'
    end, { desc = icons.UI.Git .. ' Lazygit' })
end

return M
