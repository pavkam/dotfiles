local lsp = require("utils.lsp")

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
}

function M.get_project_root_dir(path)
    path = path or vim.api.nvim_buf_get_name(0)

    local root = nil --lsp.get_lsp_root_dir(path)

    if not root then
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

return M
