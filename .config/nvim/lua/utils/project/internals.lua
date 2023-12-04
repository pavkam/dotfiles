local lsp = require 'utils.lsp'
local utils = require 'utils'
local settings = require 'utils.settings'

local setting_name = 'root_paths'

---@class utils.project.internals
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
    local roots = settings.get(setting_name, { buffer = buffer, transient = true })
    ---@cast roots string[]
    if roots then
        return roots
    end

    roots = {}
    local function add(root)
        if not utils.list_contains(roots, root) then
            roots[#roots + 1] = root
        end
    end

    -- obtain all LSP roots
    for _, val in ipairs(lsp.roots(target)) do
        add(val)
    end

    -- find also roots based on patterns
    local cwd = vim.loop.cwd()
    path = path and vim.fs.dirname(path) or cwd

    -- now add all the roots from the patterns
    local matched_files = vim.fs.find(M.root_patterns, {
        path = path,
        upward = true,
        limit = math.huge,
        stop = vim.loop.os_homedir(),
    })

    for _, matched_file in ipairs(matched_files) do
        add(vim.fs.dirname(matched_file))
    end

    -- add the cwd to the list for the last case scenario (only if no other roots were found)
    if #roots == 0 then
        add(cwd)
    end

    table.sort(roots, function(a, b)
        return #a > #b
    end)

    -- cache the roots for buffer
    settings.set(setting_name, roots, { buffer = buffer, transient = true })
    return roots
end

--- Returns the primary root for a given target
---@param target string|integer|nil # the target to get the root for
---@param deepest boolean|nil # whether to return the deepest or the shallowest root (default is deepest)
---@return string|nil # the root
function M.root(target, deepest)
    local roots = M.roots(target)

    if deepest == nil then
        deepest = true
    end

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
