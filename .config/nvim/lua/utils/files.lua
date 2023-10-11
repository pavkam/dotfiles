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
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

function M.any_file_exists(base_path, files)
    for _, file in ipairs(files) do
        if M.file_exists(vim.fs.joinpath(base_path, file)) then
            return file
        end
    end

    return nil
end

function M.get_cwd()
    return vim.fn.getcwd()
end

return M
