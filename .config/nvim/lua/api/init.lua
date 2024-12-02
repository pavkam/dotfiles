---@class api
_G.api = {
    types = require 'api.types',
    assert = require 'api.assert',
    fs = require 'api.fs',
    process = require 'api.process',
    events = require 'api.events',
}

require 'api.vim'
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
        vim.warn(formatted)

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
