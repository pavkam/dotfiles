-- Marks: abstraction over neovim's mark system.
-- Wraps vim mark APIs into a clean OOP interface.

local Marks = Class('Marks')

function Marks:init() end

--- Get all user marks (a-z, A-Z) for a buffer.
---@param bufnr integer|nil # buffer (0 or nil for current)
---@return { mark: string, pos: { row: integer, col: integer }, file: string|nil }[]
function Marks:list(bufnr)
    bufnr = bufnr or 0
    local result = {}
    local marks = vim.fn.getmarklist(bufnr == 0 and '%' or bufnr)

    for _, m in ipairs(marks) do
        local key = m.mark:sub(2, 2)
        if key:match('^[a-zA-Z]$') then
            result[#result + 1] = {
                mark = key,
                pos = { row = m.pos[2], col = m.pos[3] },
                file = m.file,
            }
        end
    end

    -- Also get global marks
    for _, m in ipairs(vim.fn.getmarklist()) do
        local key = m.mark:sub(2, 2)
        if key:match('^[A-Z]$') then
            result[#result + 1] = {
                mark = key,
                pos = { row = m.pos[2], col = m.pos[3] },
                file = m.file,
            }
        end
    end

    return result
end

--- Set a mark at the current cursor position.
---@param mark string # single character a-z or A-Z
--- Get the line number of a mark expression.
---@param mark_expr string # mark expression (e.g. "'[", "'a", "'<")
---@return integer # 1-indexed line number (0 if mark invalid)
function Marks:line(mark_expr)
    return vim.fn.line(mark_expr)
end

function Marks:set(mark)
    assert(#mark == 1 and mark:match('^[a-zA-Z]$'), 'mark must be a-z or A-Z')
    vim.cmd('normal! m' .. mark)
end

--- Jump to a mark.
---@param mark string
function Marks:jump(mark)
    assert(#mark == 1 and mark:match('^[a-zA-Z]$'), 'mark must be a-z or A-Z')
    pcall(vim.cmd, "normal! '" .. mark)
end

--- Delete a mark.
---@param mark string
function Marks:delete(mark)
    assert(#mark == 1 and mark:match('^[a-zA-Z]$'), 'mark must be a-z or A-Z')
    pcall(vim.cmd.delmarks, mark)
end

--- Remove all global marks referencing a specific file.
---@param file string # file path to forget
function Marks:forget(file)
    for _, m in ipairs(vim.fn.getmarklist()) do
        local key = m.mark:sub(2, 2)
        if key:match('^[A-Z]$') and m.file == file then
            pcall(vim.api.nvim_del_mark, key)
        end
    end
end

--- Delete all marks in the current buffer.
function Marks:clear()
    pcall(vim.cmd, 'delmarks a-z')
end

--- Count of marks in the current buffer.
---@return integer
function Marks:count()
    return #self:list()
end

---@return string
function Marks:__tostring()
    return string.format('Marks(%d)', self:count())
end

return Marks
