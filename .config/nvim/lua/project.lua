local keys = require 'keys'
local settings = require 'settings'
local lsp = require 'lsp'
local hover = require 'hover'
local icons = require 'icons'

keys.map('n', 'K', hover, { desc = 'Show hover' })

---@class project
local M = {}

--- Checks if a parsed package.json has a dependency
---@param parsed_json table<string, any> # the parsed package.json
---@param dep_type string # the type of the dependency
---@param dependency string # the name of the dependency
---@return boolean # whether the dependency exists
local function parsed_package_json_has_dependency(parsed_json, dep_type, dependency)
    assert(type(parsed_json) == 'table')
    assert(type(dep_type) == 'string' and dep_type ~= '')
    assert(type(dependency) == 'string' and dependency ~= '')

    if parsed_json[dep_type] then
        for key, _ in pairs(parsed_json[dep_type]) do
            if key == dependency then
                return true
            end
        end
    end

    return false
end

--- Reads a package.json for a given target
---@param target vim.fn.Target # the target to read the package.json for
---@return table<string, any>|nil # the parsed package.json
local function read_package_json(target)
    local full_name = vim.fs.first_found_file(M.roots(target), 'package.json')

    local json_content = full_name and vim.fn.join(vim.fn.readfile(full_name), '\n')
    return json_content and vim.json.decode(json_content)
end

--- Returns the type of the project
---@param target vim.fn.Target # the target to get the type for
---@return string|nil # the type of the project
local function dotnet_type(target)
    local root = M.root(target)

    ---@diagnostic disable-next-line: param-type-mismatch
    if root and #vim.fn.globpath(root, '*.sln', 0, 1) > 0 then
        return 'dotnet'
    end

    return nil
end

--- Returns the type of the project
---@param target vim.fn.Target # the target to get the type for
---@return string|nil # the type of the project
local function go_type(target)
    if vim.fs.first_found_file(M.roots(target), { 'go.mod', 'go.sum' }) then
        return 'go'
    end

    return nil
end

local python_root_patterns = {
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'poetry.lock',
}

--- Returns the type of the project
---@param target vim.fn.Target # the target to get the type for
---@return string|nil # the type of the project
local function python_type(target)
    if vim.fs.first_found_file(M.roots(target), python_root_patterns) then
        return 'python'
    end

    return nil
end

--- Returns the type of the project
---@param target string|integer|nil # the target to get the type for
---@return string|nil # the type of the project
local function js_type(target)
    local package = read_package_json(target)

    if package then
        if parsed_package_json_has_dependency(package, 'dependencies', 'typescript') then
            if parsed_package_json_has_dependency(package, 'dependencies', 'react') then
                return 'typescriptreact'
            end

            return 'typescript'
        else
            if parsed_package_json_has_dependency(package, 'dependencies', 'react') then
                return 'javascriptreact'
            end

            return 'javascript'
        end
    end

    return nil
end

M.js_types = {
    'javascript',
    'typescript',
    'javascriptreact',
    'typescriptreact',
}

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
---@param target vim.fn.Target # the target to get the roots for
---@return string[] # the list of roots
function M.roots(target)
    local buffer, path, is_real = vim.fn.expand_target(target)
    if not vim.api.nvim_buf_is_valid(buffer) then
        return {}
    end

    local setting_name = 'root_paths'

    -- check for cached roots
    local roots = is_real and settings.get(setting_name, { buffer = buffer, scope = 'transient' })
    ---@cast roots string[]
    if roots then
        return roots
    end

    roots = {}
    local function add(root)
        if not vim.tbl_contains(roots, root) then
            roots[#roots + 1] = root
        end
    end

    -- obtain all LSP roots
    for _, val in ipairs(lsp.roots(target)) do
        add(val)
    end

    -- find also roots based on patterns
    local cwd = vim.uv.cwd()
    path = path and vim.fs.dirname(path) or cwd

    -- now add all the roots from the patterns
    local matched_files = vim.fs.find(M.root_patterns, {
        path = path,
        upward = true,
        limit = math.huge,
        stop = vim.uv.os_homedir(),
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
    if is_real then
        settings.set(setting_name, roots, { buffer = buffer, scope = 'transient' })
    end

    return roots
end

--- Returns the primary root for a given target
---@param target vim.fn.Target # the target to get the root for
---@param deepest boolean|nil # whether to return the deepest or the shallowest root (default is deepest)
---@return string|nil # the root
function M.root(target, deepest)
    local roots = M.roots(target)
    if #roots == 0 then
        return nil
    end

    if deepest == nil then
        deepest = true
    end

    if deepest then
        return roots[1]
    else
        return roots[#roots]
    end
end

--- Returns the path components for a given target
---@param target vim.fn.Target # the target to get the path components for
---@return { work_space_path: string, file_path: string, work_space_name: string } # the path components
function M.path_components(target)
    local root = M.root(target)
    if not root then
        _, root = vim.fn.expand_target(target)
    end

    local head = vim.fn.fnamemodify(root, ':p:h')
    local ws = vim.fn.fnamemodify(head, ':p:h')
    local tail = vim.fn.fnamemodify(root, ':p:t')

    return { work_space_path = head, file_path = tail, work_space_name = ws }
end

--- Formats a relative path to a given target
---@param target vim.fn.Target # the target to get the settings path for
---@return string # the formatted relative path
function M.format_relative(target)
    ---@type string|nil
    local root = M.root(target)
    local _, path = vim.fn.expand_target(target)
    return root and vim.fs.format_relative_path(root, path) or path
end

--- Returns the path to the Neovim settings directory for a given target
---@param target vim.fn.Target # the target to get the settings path for
---@return string|nil # the path to the settings directory
function M.nvim_settings_path(target)
    ---@type string|nil
    local root = M.root(target)
    return root and vim.fs.joinpath(root, '.nvim') or nil
end

--- Returns the path to the launch.json file for a given target
---@param target vim.fn.Target # the target to get the launch.json for
---@return string|nil # the path to the launch.json file
function M.get_launch_json(target)
    local path = M.nvim_settings_path(target)
    return path and vim.fs.joinpath(path, 'dap.json')
        or vim.fs.first_found_file(M.roots(target), { '.vscode/launch.json' })
end

--- Returns the type of the project
---@param target vim.fn.Target # the target to get the type for
---@return string|nil # the type of the project
function M.type(target)
    return (js_type(target) or go_type(target) or python_type(target) or dotnet_type(target))
end

local golangci_root_patterns = {
    '.golangci.yml',
    '.golangci.yaml',
    '.golangci.toml',
    '.golangci.json',
}

--- Returns the path to the golangci file for a given target
---@param target vim.fn.Target # the target to get the golangci file for
---@return string|nil # the path to the golangci file
function M.get_golangci_config(target)
    return vim.fs.first_found_file(M.roots(target), golangci_root_patterns)
end

--- Checks if a target has a dependency
---@param target vim.fn.Target # the target to check the dependency for
---@param dependency string # the name of the dependency
---@return boolean # whether the dependency exists
function M.js_has_dependency(target, dependency)
    local parsed_json = read_package_json(target)
    if not parsed_json then
        return false
    end

    return (
        parsed_package_json_has_dependency(parsed_json, 'dependencies', dependency)
        or parsed_package_json_has_dependency(parsed_json, 'devDependencies', dependency)
    )
end

--- Gets the path to a binary for a given target
---@param target vim.fn.Target # the target to get the binary path for
---@param bin string|nil # the path of the binary
function M.get_js_bin_path(target, bin)
    local sub = vim.fs.joinpath('node_modules', '.bin', bin)
    ---@cast sub string

    return vim.fs.first_found_file(M.roots(target), sub)
end

local eslint_root_patterns = {
    '.eslintrc.json',
    '.eslintrc.js',
    'eslint.config.js',
    'eslint.config.json',
}

--- Gets the path to the eslint config for a given target
---@param target vim.fn.Target # the target to get the eslint config for
---@return string|nil # the path to the eslint config
function M.get_eslint_config_path(target)
    return vim.fs.first_found_file(M.roots(target), eslint_root_patterns)
end

settings.register_toggle('diagnostics_enabled', function(enabled, buffer)
    if not enabled then
        vim.diagnostic.enable(false, { bufnr = buffer })
    else
        vim.diagnostic.enable(true, { bufnr = buffer })
    end
end, {
    icon = icons.Diagnostics.Prefix,
    name = 'Diagnostics',
    scope = { 'global', 'buffer' },
    default = true,
})

settings.register_toggle('inlay_hint_enabled', function(enabled, buffer)
    if not enabled then
        vim.lsp.inlay_hint.enable(false, { bufnr = buffer })
    else
        vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
    end
end, {
    icon = icons.Diagnostics.LSP.Hint,
    name = 'Inlay hints',
    scope = { 'global', 'buffer' },
    default = true,
})

settings.register_toggle('code_lens_enabled', function(enabled, buffer)
    if not enabled then
        vim.lsp.codelens.clear(nil, buffer)
    else
        vim.lsp.codelens.refresh { bufnr = buffer }
    end
end, {
    icon = icons.UI.CodeLens,
    name = 'Code Lense',
    scope = { 'global', 'buffer' },
    default = true,
})

settings.register_toggle('semantic_tokens_enabled', function(enabled, buffer)
    if not buffer then
        return
    end

    local clients = lsp.active_for_buffer(buffer)
    local fn = enabled and vim.lsp.semantic_tokens.start or vim.lsp.semantic_tokens.stop

    vim.iter(clients):each(function(client)
        fn(buffer, client.id)
    end)
end, {
    icon = icons.UI.CodeLens,
    name = 'Semantic Tokens',
    scope = { 'global', 'buffer' },
    default = true,
})

return M
