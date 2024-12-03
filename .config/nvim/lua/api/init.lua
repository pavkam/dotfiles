---@alias extended_type # The extended type.
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

--- Gets the type of a given value.
---@param value any # the value to get the type of.
---@return type, extended_type # the type of the value.
function _G.extended_type(value)
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

    return t, t --[[@as extended_type]]
end

-- luacheck: push ignore 122

--- Makes a table read-only.
---@generic T: table
---@param table T # the table to make read-only.
---@return T # the read-only table.
function table.freeze(table)
    assert(type(table) == 'table', 'expected a table')

    return setmetatable({}, {
        __index = table,
        __newindex = function()
            error('attempt to modify read-only table', 2)
        end,
        __metatable = false,
    })
end

--- Merges multiple tables into one.
---@vararg table|nil # the tables to merge.
---@return table # the merged table.
function table.merge(...)
    local len = select('#', ...)
    if len == 0 then
        return {}
    end

    local all = {}
    for i = 1, len do
        local a = select(i, ...)
        assert(type(a) == 'table', 'expected a tables')

        if len == 1 then
            return a
        end

        if a then
            table.insert(all, a)
        end
    end

    return vim.tbl_deep_extend('keep', unpack(all))
end

--- Coerces a value to a list.
---@generic T
---@param value T|T[]|table<any,T>|nil # any value that will be converted to a list.
---@return T[] # the listified version of the value.
function table.to_list(value)
    local _, t = extended_type(value)

    if t == 'nil' then
        return {}
    elseif t == 'list' then
        return value --[[@as table]]
    elseif t == 'table' then
        local list = {}
        for _, item in
            pairs(value --[[@as table]])
        do
            table.insert(list, item)
        end

        return list
    else
        return { value }
    end
end

--- Returns a new list that contains only unique values.
---@param list any[] # the list to make unique.
---@param key_fn (fun(value: any): any)|nil # the function to get the key from the value.
---@return any[] # the list with unique values.
function table.list_uniq(list, key_fn)
    assert {
        list = { list, 'list' },
        key_fn = { key_fn, { 'nil', 'callable' } },
    }

    local seen = {}
    local result = {}

    for _, item in ipairs(list) do
        local key = key_fn and key_fn(item) or item
        if not seen[key] then
            table.insert(result, item)
            seen[key] = true
        end
    end

    return result
end

--- Inflates a list to a table.
---@generic T: table
---@param list T[] # the list to inflate.
---@param key_fn fun(value: T): any # the function to get the key from the value.
---@return table<string, T> # the inflated table.
function table.inflate(list, key_fn)
    assert {
        list = { list, 'list' },
        key_fn = { key_fn, 'callable' },
    }

    local result = {}

    for _, value in ipairs(list) do
        local key = key_fn(value)
        result[key] = value
    end

    return result
end

-- luacheck: pop

---@class api
_G.ide = {
    assert = require 'api.assert',
    text = require 'api.text',
    file_system = require 'api.file_system',
    process = require 'api.process',
    events = require 'api.events',
    tui = require 'api.tui',
    async = require 'api.async',
    plugins = require 'api.plugins',
}

require 'api.vim.fn'
require 'api.vim.fs'
require 'api.vim.filetype'
require 'api.vim.buf'

--- Returns the formatted arguments for debugging
---@vararg any # the arguments to format
local function format_args(...)
    local objects = {}
    for _, v in pairs { ... } do
        ---@type string
        local val = 'nil'

        if type(v) == 'string' then
            val = v
        elseif type(v) == 'number' or type(v) == 'boolean' then
            val = tostring(v)
        elseif type(v) == 'table' then
            val = vim.inspect(v)
        end

        table.insert(objects, val)
    end

    return table.concat(objects, '\n')
end

---@type table<string, boolean>
local shown_messages = {}

--- Global debug function to help me debug (duh)
---@vararg any # anything to debug
function _G.dbg(...)
    local formatted = format_args(...)
    local key = vim.fn.sha256(formatted)

    if not shown_messages[key] then
        shown_messages[key] = true
        ide.tui.warn(formatted)

        vim.defer_fn(function()
            shown_messages[key] = nil
        end, 5000)
    end

    return ...
end

--- Prints the call stack if a condition is met
---@param condition any # the condition to print the call stack
---@vararg any # anything to print
function _G.who(condition, ...)
    if condition == nil or condition then
        dbg(debug.traceback(nil, 2), ...)
    end
end
