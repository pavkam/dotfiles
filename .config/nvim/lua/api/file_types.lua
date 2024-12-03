-- Provides utilities for working with different file types.
---@class api.file_types
local M = {}

local file_system = require 'api.file_system'

---@type table<string, string>
local file_to_file_type = {}

--- Gets the file type of a file.
---@param path string # the path to the file to get the type for.
---@return string|nil # the file type or nil if the file type could not be determined.
function M.detect(path)
    assert(type(path) == 'string' and path ~= '')
    path = file_system.expand_path(path) or path

    ---@type string|nil
    local file_type = file_to_file_type[path]
    if file_type then
        return file_type
    end

    file_type = vim.filetype.match { filename = path }
    if not file_type then
        for _, buf in ipairs(vim.fn.getbufinfo()) do
            if file_system.expand_path(buf.name) == path or buf.name == path then
                return vim.filetype.match { buf = buf.bufnr }
            end
        end

        local bufn = vim.fn.bufadd(path)
        vim.fn.bufload(bufn)

        file_type = vim.filetype.match { buf = bufn }

        vim.api.nvim_buf_delete(bufn, { force = true })
    end

    file_to_file_type[path] = file_type

    return file_type
end

return table.freeze(M)
