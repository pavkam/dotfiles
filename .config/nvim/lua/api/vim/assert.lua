-- Provides a set of functions to check if a value is of a certain type.
---@class expect
vim.assert = {}

-- Checks if a given value is an integer.
---@param value any # the value to check.
---@return boolean # whether the value is an integer.
function vim.is_integer(value)
    return type(value) == 'number' and value % 1 == 0
end

---@class (exact) expect.CallableOpts # Options for the `callable` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field default function|nil # default value if `nil`.

--- Checks if a given value is a function.
---@generic T: function # the type of the value.
---@param value T # the value to check.
---@param opts expect.CallableOpts|nil # options for the function.
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

---@class (exact) expect.StringOpts # Options for the `string` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field empty boolean|nil # allow empty strings or not (default: `true`).
---@field default string|nil # default value if `nil`.

--- Checks if a given value is a string.
---@param value string # the value to check.
---@param opts expect.StringOpts|nil # options for the function.
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

---@class (exact) expect.NumberOpts # Options for the `number` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field min number|nil # minimum value (optional).
---@field default number|nil # default value if `nil`.

--- Checks if a given value is a number.
---@param value number|nil # the value to check.
---@param opts expect.NumberOpts|nil # options for the function.
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

---@class (exact) expect.IntegerOpts # Options for the `integer` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).
---@field min integer|nil # minimum value (optional).
---@field default integer|nil # default value if `nil`.

--- Checks if a given value is a integer.
---@param value integer|nil # the value to check.
---@param opts expect.IntegerOpts|nil # options for the function.
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

---@class (exact) expect.StringColorOpts # Options for the `color_string` function.
---@field optional boolean|nil # allow `nil` or not (default: `false`).

--- Checks if a given value is a color string (`#rrggbb`).
---@param value string # the value to check.
---@param opts expect.StringOpts|nil # options for the function.
---@return string|nil # the value if it is a string.
function vim.assert.color_string(value, opts)
    local color = vim.assert.string(value, opts and { optional = opts.optional, default = opts.default })

    if type(value) == 'string' then
        if not color:match '^#%x%x%x%x%x%x$' then
            error(string.format('expected a color string in the format `#rrggbb`, got `%s`.', color))
        end

        return color
    end
end
