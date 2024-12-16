math.randomseed(os.time())

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

---@type fun(parent_field_name: string|nil, schema: xassert_schema): xassert_error[] # the validation function.
local validate

-- Validates a given schema entry.
---@param field_name string # the key to assert.
---@param entry xassert_entry # the schema to validate.
---@return xassert_error|xassert_error[]|nil # the result of the validation.
local function validate_entry(field_name, entry)
    if xtype(entry) ~= 'table' then
        return {
            field = field_name,
            expected_type = 'table',
            actual_type = type(entry),
            message = 'invalid schema entry',
        }
    end

    local field_value = entry[1]
    local field_schema = entry[2]
    local field_value_raw_type, field_value_type = xtype(field_value)
    local field_schema_raw_type, field_schema_type = xtype(field_schema)

    local field_value_type_maybe_table = field_value_type == 'list' and next(field_value) == nil

    if field_schema_type == 'string' then --[[@cast field_schema string]]
        if field_schema == 'table' and field_value_type_maybe_table then
            return
        end

        if field_value_type ~= field_schema then
            return {
                field = field_name,
                expected_type = field_schema,
                actual_type = field_value_type,
                message = 'invalid type',
            }
        end

        return
    end

    if field_schema_raw_type ~= 'table' then
        return {
            field = field_name,
            expected_type = 'table',
            actual_type = field_schema_raw_type,
            message = 'invalid schema entry',
        }
    end

    ---@cast field_schema table
    if field_schema_type == 'table' and xtype(field_schema[1]) == 'string' then
        local possible_type = field_schema[1] --[[@as xtype]]

        if possible_type == 'table' then
            if field_value_type ~= possible_type and not field_value_type_maybe_table then
                return {
                    field = field_name,
                    expected_type = possible_type,
                    actual_type = field_value_type,
                    message = 'not a table',
                }
            end

            local table_item_schema = field_schema['*']

            if table_item_schema ~= nil then
                ---@type xassert_schema
                local composite_schema = {
                    ['__keys__'] = { table.keys(field_value), { 'list', ['*'] = 'string' } },
                }

                for k, v in pairs(field_value) do
                    composite_schema[tostring(k)] = { v, table_item_schema }
                end

                return validate(field_name, composite_schema)
            end

            return
        end

        local lt = xtype(field_schema['<']) == 'number' and field_schema['<'] or nil
        local gt = xtype(field_schema['>']) == 'number' and field_schema['>'] or nil

        if possible_type == 'list' then
            if field_value_type ~= possible_type then
                return {
                    field = field_name,
                    expected_type = possible_type,
                    actual_type = field_value_type,
                    message = 'not a list',
                }
            end

            if lt and #field_value > lt then
                return {
                    field = field_name,
                    expected_type = field_value_type,
                    actual_type = field_value_type,
                    message = string.format('list is too long (expected at most `%d`)', lt),
                }
            end

            if gt and #field_value < gt then
                return {
                    field = field_name,
                    expected_type = field_value_type,
                    actual_type = field_value_type,
                    message = string.format('list is too short (expected at least `%d`)', gt),
                }
            end

            local list_item_schema = field_schema['*']

            if list_item_schema ~= nil then
                ---@type xassert_schema
                local composite_schema = {}
                for i, v in ipairs(field_value) do
                    composite_schema[tostring(i)] = { v, list_item_schema }
                end

                return validate(field_name, composite_schema)
            end

            return
        end

        if possible_type == 'integer' or possible_type == 'number' then
            if field_value_type ~= possible_type then
                return {
                    field = field_name,
                    expected_type = possible_type,
                    actual_type = field_value_type,
                    message = 'invalid type',
                }
            end

            if lt and field_value > lt then
                return {
                    field = field_name,
                    expected_type = field_value_type,
                    actual_type = field_value_type,
                    message = string.format('value is too large (expected at most `%d`)', lt),
                }
            end

            if gt and field_value < gt then
                return {
                    field = field_name,
                    expected_type = field_value_type,
                    actual_type = field_value_type,
                    message = string.format('value is too small (expected at least `%d`)', gt),
                }
            end

            return
        end

        if possible_type == 'string' then
            if field_value_type ~= possible_type then
                return {
                    field = field_name,
                    expected_type = possible_type,
                    actual_type = field_value_type,
                    message = 'invalid type',
                }
            end

            if lt and #field_value > lt then
                return {
                    field = field_name,
                    expected_type = field_value_type,
                    actual_type = field_value_type,
                    message = string.format('string is too long (expected at most `%d`)', lt),
                }
            end

            if gt and #field_value < gt then
                return {
                    field = field_name,
                    expected_type = field_value_type,
                    actual_type = field_value_type,
                    message = string.format('string is too short (expected at least `%d`)', gt),
                }
            end

            local string_match = xtype(field_schema['*']) == 'string' and field_schema['*'] or nil
            if string_match ~= nil and not field_value:match(string_match) then
                return {
                    field = field_name,
                    expected_type = field_value_type,
                    actual_type = field_value_type,
                    message = string.format('string does not match pattern `%s`', string_match),
                }
            end

            return
        end
    end

    if field_schema_type == 'list' then
        local errors = {}
        for i, candidate_schema in ipairs(field_schema) do
            local inner_errors = validate(field_name, { [tostring(i)] = { field_value, candidate_schema } })

            if #inner_errors == 0 then
                return
            else
                for _, error in ipairs(inner_errors) do
                    table.insert(errors, error)
                end
            end
        end

        return errors
    end

    if field_value_raw_type ~= 'table' then
        return {
            field = field_name,
            expected_type = 'table | list',
            actual_type = field_value_type,
            message = 'invalid type',
        }
    end

    ---@type xassert_schema
    local composite_schema = {}
    for k, v in pairs(composite_schema) do
        composite_schema[k] = { field_value[k], v }
    end

    return validate(field_name, composite_schema)
end

-- Validates a given schema.
---@param parent_field_name string|nil # the key to assert.
---@param schema xassert_schema # the schema to validate.
---@return xassert_error[] # the result of the validation.
validate = function(parent_field_name, schema)
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

        local validation_result = validate_entry(field_name, entry)
        if validation_result then
            local _, ty = xtype(validation_result)

            if ty == 'list' then
                for _, error in ipairs(validation_result) do
                    table.insert(errors, error)
                end
            else
                table.insert(errors, validation_result)
            end
        end
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

--- Makes a table weak.
---@generic T: table
---@param t T # the table to make weak.
---@param mode string|nil # the mode of the weak table (`k`, `v` or `kv`; default is `k`).
---@return T # the weak table.
function table.weak(t, mode)
    xassert {
        t = { t, 'table' },
        mode = { mode, { 'nil', { 'string', ['*'] = '^k|v|kv$' } } },
    }

    return setmetatable(t, { __mode = mode or 'k' })
end

---@class (exact) smart_table_entity_prop # The property for a smart table.
---@field get fun(smart_table: table, entity: table): any # the getter function.
---@field set (fun(smart_table: table, entity: table, value: any)) | nil # the setter function (optional).
---@field cache boolean|nil # whether to cache the values (default `false`).

---@class (exact) smart_table_prop # The property for a smart table.
---@field get fun(smart_table: table): any # the getter function.
---@field set (fun(smart_table: table, value: any)) | nil # the setter function (optional).

---@alias smart_table_func fun(smart_table: table, ...): any # The function for a smart table.
---@alias smart_table_entity_func fun(entity: table, ...): any # The function for an entity.

---@class smart_table_options # The options for a synthetic table.
---@field functions table<string, smart_table_func>|nil # the functions for the smart table (optional).
---@field properties table<string, smart_table_prop>|nil # the properties for the smart table (optional).
---@field entity_id_valid fun(id: any): boolean # the function to check if an entity is valid.
---@field entity_ids (fun(): any[])|nil # the entities to make smart tables for (optional).
---@field entity_functions table<string, smart_table_entity_func>|nil # the functions for the smart table (optional).
---@field entity_properties table<string, smart_table_entity_prop>|nil # the properties for the smart table (optional).

--- Creates a new smart table.
---@param opts smart_table_options # the options for the smart table.
---@return table # the smart table.
function table.smart(opts)
    ---@type smart_table_options
    opts = table.merge(opts, {
        functions = {},
        properties = {},
        entity_functions = {},
        entity_properties = {},
    })

    xassert {
        opts = {
            opts,
            {
                functions = {
                    'table',
                    ['*'] = 'callable',
                },
                properties = {
                    'table',
                    ['*'] = {
                        get = 'callable',
                        set = { 'nil', 'callable' },
                    },
                },
                entity_ids = { 'nil', 'callable' },
                entity_id_valid = 'callable',
                entity_functions = {
                    'table',
                    ['*'] = 'callable',
                },
                entity_properties = {
                    'table',
                    ['*'] = {
                        get = 'callable',
                        set = { 'nil', 'callable' },
                        cache = { 'nil', 'boolean' },
                    },
                },
            },
        },
    }

    local entity_keys = table.list_merge(table.keys(opts.entity_functions), table.keys(opts.entity_properties))

    ---@param root table
    ---@param entity_id any
    local function make_entity_table(root, entity_id)
        return setmetatable({}, {
            __index = function(entity, key)
                if key == 'id' then
                    return entity_id
                end

                local fn = opts.entity_functions[key]
                if fn then
                    return function(...)
                        return fn(root, entity, ...)
                    end
                end

                local prop = opts.entity_properties[key]
                if prop then
                    if prop.cache then
                        local value = rawget(entity, key)
                        if value == nil then
                            value = prop.get(root, entity)
                            rawset(entity, key, value)
                        end

                        return value
                    end

                    return prop.get(root, entity)
                end

                error(string.format('unknown property, function or property %s.', inspect(key)), 2)
            end,
            __newindex = function(entity, key, value)
                local prop = opts.entity_properties[key]

                if prop then
                    if prop.cache then
                        rawset(entity, key, value)
                    end

                    if prop.set then
                        return prop.set(root, entity, value)
                    end
                end

                error(string.format('unknown property, function or property %s.', inspect(key)), 2)
            end,
            __pairs = function()
                return entity_keys
            end,
        })
    end

    return setmetatable({}, {
        __index = function(root, key)
            local fn = opts.functions[key]
            if fn then
                return function(...)
                    return fn(root, ...)
                end
            end

            local prop = opts.properties[key]
            if prop and prop.get then
                return prop.get(root)
            end

            if opts.entity_id_valid(key) then
                local entity = rawget(root, key)
                if entity == nil then
                    entity = make_entity_table(root, key)
                    rawset(root, key, entity)
                end

                return entity
            end

            return nil
        end,
        __newindex = function(root, key, value)
            local prop = opts.properties[key]
            if prop and prop.set then
                prop.set(root, value)
                return
            end

            error(string.format('unknown property %s.', inspect(key)), 2)
        end,
        __pairs = opts.entity_ids and function()
            return opts.entity_ids()
        end or function()
            error 'this table is not enumerable'
        end,
    })
end

-- Checks if a table has a specific kay/value.
---@generic K, V
---@param t table<K, V> # the table to check.
---@param fn fun(key: K, value: V): boolean # the function to check the key/value.
---@return boolean # whether the table has the key/value.
function table.any(t, fn)
    for k, v in pairs(t) do
        if fn(k, v) then
            return true
        end
    end

    return false
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
        result = vim.tbl_extend('keep', unpack(list))
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
        xassert {
            [tostring(i)] = { list, 'list' },
        }

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

--- Converts a list to a set.
---@param list any[] # the list to convert to a set.
---@return table<any, boolean> # the set.
function table.list_to_set(list)
    xassert {
        list = { list, 'list' },
    }

    local result = {}

    for _, item in ipairs(list) do
        result[item] = true
    end

    return result
end

--- Removes the keys from a table.
---@generic K, V
---@param t table<K, V> # the table to remove the keys from.
---@param keys K[] # the keys to remove.
---@return table<K, V> # the table without the keys.
function table.without_keys(t, keys)
    xassert {
        t = { t, 'table' },
        keys = { keys, 'list' },
    }

    local result = {}
    local set = table.list_to_set(keys)

    for k, v in pairs(t) do
        if not set[k] then
            result[k] = v
        end
    end

    return result
end

--- Returns a new list that contains only unique values.
---@param list any[] # the list to make unique.
---@param key_fn (fun(value: any): any)|nil # the function to get the key from the value.
---@return any[] # the list with unique values.
function table.list_uniq(list, key_fn)
    xassert {
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

--- Checks if a table is a list.
---@param t table # the table to check.
---@return boolean # whether the table is a list.
function table.is_list(t)
    xassert {
        t = { t, { 'table', 'list' } },
    }

    local _, ty = xtype(t)
    return ty == 'list'
end

--- Converts the elements of a list to a new list.
---@generic I, O
---@param list I[] # the list to map.
---@param fn fun(value: I): O # the function to map the values.
---@return O[] # the mapped list.
function table.list_map(list, fn)
    xassert {
        list = { list, 'list' },
        fn = { fn, 'callable' },
    }

    local result = {}
    for _, item in ipairs(list) do
        table.insert(result, fn(item))
    end

    return result
end

--- Filters the elements of a list.
---@generic T
---@param list T[] # the list to filter.
---@param fn fun(value: T): boolean # the function to filter the values.
---@return T[] # the filtered list.
function table.list_filter(list, fn)
    xassert {
        list = { list, 'list' },
        fn = { fn, 'callable' },
    }

    local result = {}
    for _, item in ipairs(list) do
        if fn(item) then
            table.insert(result, item)
        end
    end

    return result
end

--- Converts the values of a table to a new table.
---@generic K, I, O
---@param t table<K, I> # the table to map.
---@param fn fun(value: I): O # the function to map the values.
---@return table<K, O> # the mapped list.
function table.map(t, fn)
    xassert {
        t = { t, 'table' },
        fn = { fn, 'callable' },
    }

    local result = {}
    for key, value in pairs(t) do
        result[key] = fn(value)
    end

    return result
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

-- Clones a table or a list.
---@generic T: table
---@param t T # the table or list to clone.
---@return T # the cloned table or list.
function table.clone(t)
    return vim.deepcopy(t)
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

--- Gets the timezone offset for a given timestamp
---@param timestamp integer # the timestamp to get the offset for
---@return integer # the timezone offset
function os.timezone_offset(timestamp)
    assert(type(timestamp) == 'number')

    local utc_date = os.date('!*t', timestamp)
    local local_date = os.date('*t', timestamp)

    local_date.isdst = false

    local diff = os.difftime(os.time(local_date --[[@as osdateparam]]), os.time(utc_date --[[@as osdateparam]]))
    local h, m = math.modf(diff / 3600)

    return 100 * h + 60 * m
end

---@type string
local uuid_template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

--- Generates a new UUID
---@return string # the generated UUID
function os.uuid()
    ---@param c string
    local function subs(c)
        local v = (((c == 'x') and math.random(0, 15)) or math.random(8, 11))
        return string.format('%x', v)
    end

    local res = uuid_template:gsub('[xy]', subs)
    return res
end

-- luacheck: pop

---@class api
_G.ide = {
    text = require 'api.text',
    fs = require 'api.fs',
    buf = require 'api.buf',
    win = require 'api.win',
    ft = require 'api.ft',
    command = require 'api.command',
    editor = require 'api.editor',
    process = require 'api.process',
    evt = require 'api.evt',
    tui = require 'api.tui',
    async = require 'api.async',
    theme = require 'api.theme',
    plugin = require 'api.plugin',
}

require 'api.vim.fn'
require 'api.vim.buf'

--- Returns the formatted arguments for debugging
---@param ... any # the arguments to format
local function format_args(...)
    local objects = {}
    for i = 1, select('#', ...) do
        local v = select(i, ...)
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
---@param ... any # anything to debug
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
