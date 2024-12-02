-- Provides a set of functions to check if a value is of a certain type.
---@class expect
vim.assert = {}

-- Checks if a given value is an integer.
---@param value any # the value to check.
---@return boolean # whether the value is an integer.
function vim.is_integer(value)
    return type(value) == 'number' and value % 1 == 0
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
