local M = {}

--- Gets all files in the oldfiles list
---@return string[] # a list of file names
function M.all()
    return vim.v.oldfiles
end

--- Forget all a file in the oldfiles list
---@param file string # the file to forget
function M.forget(file)
    assert(type(file) == 'string' and file ~= '')
    for i, old_file in ipairs(vim.v.oldfiles) do
        if old_file == file then
            vim.cmd('call remove(v:oldfiles, ' .. (i - 1) .. ')')
            break
        end
    end
end

--- Forget all files in the oldfiles list
function M.clear()
    vim.cmd [[
        let v:oldfiles = []
    ]]
end

return M
