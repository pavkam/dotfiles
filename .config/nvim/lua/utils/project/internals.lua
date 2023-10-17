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

function M.root(target)
    local root = lsp.root(target)

    if not root then
        local _, path = utils.expand_target(target)
        path = path and vim.fs.dirname(path) or vim.loop.cwd()

        root = vim.fs.find(M.root_patterns, {
            path = path,
            upward = true,
            stop = vim.fs.normalize("~")
        })[1]

        root = root and vim.fs.dirname(root) or path
    end

    return root
end

function M.get_launch_json(target)
    local root = M.root(target)
    local option = root and utils.any_file_exists(root, { '.dap.json', '.vscode/launch.json' })

    return option and utils.join_paths(root, option)
end

return M
