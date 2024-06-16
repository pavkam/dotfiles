local utils = require 'core.utils'
local M = {}

--- Extracts the color and attributes from a highlight group.
---@param name string # the name of the highlight group
---@return { fg: string, gui: string }|nil # the color and attributes of the highlight group
function M.hl_fg_color_and_attrs(name)
    assert(type(name) == 'string' and name ~= '')

    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })

    if not hl then
        return nil
    end

    local fg = hl.fg or 0
    local attrs = {}

    for _, attr in ipairs { 'italic', 'bold', 'undercurl', 'underdotted', 'underlined', 'strikethrough' } do
        if hl[attr] then
            table.insert(attrs, attr)
        end
    end

    return { fg = string.format('#%06x', fg), gui = table.concat(attrs, ',') }
end

--- Sets the highlight group for a name
---@param name string # the name of the highlight group
---@vararg table<string, any>|string # the attributes to set
function M.make_hl(name, ...)
    assert(type(name) == 'string' and name ~= '')

    local args = { ... }

    assert(#args > 0)

    if #args == 1 and type(args[1]) == 'string' then
        vim.api.nvim_set_hl(0, name, { link = args[1] })
        return
    end

    ---@type table<string, any>
    local hls = {}
    for _, m in ipairs(args) do
        if type(m) == 'table' then
            table.insert(hls, m)
        elseif type(m) == 'string' then
            table.insert(hls, vim.api.nvim_get_hl(0, { name = m, link = false }))
        elseif type(m) == 'integer' then
            table.insert(hls, vim.api.nvim_get_hl(0, { id = m, link = false }))
        else
            error 'Invalid highlight group type'
        end
    end

    -- merge and cleanup the final table
    local merged = utils.tbl_merge(unpack(hls))
    vim.api.nvim_set_hl(0, name, merged)
end

--- Converts a hex color to an RGB table
---@param c  string
local function hex_to_rgb(c)
    c = c or '#000000'

    c = string.lower(c)
    return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

--- Blends two colors
---@param foreground string # The foreground color
---@param background string # The background color
---@param alpha number|string # The number between 0 and 1
---@return string # The blended color
function M.blend(foreground, background, alpha)
    alpha = type(alpha) == 'string' and (tonumber(alpha, 16) / 0xff) or alpha
    local bg = hex_to_rgb(background)
    local fg = hex_to_rgb(foreground)

    local blendChannel = function(i)
        local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
        return math.floor(math.min(math.max(0, ret), 255) + 0.5)
    end

    return string.format('#%02x%02x%02x', blendChannel(1), blendChannel(2), blendChannel(3))
end

--- Lightens a color
---@param hex string # The color to lighten
---@param amount number|string # The amount to lighten
---@param background string|nil # The background color
---@return string # The lightened color
function M.darken(hex, amount, background)
    return M.blend(hex, background or '#000000', amount)
end

--- Lightens a color
---@param hex string # The color to lighten
---@param amount number|string # The amount to lighten
---@param foreground string|nil # The background color
---@return string # The lightened color
function M.lighten(hex, amount, foreground)
    return M.blend(hex, foreground or '#FFFFFF', amount)
end

return M
