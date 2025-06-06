local shell = require 'shell'
local lazygit = require 'lazy-git'

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
                path = vim.fs.join_paths(dir, path) --[[@as string]]
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

---@class (exact) git.HunkPreviewOpts # Options for dealing with hunk previews.
---@field window number|nil # the window to use for the operation, if nil the current window is used.
---@field line number|nil # the line number to use for the operation, if nil the current line is used.
---@field inline boolean|nil # whether to show the hunk diff inline or not.

--- Preview a hunk at a given line
---@param opts git.HunkPreviewOpts|nil # the options for the operation
function M.preview_hunk(opts)
    opts = opts or {}
    opts.window = opts.window or vim.api.nvim_get_current_win()

    assert(type(opts.line) == 'number' or opts.line == nil)

    if not package.loaded['gitsigns'] then
        return
    end

    local command = string.format('Gitsigns %s', opts.inline and 'preview_hunk_inline' or 'preview_hunk')

    vim.schedule(function()
        if opts.line == nil then
            vim.cmd(command)
        else
            ide.win[opts.window].invoke_on_line(command, opts.line)
        end
    end)
end

M.lazygit = lazygit

return M
