local lsp = require "utils.lsp"
local utils = require "utils"

local M = {}

-- root patterns to find project root if the LSP failed
M.root_patterns = {
    -- git is the end of the search
    ".git",

    -- JS/TS projects
    "package.json",

    -- Go projects
    "go.mod",
    "go.sum",

    -- Makefile-based projects
    "Makefile",

    -- Rust projects
    "Cargo.toml",

    -- Python projects
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "poetry.lock",

    -- .NET
    "*.sln"
}

function M.roots(target)
    local buffer, path = utils.expand_target(target)

    -- check for cached roots
    local valid_buffer = vim.api.nvim_buf_is_valid(buffer)
    if valid_buffer and vim.b[buffer].root_path_cache then
        return vim.b[buffer].root_path_cache
    end

    -- obtain all LSP roots
    local roots = lsp.roots(target)

    -- find also roots based on patterns
    local cwd = vim.loop.cwd()
    path = path and vim.fs.dirname(path) or cwd

    root = vim.fs.find(M.root_patterns, {
        path = path,
        upward = true,
        stop = vim.fs.normalize("~")
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

    table.sort(roots, function(a, b) return #a > #b end)

    -- cache the roots for buffer
    if valid_buffer then
        vim.b[buffer].root_path_cache = roots
    end

    return roots
end

function M.root(target, deepest)
    local roots = M.roots(target)

    if deepest then
        return roots[1]
    else
        return roots[#roots]
    end
end

function M.get_launch_json(target)
    return utils.first_found_file(M.roots(target), { '.dap.json', '.vscode/launch.json' })
end

return M
