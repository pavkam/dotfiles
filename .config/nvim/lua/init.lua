math.randomseed(os.time())

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
        local mt = getmetatable(value)
        if mt then
            if type(mt.__pairs) == 'function' then
                return t, 'table'
            end

            if type(mt.__ipairs) == 'function' then
                return t, 'list'
            end

            if type(mt.__call) == 'function' then
                return t, 'callable'
            end
        end

        if vim.islist(value) then
            return t, 'list'
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
---| { [1]: 'list', ['*']: xassert_type|nil, ['=']: integer|nil } # a list of values.
---| { [1]: 'number'|'integer', ['<']: integer|nil, ['>']: integer|nil } # a number.
---| { [1]: 'string', ['*']: string|string[]|function|nil, ['<']: integer|nil, ['>']: integer|nil } # a string.
---| { [1]: 'string', ['*']: string|string[]|function|nil, ['=']: integer|nil } # a string.
---| { [string]: xassert_type } # a sub-table.

---@class (exact) xassert_entry # An assertion entry.
---@field [1] any # the value to assert.
---@field [2] xassert_type # the type of the value.

---@alias xassert_schema # An assertion schema.
---| { [string]: xassert_entry } # The field to assert.

---@class (exact) xassert_error # The error of a validation.
---@field field string|nil # the field that failed the validation.
---@field expected_cond string # the expected type.
---@field actual_cond string # the actual type.
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
            expected_cond = 'table',
            actual_cond = type(entry),
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
                expected_cond = field_schema,
                actual_cond = field_value_type,
                message = 'invalid type',
            }
        end

        return
    end

    if field_schema_raw_type ~= 'table' then
        return {
            field = field_name,
            expected_cond = 'table',
            actual_cond = field_schema_raw_type,
            message = 'invalid schema entry: not a table',
        }
    end

    ---@cast field_schema table
    if field_schema_type == 'table' and xtype(field_schema[1]) == 'string' then
        local possible_type = field_schema[1] --[[@as xtype]]

        if possible_type == 'table' then
            if field_value_type ~= possible_type and not field_value_type_maybe_table then
                return {
                    field = field_name,
                    expected_cond = possible_type,
                    actual_cond = field_value_type,
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
        local eq = xtype(field_schema['=']) == 'number' and field_schema['='] or nil

        if possible_type == 'list' then
            if field_value_type ~= possible_type then
                return {
                    field = field_name,
                    expected_cond = possible_type,
                    actual_cond = field_value_type,
                    message = 'not a list',
                }
            end

            if lt and #field_value > lt then
                return {
                    field = field_name,
                    expected_cond = string.format('max. %d items', lt),
                    actual_cond = string.format('%d items', #field_value),
                    message = 'list is too long',
                }
            end

            if gt and #field_value < gt then
                return {
                    field = field_name,
                    expected_cond = string.format('max. %d items', gt),
                    actual_cond = string.format('%d items', #field_value),
                    message = 'list is too short',
                }
            end

            if eq and #field_value ~= eq then
                return {
                    field = field_name,
                    expected_cond = string.format('exactly %d items', eq),
                    actual_cond = string.format('%d items', #field_value),
                    message = 'list is not of the expected length',
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
                    expected_cond = possible_type,
                    actual_cond = field_value_type,
                    message = 'invalid type',
                }
            end

            if lt and field_value > lt then
                return {
                    field = field_name,
                    expected_cond = string.format('max. %d', lt),
                    actual_cond = tostring(field_value),
                    message = 'number is too big',
                }
            end

            if gt and field_value < gt then
                return {
                    field = field_name,
                    expected_cond = string.format('max. %d', gt),
                    actual_cond = tostring(field_value),
                    message = 'number is too small',
                }
            end

            return
        end

        if possible_type == 'string' then
            if field_value_type ~= possible_type then
                return {
                    field = field_name,
                    expected_cond = possible_type,
                    actual_cond = field_value_type,
                    message = 'invalid type',
                }
            end

            if lt and #field_value > lt then
                return {
                    field = field_name,
                    expected_cond = string.format('max. %d characters', lt),
                    actual_cond = string.format('%d characters', #field_value),
                    message = 'string is too long',
                }
            end

            if gt and #field_value < gt then
                return {
                    field = field_name,
                    expected_cond = string.format('max. %d characters', gt),
                    actual_cond = string.format('%d characters', #field_value),
                    message = 'string is too short',
                }
            end

            if eq and #field_value ~= eq then
                return {
                    field = field_name,
                    expected_cond = string.format('exactly %d characters', eq),
                    actual_cond = string.format('%d characters', #field_value),
                    message = 'string is not of the expected length',
                }
            end

            local string_match = field_schema['*']
            local _, string_match_type = xtype(string_match)

            if string_match_type == 'string' then
                if not field_value:match(string_match) then
                    return {
                        field = field_name,
                        expected_cond = string.format('string matching "%s"', string_match),
                        actual_cond = field_value,
                        message = 'string does not match pattern',
                    }
                end
            elseif string_match_type == 'callable' then
                if not string_match(field_value) then
                    return {
                        field = field_name,
                        expected_cond = 'validated string',
                        actual_cond = field_value,
                        message = 'string does not pass validation',
                    }
                end
            elseif string_match_type == 'list' then
                local found = table.list_any(string_match --[[@as table]], field_value)

                if not found then
                    return {
                        field = field_name,
                        expected_cond = string.format('string matching any of [%s]', table.concat(string_match, ', ')),
                        actual_cond = field_value,
                        message = 'string does not match any candidate',
                    }
                end
            elseif string_match_type ~= 'nil' then
                return {
                    field = field_name,
                    expected_cond = 'string | callable | list',
                    actual_cond = string_match_type,
                    message = 'invalid schema: invalid string match type',
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

        return {
            field = field_name,
            expected_cond = table.concat(
                table.list_uniq(table.list_map(errors, function(e)
                    return e.expected_cond
                end)),
                ' | '
            ),
            actual_cond = table.concat(
                table.list_uniq(table.list_map(errors, function(e)
                    return e.actual_cond
                end)),
                ' | '
            ),
            message = 'invalid type or assertions of value failed',
        }
    end

    if field_value_raw_type ~= 'table' then
        return {
            field = field_name,
            expected_cond = 'table | list',
            actual_cond = field_value_type,
            message = 'invalid type',
        }
    end

    ---@type xassert_schema
    local composite_schema = {}
    for k, v in pairs(composite_schema) do
        composite_schema[k] = { field_value[k], v }
    end

    return validate(field_name, composite_schema) -- TODO: this does not work for nested tables.
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
                expected_cond = 'table',
                actual_cond = type(schema),
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
        assert(error.field, 'validation internal error')

        formatted = formatted
            .. string.format(
                '\n  - [`%s`]: %s. expected `%s`, got `%s`.',
                error.field,
                error.message,
                error.expected_cond,
                error.actual_cond
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

-- Creates a hash from a list of values.
---@param ... any # the values to hash.
---@return string # the hash.
_G.hash = function(...)
    local key = ''
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        key = key .. '|' .. inspect(v)
    end

    return vim.fn.sha256(key)
end

-- Memoizes a the value of a function.
---@generic T: fun(...): any
---@param fn T # the function to memoize.
---@return T # the memoized function.
_G.memoize = function(fn)
    ---@type table<string, any>
    local data = {}

    return function(...)
        local key = hash(...)
        if not data[key] then
            data[key] = fn(...)
        end

        return data[key]
    end
end

-- Reuires a module lazyly.
---@param module string # the module to require.
_G.xrequire = function(module)
    xassert {
        module = { module, 'string', ['>'] = 0 },
    }

    ---@type any|nil
    local loaded_module
    return setmetatable({}, {
        __index = function(_, key)
            loaded_module = loaded_module or require(module)
            return loaded_module[key]
        end,
        __newindex = function(_, key, value)
            loaded_module = loaded_module or require(module)
            loaded_module[key] = value
        end,
        __call = function(_, ...)
            loaded_module = loaded_module or require(module) --TODO: probably can be made smarter
            return loaded_module(...)
        end,
        __ipairs = function()
            loaded_module = loaded_module or require(module)
            local a, b, c = ipairs(loaded_module)
            return a, b, c
        end,
        __pairs = function()
            loaded_module = loaded_module or require(module)
            local a, b, c = pairs(loaded_module)
            return a, b, c
        end,
    })
end

-- luacheck: push ignore 121 122 113

local __lua_pairs = pairs
local __lua_ipairs = ipairs

-- Iterates over all key–value pairs of a table.
---@generic K, V
---@param t table<K, V>
---@return (fun(t: table<K, V>, i: K|nil): K, V), table<K, V>, K
_G.pairs = function(t)
    assert(type(t) == 'table', 'expected a table')

    local mt = getmetatable(t)
    local n, p, k = (mt and mt.__pairs or __lua_pairs)(t)
    return n, p, k
end

-- Iterates over a list of values.
---@generic T
---@param t T[]
---@return (fun(table: T[], i: integer|nil): integer, T), T[], integer
_G.ipairs = function(t)
    assert(type(t) == 'table', 'expected a table')

    local mt = getmetatable(t)
    local n, p, i = (mt and mt.__ipairs or __lua_ipairs)(t)
    return n, p, i
end

---@class (exact) inspect_options # The options for the inspect function.
---@field unroll_meta boolean|nil # whether to unroll meta tables (default: `true`).
---@field new_line string|nil # the newline character to use (default: '\n').
---@field indent string|nil # the indent string to use (default: '  ').
---@field separator string|nil # the separator to use (default: ', ').
---@field max_depth integer|nil # the maximum depth to inspect (default: 3).

--- Inspects a value.
---@param value any # the value to inspect.
---@param opts inspect_options|nil # the options to use.
---@param depth integer|nil # the current depth.
---@return string # the inspected value.
function _G.inspect(value, opts, depth)
    ---@type inspect_options
    opts = table.merge(opts, {
        unroll_meta = true,
        new_line = '\n',
        indent = '  ',
        separator = ', ',
        max_depth = 3,
    })

    depth = (depth or -2) + 1

    xassert {
        opts = {
            opts,
            {
                unroll_meta = 'boolean',
                new_line = 'string',
                separator = 'string',
                indent = 'string',
                max_depth = { 'integer', ['>'] = 0 },
            },
        },
        depth = { depth, 'integer' },
    }

    local t, ty = xtype(value)

    if ty == 'nil' then
        return 'nil'
    elseif ty == 'string' then
        return string.format("'%s'", value)
    elseif ty == 'number' or ty == 'integer' or ty == 'boolean' then
        return tostring(value)
    elseif ty == 'table' or ty == 'callable' and t == 'table' then
        if depth <= opts.max_depth then
            local parts = {}

            local mt = getmetatable(value)
            if mt then
                if opts.unroll_meta and mt.__tostring then
                    return mt.__tostring(value)
                elseif opts.unroll_meta and mt.__ipairs or mt.__pairs then
                    local unrolled = table.clone(value)
                    return inspect(unrolled, opts, depth)
                end

                table.insert(parts, string.format('<metatable> = %s', inspect(mt, opts, depth)))
            end

            for k, v in pairs(value) do
                table.insert(
                    parts,
                    string.format(
                        '%s = %s',
                        inspect(k, {
                            newline = '',
                            unroll_meta = opts.unroll_meta,
                            indent = '',
                            max_depth = 1,
                            separator = opts.separator,
                        }, depth),
                        inspect(v, opts, depth)
                    )
                )
            end

            local item_str = table.concat(parts, opts.new_line)

            if item_str == '' then
                return '{}'
            elseif item_str:find '\n' then
                return string.format('{%s%s%s}', opts.new_line, string.indent(item_str, opts.indent), opts.new_line)
            else
                return string.format('{%s}', item_str)
            end
        else
            return string.format '{...}'
        end
    elseif ty == 'list' then
        if depth <= opts.max_depth then
            local parts = {}

            for _, v in ipairs(value) do
                table.insert(parts, inspect(v, opts, depth))
            end

            local item_str = table.concat(parts, opts.separator)
            if item_str == '' then
                return '{}'
            elseif item_str:find '\n' then
                return string.format('[%s%s%s]', opts.new_line, string.indent(item_str, opts.indent), opts.new_line)
            else
                return string.format('[%s]', item_str)
            end
        else
            return string.format '[...]'
        end
    end

    return vim.inspect(value, { newline = opts.new_line, depth = opts.max_depth })
end

-- Makes a table read-only.
---@generic T: table
---@param table T # the table to make read-only.
---@return T # the read-only table.
function table.freeze(table)
    assert(type(table) == 'table', 'expected a table')

    return setmetatable({}, {
        __index = table, -- TODO: freeze deep.
        __newindex = function()
            error('attempt to modify read-only table', 2)
        end,
        __pairs = function()
            local a, b, c = pairs(table)
            return a, b, c
        end,
        __ipairs = function()
            local a, b, c = ipairs(table)
            return a, b, c
        end,
    })
end

-- Creates a read-only table from a function.
---@generic K, V
---@param fn fun(key: K): V # the function to read from.
---@return table<K, V> # the read-only table.
function table.read_proxy(fn)
    xassert {
        fn = { fn, 'callable' },
    }

    return setmetatable({}, {
        __index = function(_, key)
            return fn(key)
        end,
        __newindex = function()
            error('attempt to modify read-only table', 2)
        end,
        __metatable = false,
    })
end

-- Clears a table.
---@generic T: table
---@param t T # the table to clear.
function table.clear(t)
    for k, _ in pairs(t) do
        t[k] = nil
    end
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

    local entity_keys =
        table.list_to_set(table.list_merge(table.keys(opts.entity_functions), table.keys(opts.entity_properties)))

    ---@param root table
    ---@param entity_id any
    local function make_entity_table(root, entity_id)
        return setmetatable({}, {
            __index = function(entity, key)
                if key == nil then
                    return
                end

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

                error(string.format('unknown function or property `%s`', inspect(key)), 2)
            end,
            __newindex = function(entity, key, value)
                if key == nil then
                    return
                end

                if key == 'id' then
                    error(string.format('property `%s` is read-only', inspect(key)), 2)
                end

                local prop = opts.entity_properties[key]

                if prop then
                    if prop.set then
                        if prop.cache then
                            rawset(entity, key, value)
                        end

                        return prop.set(root, entity, value)
                    else
                        error(string.format('property `%s` is read-only', inspect(key)), 2)
                    end
                end

                error(string.format('unknown property `%s`', inspect(key)), 2)
            end,
            __pairs = function(entity)
                local iter = function(t, k)
                    k = next(t, k)
                    return k, entity[k]
                end

                return iter, entity_keys, nil
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

            if prop then
                if prop.set then
                    prop.set(root, value)
                    return
                else
                    error(string.format('property `%s` is read-only', inspect(key)), 2)
                end
            end

            error(string.format('unknown property `%s`', inspect(key)), 2)
        end,
        __pairs = opts.entity_ids and function(root)
            local iter = function(t, k)
                local v
                repeat
                    k, v = next(t, k)
                until k == nil or opts.entity_id_valid(v)

                if k == nil then
                    return
                end

                return k, root[v]
            end

            return iter, opts.entity_ids(), nil
        end or function()
            error 'this table is not enumerable'
        end,
        __ipairs = opts.entity_ids and function(root)
            local iter = function(t, i)
                local v
                repeat
                    i, v = i + 1, t[i]
                until i > #t or opts.entity_id_valid(v)

                if i > #t then
                    return
                end

                return i, root[t[i]]
            end

            return iter, opts.entity_ids(), 0
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
---@nodiscard
function table.any(t, fn)
    for k, v in pairs(t) do
        if fn(k, v) then
            return true
        end
    end

    return false
end

--- Merges multiple tables into one.
---@param ... table|nil # the tables to merge.
---@return table # the merged table.
---@nodiscard
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
---@return T # the merged list.
---@nodiscard
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
---@nodiscard
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

---@class (exact) set<T>: { [T]: true } # Represents a set.

-- Converts a list to a set.
---@generic T
---@param list T[] # the list to convert to a set.
---@return set<T>
---@nodiscard
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

-- Returns a new list that contains only unique values.
---@param list any[] # the list to make unique.
---@param key_fn (fun(value: any): any)|nil # the function to get the key from the value.
---@return any[] # the list with unique values.
---@nodiscard
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

-- Inflates a list to a table.
---@generic T, K, V
---@param list T[] # the list to inflate.
---@param fn fun(value: T, index: integer): K, V  # the function to inflate the values.
---@return {[K]: V} # the inflated table.
---@nodiscard
function table.inflate(list, fn)
    xassert {
        list = { list, 'list' },
        fn = { fn, 'callable' },
    }

    local result = {}

    for index, item in ipairs(list) do
        local key, value = fn(item, index)
        result[key] = value
    end

    return result
end

-- Checks if a table is empty.
---@param t table # the table to check.
---@return boolean # whether the table is empty.
---@nodiscard
function table.is_empty(t)
    xassert {
        t = { t, { 'table', 'list' } },
    }

    return next(t) == nil
end

-- Checks if a table is a list.
---@param t table # the table to check.
---@return boolean # whether the table is a list.
---@nodiscard
function table.is_list(t)
    xassert {
        t = { t, { 'table', 'list' } },
    }

    local _, ty = xtype(t)
    return ty == 'list'
end

-- Converts the elements of a list to a new list.
---@generic I, O
---@param list I[] # the list to map.
---@param fn fun(value: I, index: integer): O # the function to map the values.
---@return O[] # the mapped list.
---@nodiscard
function table.list_map(list, fn)
    xassert {
        list = { list, 'list' },
        fn = { fn, 'callable' },
    }

    local result = {}
    for index, item in ipairs(list) do
        table.insert(result, fn(item, index))
    end

    return result
end

-- Iterates over the elements of a list.
---@generic T
---@param list T[] # the list to iterate over.
---@param fn fun(value: T, index: integer) # the function to iterate the values.
function table.list_iterate(list, fn)
    xassert {
        list = { list, 'list' },
        fn = { fn, 'callable' },
    }

    for index, item in ipairs(list) do
        fn(item, index)
    end
end

-- Sorts the elements of a list.
---@generic T
---@param list T[] # the list to sort.
---@param fn fun(a: T, b: T): boolean # the function to sort the values.
---@return T[] # the sorted list.
---@nodiscard
function table.list_sort(list, fn)
    xassert {
        list = { list, 'list' },
        fn = { fn, 'callable' },
    }

    list = table.clone(list)
    table.sort(list, fn)

    return list
end

-- Filters the elements of a list.
---@generic T
---@param list T[] # the list to filter.
---@param fn fun(value: T, index: integer): any # the function to filter the values.
---@return T[] # the filtered list.
---@nodiscard
function table.list_filter(list, fn)
    xassert {
        list = { list, 'list' },
        fn = { fn, 'callable' },
    }

    local result = {}
    for index, item in ipairs(list) do
        if fn(item, index) then
            table.insert(result, item)
        end
    end

    return result
end

-- Checks if a list has a value that matches a condition.
---@generic T
---@param list T[] # the list to check.
---@param cond T|fun(value: T, index: integer): any # the function to check the values.
---@return boolean # whether the list has any matching value.
---@nodiscard
function table.list_any(list, cond)
    xassert {
        list = { list, 'list' },
    }

    local _, ty = xtype(cond)

    if ty == 'callable' then
        for index, item in ipairs(list) do
            if cond(item, index) then
                return true
            end
        end
    else
        for _, item in ipairs(list) do
            if item == cond then
                return true
            end
        end
    end

    return false
end

-- Checks if a list has all values that match a condition.
---@generic T
---@param list T[] # the list to check.
---@param fn fun(value: T, index: integer): any # the function to check the values.
---@return boolean # whether the list has all matching values.
---@nodiscard
function table.list_all(list, fn)
    xassert {
        list = { list, 'list' },
        fn = { fn, 'callable' },
    }

    if #list == 0 then
        return true
    end

    for index, item in ipairs(list) do
        if fn(item, index) then
            return true
        end
    end

    return false
end

--- Converts the values of a table to a new table.
---@generic K, I, O
---@param t { [K]: I } # the table to map.
---@param fn fun(value: I): O # the function to map the values.
---@return { [K]: O } # the mapped list.
---@nodiscard
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
---@generic K, V
---@param t table<K, V> # the table to extract the keys from.
---@return K[] # the keys of the table.
---@nodiscard
function table.keys(t)
    xassert {
        t = { t, { 'table', 'list' } },
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
---@param shallow boolean|nil # whether to do a shallow clone (default: `true`).
---@return T # the cloned table or list.
---@nodiscard
function table.clone(t, shallow)
    xassert {
        t = { t, { 'table', 'list' } },
        shallow = { shallow, { 'nil', 'boolean' } },
    }

    if shallow == false then
        return vim.deepcopy(t)
    elseif table.is_list(t) then
        return table.list_merge({}, t)
    else
        return table.merge({}, t)
    end
end

--- Checks if a string starts with a given prefix.
---@param s string # the string to check.
---@param prefix string # the prefix to check.
---@return boolean # whether the string starts with the prefix.
---@nodiscard
function string.starts_with(s, prefix)
    xassert {
        s = { s, 'string' },
        prefix = { prefix, 'string' },
    }

    return string.sub(s, 1, #prefix) == prefix
end

-- Checks if a string ends with a given suffix.
---@param s string # the string to check.
---@param suffix string # the suffix to check.
function string.ends_with(s, suffix)
    xassert {
        s = { s, 'string' },
        suffix = { suffix, 'string' },
    }

    return string.sub(s, -#suffix) == suffix
end

-- Indents a string.
---@param s string # the string to indent.
---@param indent string # the indent to use.
---@return string # the indented string.
---@nodiscard
function string.indent(s, indent)
    xassert {
        s = { s, 'string' },
        indent = { indent, 'string' },
    }

    return indent .. s:gsub('\n', '\n' .. indent)
end

-- Gets the timezone offset for a given timestamp
---@param timestamp integer # the timestamp to get the offset for
---@return integer # the timezone offset
---@nodiscard
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

-- Generates a new UUID
---@return string # the generated UUID
---@nodiscard
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
    ---@module 'text'
    text = xrequire 'text',
    ---@module 'fs'
    fs = xrequire 'fs',
    ---@module 'buf'
    buf = xrequire 'buf',
    ---@module 'win'
    win = xrequire 'win',
    ---@module 'ft'
    ft = xrequire 'ft',
    ---@module 'config'
    config = xrequire 'config',
    ---@module 'cmd'
    cmd = xrequire 'cmd',
    ---@module 'editor'
    editor = xrequire 'editor',
    ---@module 'process'
    process = xrequire 'process',
    ---@module 'tui'
    tui = xrequire 'tui',
    ---@module 'sched'
    sched = xrequire 'sched',
    ---@module 'theme'
    theme = xrequire 'theme',
    ---@module 'plugin'
    plugin = xrequire 'plugin',
    ---@module 'symb'
    symb = xrequire 'symb',
}

require '__unsorted'

---@type table<string, boolean>
local shown_messages = {}

--- Global debug function to help me debug (duh)
---@param ... any # anything to debug
function _G.dbg(...)
    local objects = {}
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        table.insert(objects, inspect(v))
    end

    local trace = ide.process.get_formatted_trace_back(2)
    local formatted = string.format('%s\n\ntraceback:\n%s', table.concat(objects, '\n'), trace)
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
