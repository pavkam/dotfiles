_G.inspect = vim.inspect

---@alias xtype # The extended type.
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
---@return type, xtype # the type of the value.
function _G.xtype(value)
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

    return t, t --[[@as xtype]]
end

---@alias xassert_type # The assertion condition.
---| xtype # the base type.
---| xassert_type[] # a list of types.
---| { [1]: 'list', ['*']: xassert_type|nil, ['<']: integer|nil, ['>']: integer|nil  } # a list of values.
---| { [1]: 'number'|'integer', ['<']: integer|nil, ['>']: integer|nil } # a number.
---| { [1]: 'number'|'integer'|'string', ['*']: string|nil, ['<']: integer|nil, ['>']: integer|nil } # a string.
---| { [string]: xassert_type } # a sub-table.

---@class (exact) xassert_entry # An assertion entry.
---@field [1] any # the value to assert.
---@field [2] xassert_type # the type of the value.

---@alias xassert_schema # An assertion schema.
---| { [string]: xassert_entry } # The field to assert.

---@class (exact) xassert_error # The error of a validation.
---@field field string|nil # the field that failed the validation.
---@field expected_type xtype # the expected type.
---@field actual_type xtype # the actual type.
---@field message string # the message to display.

-- Validates a given schema.
---@param parent_field_name string|nil # the key to assert.
---@param schema xassert_schema # the schema to validate.
---@return xassert_error[] # the result of the validation.
local function validate(parent_field_name, schema)
    if type(schema) ~= 'table' then
        return {
            {
                field = parent_field_name,
                expected_type = 'table',
                actual_type = type(schema),
                message = 'invalid schema',
            },
        }
    end

    ---@type xassert_error[]
    local errors = {}

    for key, entry in pairs(schema) do
        local field_name = parent_field_name and string.format('%s.%s', parent_field_name, tostring(key))
            or tostring(key)

        if xtype(entry) ~= 'table' then
            table.insert(errors, {
                field = field_name,
                expected_type = 'table',
                actual_type = type(entry),
                message = 'invalid schema entry',
            })

            goto continue
        end

        local field_value = entry[1]
        local field_schema = entry[2]
        local field_value_raw_type, field_value_type = xtype(field_value)
        local field_schema_raw_type, field_schema_type = xtype(field_schema)

        if field_schema_type == 'string' then --[[@cast field_schema string]]
            if field_value == 'list' and field_schema == 'table' and table.is_empty(field_value) then
                goto continue
            end

            if field_value_type ~= field_schema then
                table.insert(errors, {
                    field = field_name,
                    expected_type = field_schema,
                    actual_type = field_value_type,
                    message = 'invalid type',
                })
            end

            goto continue
        end

        if field_schema_raw_type ~= 'table' then
            table.insert(errors, {
                field = field_name,
                expected_type = 'table',
                actual_type = field_schema_raw_type,
                message = 'invalid schema entry',
            })

            goto continue
        end

        ---@cast field_schema table
        if field_schema_type == 'table' and xtype(field_schema[1]) == 'string' then
            local possible_type = field_schema[1] --[[@as xtype]]
            local lt = xtype(field_schema['<']) == 'number' and field_schema['<'] or nil
            local gt = xtype(field_schema['>']) == 'number' and field_schema['>'] or nil

            if possible_type == 'list' then
                if field_value_type ~= possible_type then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = possible_type,
                        actual_type = field_value_type,
                        message = 'not a list',
                    })

                    goto continue
                end

                if lt and #field_value > lt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('list is too long (expected at most `%d`)', lt),
                    })

                    goto continue
                end

                if gt and #field_value < gt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('list is too short (expected at least `%d`)', gt),
                    })

                    goto continue
                end

                local list_item_schema = field_schema['*']

                if list_item_schema ~= nil then
                    ---@type xassert_schema
                    local composite_schema = {}
                    for i, v in ipairs(field_value) do
                        composite_schema[tostring(i)] = { v, list_item_schema }
                    end

                    table.list_merge(errors, validate(field_name, composite_schema))
                end

                goto continue
            end

            if possible_type == 'integer' or possible_type == 'number' then
                if field_value_type ~= possible_type then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = possible_type,
                        actual_type = field_value_type,
                        message = 'invalid type',
                    })

                    goto continue
                end

                if lt and field_value > lt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('value is too large (expected at most `%d`)', lt),
                    })

                    goto continue
                end

                if gt and field_value < gt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('value is too small (expected at least `%d`)', gt),
                    })

                    goto continue
                end

                goto continue
            end

            if possible_type == 'string' then
                if field_value_type ~= possible_type then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = possible_type,
                        actual_type = field_value_type,
                        message = 'invalid type',
                    })

                    goto continue
                end

                if lt and #field_value > lt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('string is too long (expected at most `%d`)', lt),
                    })

                    goto continue
                end

                if gt and #field_value < gt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('string is too short (expected at least `%d`)', gt),
                    })

                    goto continue
                end

                local string_match = xtype(field_schema['*']) == 'string' and field_schema['*'] or nil
                if string_match ~= nil and not field_value:match(string_match) then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('string does not match pattern `%s`', string_match),
                    })

                    goto continue
                end

                goto continue
            end
        end

        if field_schema_type == 'list' then
            local all_inner_errors = {}
            for i, candidate_schema in ipairs(field_schema) do
                local inner_errors = validate(field_name, { [tostring(i)] = { field_value, candidate_schema } })

                if #inner_errors == 0 then
                    all_inner_errors = {}
                    break
                else
                    table.insert(all_inner_errors, inner_errors)
                end
            end

            errors = table.list_merge(errors, all_inner_errors)

            goto continue
        end

        if field_value_raw_type ~= 'table' then
            table.insert(errors, {
                field = field_name,
                expected_type = 'table | list',
                actual_type = field_value_type,
                message = 'invalid type',
            })

            goto continue
        end

        ---@type xassert_schema
        local composite_schema = {}
        for k, v in pairs(composite_schema) do
            composite_schema[k] = { field_value[k], v }
        end

        errors = table.list_merge(errors, validate(field_name, composite_schema))

        ::continue::
    end

    return errors
end


-- Formats the errors of a validation.
---@param errors xassert_error[] # the errors to format.
---@return string # the formatted errors.
local format_assert_error = function(errors)
    local formatted = 'assert failed:'
    for _, error in ipairs(errors) do
        formatted = formatted
            .. string.format(
                '\n  - [`%s`]: %s. expected type(s) `%s`, got `%s`.',
                error.field,
                error.message,
                error.expected_type,
                error.actual_type
            )
    end

    return formatted
end


-- Asserts the validity of a schema.
---@param input xassert_schema # the input to assert.
_G.xassert = function(input)
    local errors = validate(nil, input)
    if #errors > 0 then
        error(format_assert_error(errors))
    end
end

-- luacheck: push ignore 121 122 113

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

---@class synthetic_table_opts # The options for a synthetic table.
---@field getter fun(key: any): boolean, any # the getter function.
---@field setter (fun(key: any, value: any): boolean)|nil # the setter function (optional).
---@field enumerate (fun(): any[])|nil # the enumeration function (optional).
---@field store boolean|nil # whether to cache the values (default `true`).

--- Creates a new synthetic table.
---@generic T: table
---@param table T # the table to make synthetic.
---@param opts synthetic_table_opts # the options for the synthetic table.
---@return T # the synthetic table.
function table.synthetic(table, opts)
    return setmetatable(table, {
        __index = function(t, key)
            local value = rawget(t, key)
            if value == nil then
                local ok
                ok, value = opts.getter(key)
                if not ok then
                    error(string.format('Unknown property %s.', inspect(key)))
                end

                if opts.store ~= false then
                    rawset(t, key, value)
                end
            end

            return value
        end,
        __newindex = function(t, key, value)
            if not opts.setter then
                error(string.format('Property %s is read-only.', inspect(key)))
            end

            local ok = opts.setter(key, value)
            if not ok then
                error(string.format('Unknown property %s.', inspect(key)))
            end

            if opts.store ~= false then
                rawset(t, key, value)
            end
        end,
        __pairs = opts.enumerate and function(t)
            local keys = opts.enumerate()
            local i = 0

            return function()
                i = i + 1

                local key = keys[i]
                if key == nil then
                    return nil
                end

                local val = t[key]
                if val == nil then
                    local ok
                    ok, val = opts.getter(key)
                    if not ok then
                        error(string.format('Unknown property %s.', inspect(key)))
                    end
                    if opts.store ~= false then
                        rawset(t, key, val)
                    end
                end
                return key, val
            end
        end,
    })
end

---@class smart_table_prop # The property for a smart table.
---@field get fun(entity: any, key: string): any # the getter function.
---@field set (fun(entity: any, key: string, value: any)) | nil # the setter function (optional).

---@class smart_table_opts # The options for a synthetic table.
---@field enumerate fun(): any[] # enumerate members.
---@field functions table<string, fun(entity: any, ...): any> # the functions for the smart table.
---@field properties table<string, smart_table_prop> # the properties for the smart table.

--- Creates a new smart table.
---@param opts smart_table_opts # the options for the smart table.
---@return table # the smart table.
function table.smart(opts)
    xassert {
        opts = {
            opts,
            {
                enumerate = 'callable',
                functions = 'table', --TODO: make the assrt allow to check for table key/val
                properties = 'table',
            },
        },
    }

    --TODO: make smarter

    local function make(entity)
        return table.synthetic({}, {
            getter = function(key)
                local fn = opts.functions[key]
                if fn then
                    return true, function(...)
                        return fn(entity, ...)
                    end
                end

                local prop = opts.properties[key]
                if prop then
                    return true, prop.get(entity, key)
                end

                return false, nil
            end,
            setter = function(key, value)
                local prop = opts.properties[entity]
                if prop and prop.set then
                    prop.set(entity, key, value)
                    return true
                end

                return false
            end,
            enumerate = function()
                return table.list_merge(table.keys(opts.functions), table.keys(opts.properties))
            end,
        })
    end

    return setmetatable({}, {
        __index = function(t, entity)
            local value = rawget(t, entity)
            if value == nil then
                value = make(entity)
                rawset(t, entity, value)
            end

            return value
        end,
        __newindex = function()
            error('Cannot set a value on a smart table.', 2)
        end,
        __pairs = function()
            return opts.enumerate()
        end,
    })
end

--- Merges multiple tables into one.
---@vararg table|nil # the tables to merge.
---@return table # the merged table.
function table.merge(...)
    local list = table.to_list { ... }
    xassert {
        args = { list, { 'list', ['*'] = { 'list', 'table' } } },
    }

    ---@type table
    local result

    if #list == 0 then
        result = {}
    elseif #list == 1 then
        result = list[1] --[[@as table]]
    else
        -- TODO: make my own
        result = vim.tbl_extend('force', unpack(list))
    end

    return result
end

-- Merge multiple lists into one.
---@generic T: table
---@param ... T # the lists to merge.
function table.list_merge(...)
    local lists = table.to_list { ... }

    local result = {}
    for i, list in ipairs(lists) do
        local _, t = xtype(list)
        assert(t == 'list', format_assert_error({
            {
                field = tostring(i),
                expected_type = 'list',
                actual_type = t,
                message = 'invalid type',
            },
        }))

        for _, item in ipairs(list) do
            table.insert(result, item)
        end
    end

    return result
end

--- Coerces a value to a list.
---@generic T
---@param value T|T[]|table<any,T>|nil # any value that will be converted to a list.
---@return T[] # the listified version of the value.
function table.to_list(value)
    local _, t = xtype(value)

    ---@type table
    local result

    if t == 'nil' then
        result = {}
    elseif t == 'list' then
        result = value --[[@as table]]
    elseif t == 'table' then
        local list = {}
        for _, item in
            pairs(value --[[@as table]])
        do
            table.insert(list, item)
        end

        result = list
    else
        result = { value }
    end

    return result
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
    xassert {
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

--- Checks if a table is empty.
---@param t table # the table to check.
---@return boolean # whether the table is empty.
function table.is_empty(t)
    xassert {
        t = { t, { 'table', 'list' } },
    }

    return next(t) == nil
end

--- Extracts the keys from a table.
---@param t table # the table to extract the keys from.
function table.keys(t)
    xassert {
        t = { t, 'table' },
    }

    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end

  return keys
end

--- Checks if a string starts with a given prefix.
---@param s string # the string to check.
---@param prefix string # the prefix to check.
---@return boolean # whether the string starts with the prefix.
function string.starts_with(s, prefix)
    xassert {
        s = { s, 'string' },
        prefix = { prefix, 'string' },
    }

    return string.sub(s, 1, #prefix) == prefix
end

--- Checks if a string ends with a given suffix.
---@param s string # the string to check.
---@param suffix string # the suffix to check.
function string.ends_with(s, suffix)
    xassert {
        s = { s, 'string' },
        suffix = { suffix, 'string' },
    }

    return string.sub(s, -#suffix) == suffix
end


-- luacheck: pop

---@class api
_G.ide = {
    text = require 'api.text',
    fs = require 'api.fs',
    buf = require 'api.buf',
    ft = require 'api.ft',
    process = require 'api.process',
    events = require 'api.events',
    tui = require 'api.tui',
    async = require 'api.async',
    plugins = require 'api.plugins',
}

require 'api.vim.fn'
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
            val = inspect(v)
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
