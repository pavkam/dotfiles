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
---@return api.types.Type # the type of the value.
function M.get(value)
    local t = type(value)
    if t == 'table' then
        if vim.islist(value) then
            return 'list'
        end

        local m = getmetatable(t)
        if m and type(m.__call) == 'function' then
            return 'callable'
        end
    elseif t == 'number' then
        if value % 1 == 0 then
            return 'integer'
        end
    elseif t == 'function' then
        return 'callable'
    end

    return t --[[@as api.types.Type]]
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

local valid_types = {
    ['nil'] = true,
    ['string'] = true,
    ['number'] = true,
    ['boolean'] = true,
    ['table'] = true,
    ['thread'] = true,
    ['userdata'] = true,
    ['integer'] = true,
    ['list'] = true,
    ['callable'] = true,
}

--- Checks if a given type is valid.
---@param type api.types.Type # the type of the items in the list.
---@return boolean # whether the type is valid.
function M.is_valid(type)
    return valid_types[type] == true
end

--- Checks if a items in a list are of a given type.
---@param list any[] # the list to check.
---@param type api.types.Type # the type of the items in the list.
---@return boolean # whether the items in the list are of the given type.
function M.is_list_of(list, type)
    assert(vim.islist(list), 'expected a list')
    assert(M.is_valid(type), 'invalid type')

    for _, item in ipairs(list) do
        if M.get(item) ~= type then
            return false
        end
    end

    return true
end

return M.freeze_table(M)
