-- Provides a set of functions to check if a value is of a certain type.
---@class expect
vim.assert = {}

-- Checks if a given value is an integer.
---@param value any # the value to check.
---@return boolean # whether the value is an integer.
function vim.is_integer(value)
    return type(value) == 'number' and value % 1 == 0
end

---@class (exact) vim.assert.CallableOpts # Options for the `callable` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field default function|nil # default value if `nil`.

--- Checks if a given value is a function.
---@generic T: function # the type of the value.
---@param value T # the value to check.
---@param opts vim.assert.CallableOpts|nil # options for the function.
---@return T|nil # the value if it is a function.
function vim.assert.callable(value, opts)
    assert(opts == nil or type(opts) == 'table')
    assert(opts == nil or opts.optional == nil or type(opts.optional) == 'boolean')
    assert(opts == nil or opts.default == nil or vim.is_callable(opts.default))

    if vim.is_callable(value) then
        return value
    elseif not value and opts and opts.optional ~= false then
        return opts.default
    end

    error(string.format('expected a `callable`, got `%s`.', type(value)))
end

---@class (exact) vim.assert.StringOpts # Options for the `string` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field empty boolean|nil # allow empty strings or not (default: `true`).
---@field default string|nil # default value if `nil`.

--- Checks if a given value is a string.
---@param value string # the value to check.
---@param opts vim.assert.StringOpts|nil # options for the function.
---@return string|nil # the value if it is a string.
function vim.assert.string(value, opts)
    assert(opts == nil or type(opts) == 'table')
    assert(opts == nil or opts.optional == nil or type(opts.optional) == 'boolean')
    assert(opts == nil or opts.empty == nil or type(opts.empty) == 'boolean')
    assert(opts == nil or opts.default == nil or type(opts.default) == 'string')

    if type(value) == 'string' then
        if opts and opts.empty == false and #value == 0 then
            error 'expected a non-empty string.'
        end

        return value
    elseif value == nil and opts and opts.optional ~= false then
        return opts.default
    end

    error(string.format('expected a `string`, got `%s`.', type(value)))
end

---@class (exact) vim.assert.NumberOpts # Options for the `number` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field min number|nil # minimum value (optional).
---@field default number|nil # default value if `nil`.

--- Checks if a given value is a number.
---@param value number|nil # the value to check.
---@param opts vim.assert.NumberOpts|nil # options for the function.
---@return number|nil # the value if it is a string.
function vim.assert.number(value, opts)
    assert(opts == nil or type(opts) == 'table')
    assert(opts == nil or opts.optional == nil or type(opts.optional) == 'boolean')
    assert(opts == nil or opts.min == nil or type(opts.min) == 'number')
    assert(opts == nil or opts.default == nil or type(opts.default) == 'string')

    if type(value) == 'number' then
        if opts and opts.min ~= nil and value < opts.min then
            error(string.format('expected a number greater than or equal to `%d` but got `%d`.', opts.min, value))
        end

        return value
    elseif value == nil and opts and opts.optional ~= false then
        return opts.default
    end

    error(string.format('expected a `number`, got `%s`.', type(value)))
end

---@class (exact) vim.assert.IntegerOpts # Options for the `integer` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field min integer|nil # minimum value (optional).
---@field default integer|nil # default value if `nil`.

--- Checks if a given value is a integer.
---@param value integer|nil # the value to check.
---@param opts vim.assert.IntegerOpts|nil # options for the function.
---@return integer|nil # the value if it is a string.
function vim.assert.integer(value, opts)
    assert(opts == nil or opts.min == nil or (type(opts.min) == 'number' and opts.min % 1 == 0))
    assert(opts == nil or opts.default == nil or (type(opts.default) == 'number' and vim.is_integer(opts.default)))

    local number =
        vim.assert.number(value, opts and { optional = opts.optional, min = opts.min, default = opts.default })
    if number ~= nil then
        if vim.is_integer(number) then
            return number
        end

        error(string.format('expected an `integer`, got a `number` with value `%d`.', number))
    end
end

---@class (exact) vim.assert.StringColorOpts # Options for the `color_string` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).

--- Checks if a given value is a color string (`#rrggbb`).
---@param value string # the value to check.
---@param opts vim.assert.StringColorOpts|nil # options for the function.
---@return string|nil # the value if it is a string.
function vim.assert.color_string(value, opts)
    opts = vim.tbl_merge(opts, { optional = false })

    local color = vim.assert.string(value, { optional = opts.optional })

    if type(color) == 'string' then
        if not color:match '^#%x%x%x%x%x%x$' then
            error(string.format('expected a color string in the format `#rrggbb`, got `%s`.', color))
        end

        return color
    end
end

---@class (exact) vim.assert.ListOpts # Options for the `list` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field default any[] | nil # default value if `nil`.
---@field types ('string' | 'number' | 'boolean' | 'table' | 'nil' | 'callable' | 'integer' | 'list')[]

--- Checks if a given value is a integer.
---@generic T # the type of the values in the list.
---@param value T[]|nil # the value to check.
---@param opts vim.assert.ListOpts|nil # options for the function.
---@return T[]|nil # the value if it is a string.
function vim.assert.list(value, opts)
    opts = vim.tbl_merge(opts, { optional = false, default = nil, types = nil })

    assert(opts.types == nil or vim.islist(opts.types))
    assert(opts.optional == nil or type(opts.optional) == 'boolean')
    assert(opts.default == nil or vim.islist(opts.default))

    if value == nil and opts.optional then
        if opts.default then
            return opts.default
        end

        error(string.format 'expected a `list`, got `nil`.')
    elseif not vim.islist(value) then
        error(string.format('expected a `list`, got `%s`.', type(value)))
    elseif vim.islist(opts.types) then
        for i, v in
            ipairs(value --[[@as any[] ]])
        do
            local value_type = type(v)
            if not vim.tbl_contains(opts.types, value_type) then
                error(
                    string.format(
                        'expected a `list` of types `%s`, got a `%s` at index `%d`.',
                        table.concat(opts.types, ', '),
                        value_type,
                        i
                    )
                )
            end
        end
    end

    return value
end

---@class (exact) vim.assert.BufferIdOpts # Options for the `buffer_id` function.

--- Checks if a given value is a integer.
---@param value integer|nil # the value to check.
---@param opts vim.assert.IntegerOpts|nil # options for the function.
---@return integer|nil # the value if it is a string.
function vim.assert.buffer_id(value, opts)
    opts = vim.tbl_merge(opts, {})
    value = value or vim.api.nvim_get_current_buf()

    if not vim.is_integer(value) then
        error(string.format('expected a `buffer id`, got a `%s`.', type(value)))
    end

    if not vim.api.nvim_buf_is_valid(value) then
        error(string.format 'expected a valid `buffer`, but it is not.')
    end
end
