---@alias api.types.Type # The extended type.
---| 'nil' # a nil value.
---| 'string' # a string.
---| 'number' # a number.
---| 'boolean' # a boolean.
---| 'table' # a table.
---| 'thread' # a thread.
---| 'userdata' # userdata.
---| 'integer' # an integer.
---| 'list' # a list.
---| 'callable' # a callable.

--- Handling of values of different types.
---@class api.types
local M = {}

--- Gets the type of a given value.
---@param value any # the value to get the type of.
---@return type, api.types.Type # the type of the value.
function M.get(value)
    local t = type(value)
    if t == 'table' then
        if vim.islist(value) then
            return t, 'list'
        end

        local m = getmetatable(t)
        if m and type(m.__call) == 'function' then
            return t, 'callable'
        end
    elseif t == 'number' then
        if value % 1 == 0 then
            return t, 'integer'
        end
    elseif t == 'function' then
        return t, 'callable'
    end

    return t, t --[[@as api.types.Type]]
end

--- Makes a table read-only.
---@generic T: table
---@param table T # the table to make read-only.
---@return T # the read-only table.
function M.freeze_table(table)
    assert(type(table) == 'table', 'expected a table')

    return setmetatable({}, {
        __index = table,
        __newindex = function()
            error('attempt to modify read-only table', 2)
        end,
        __metatable = false,
    })
end

return M.freeze_table(M)
