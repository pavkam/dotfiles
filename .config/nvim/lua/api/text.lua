-- Text manipulation utilities.
---@class api.text
local M = {}

---@class (exact) vim.AbbreviateOpts
---@field max number|nil # The maximum length of the string (default: 40)
---@field ellipsis string|nil # The ellipsis to append to the cut-off string (default: '...')

--- Abbreviate a string with an optional maximum length and ellipsis
---@param str string # The string to cut off
---@param opts vim.AbbreviateOpts|nil # The options for the abbreviation
---(if not provided, the default ellipsis is '...')
---@return string # The cut-off string
function M.abbreviate(str, opts)
    str = str or ''

    opts = opts or {}
    opts.max = opts.max or 40
    opts.ellipsis = opts.ellipsis or require('icons').TUI.Ellipsis

    assert(type(str) == 'string')
    assert(type(opts.max) == 'number' and opts.max > 0)
    assert(type(opts.ellipsis) == 'string')

    if vim.fn.strwidth(str) > opts.max then
        return vim.fn.strcharpart(str, 0, opts.max - vim.fn.strwidth(opts.ellipsis)) .. opts.ellipsis
    end

    return str
end

return table.freeze(M)
