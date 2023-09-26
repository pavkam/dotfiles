local neotest_lib = require 'neotest.lib'
local git_root = ".git"

local M = {}

function M.read_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end

    local content = file:read "*a"
    file:close()

    return content
end

function M.find_root(path, ...)
    return neotest_lib.files.match_root_pattern(..., git_root)(path)
end

function M.file_exists(path)
    return neotest_lib.files.exists(path)
end

function M.get_cwd()
    return vim.fn.getcwd()
end

return M
