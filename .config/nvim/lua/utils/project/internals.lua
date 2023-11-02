local lsp = require 'utils.lsp'
local utils = require 'utils'
local settings = require 'utils.settings'

local setting_name = 'root_paths'

local M = {}

-- root patterns to find project root if the LSP failed
M.root_patterns = {
    -- git is the end of the search
    '.git',

    -- JS/TS projects
    'package.json',

    -- Go projects
    'go.mod',
    'go.sum',

    -- Makefile-based projects
    'Makefile',

    -- Rust projects
    'Cargo.toml',

    -- Python projects
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'poetry.lock',

    -- lua / neovim
    'lazy-lock.json',
    '.luarc.json',
    '.luarc.jsonc',
    '.luacheckrc',
    '.stylua.toml',
    'stylua.toml',
    'selene.toml',
    'selene.yml',

    -- .NET
    '*.sln',
}

--- Returns the project roots for a given target
---@param target string|integer|nil # the target to get the roots for
---@return string[] # the list of roots
function M.roots(target)
    local buffer, path = utils.expand_target(target)

    -- check for cached roots
    local roots = settings.get_transient_for_buffer(buffer, setting_name)

    ---@cast roots string[]
    if roots then
        return roots
    end

    -- obtain all LSP roots
    roots = lsp.roots(target)

    -- find also roots based on patterns
    local cwd = vim.loop.cwd()
    path = path and vim.fs.dirname(path) or cwd

    local root = vim.fs.find(M.root_patterns, {
        path = path,
        upward = true,
        stop = vim.fs.normalize '~',
    })[1]

    -- add new root to the list
    root = root and vim.fs.dirname(root) or path
    if not utils.list_contains(roots, root) then
        roots[#roots + 1] = root
    end

    -- add the cwd to the list as well, for the last case scenario
    if not utils.list_contains(roots, cwd) then
        roots[#roots + 1] = cwd
    end

    table.sort(roots, function(a, b)
        return #a > #b
    end)

    -- cache the roots for buffer
    settings.set_transient_for_buffer(buffer, setting_name, roots)
    return roots
end

--- Returns the primary root for a given target
---@param target string|integer|nil # the target to get the root for
---@param deepest boolean|nil # whether to return the deepest or the shallowest root
---@return string|nil # the root
function M.root(target, deepest)
    local roots = M.roots(target)

    if deepest then
        return roots[1]
    else
        return roots[#roots]
    end
end

--- Returns the path to the launch.json file for a given target
---@param target string|integer|nil # the target to get the launch.json for
---@return string|nil # the path to the launch.json file
function M.get_launch_json(target)
    return utils.first_found_file(M.roots(target), { '.dap.json', '.vscode/launch.json' })
end

return M
