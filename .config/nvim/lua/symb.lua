---@alias symbol string | { [1]: string, hl: string } # A symbol.

---@class (exact) icon # An icon.
---@field symbol symbol # the symbol to display.
---@field fit fun(width: integer): icon # a function to fit the symbol to a width.
---@field with_hl fun(hl: string): icon # a function to set the highlight group of the icon.
---@field no_hl fun(): icon # a function to remove the highlight group of the icon.
---@field replace_hl fun(icon: icon): icon # a function to replace the highlight group of the icon.

-- Creates an icon.
---@param text string # the text of the icon.
---@param hl string|nil # the highlight group of the icon.
---@return icon # the icon.
local function icon(text, hl)
    xassert {
        text = { text, { 'string', ['>'] = 0 } },
        hl = { hl, { 'nil', { 'string', ['>'] = 0 } } },
    }

    ---@type icon
    return table.freeze {
        ---@type symbol
        symbol = hl and { text, hl = hl } or text,
        ---@param width integer
        ---@return icon
        fit = function(width)
            xassert {
                width = { width, 'integer' },
            }

            local delta = math.abs(width) - vim.fn.strwidth(text)
            local new_text = text
            if delta > 0 then
                local spaces = string.rep(' ', delta)
                if width < 0 then
                    new_text = spaces .. text
                else
                    new_text = text .. spaces
                end
            end

            return icon(new_text, hl)
        end,
        ---@param new_hl string
        ---@return icon
        with_hl = function(new_hl)
            xassert {
                new_hl = { new_hl, { 'string', ['>'] = 0 } },
            }

            return icon(text, new_hl)
        end,
        ---@return icon
        no_hl = function()
            return icon(text)
        end,
        ---@param rep_icon icon
        ---@return icon
        replace_hl = function(rep_icon)
            xassert {
                rep_icon = {
                    rep_icon,
                    {
                        symbol = { 'string', 'table' }, -- TODO: better type check
                    },
                },
            }

            return icon(text, type(rep_icon.symbol) == 'table' and rep_icon.symbol.hl or nil)
        end,
    }
end

local file_type_to_icon_cache = {}

ide.plugin.on_symbol_provider_registered(function()
    table.clear(file_type_to_icon_cache)
end)

---@type table<string, icon>
local file_type_to_icon_map = setmetatable(file_type_to_icon_cache, {
    __index = function(t, key)
        xassert {
            key = { key, { 'string', ['>'] = 0 } },
        }

        local icn = rawget(t, key)
        if not icn then
            for _, plugin in ipairs(ide.plugin.symbol_provider_plugins) do
                local symb = plugin.get_file_type_symbol(key)
                if symb then
                    if type(symb) == 'table' then
                        icn = icon(symb[1], symb.hl)
                    else
                        icn = icon(symb)
                    end
                end
            end

            if not icn then
                icn = icon('', 'Error')
            end

            rawset(t, key, icn)
        end

        return icn
    end,
    __newindex = function()
        error('cannot set values for this table', 2)
    end,
    __metatable = false,
})

ide.theme.register_highlight_groups {
    LinterTool = { 'Statement', { italic = true } },
    FormatterTool = { 'Function', { italic = true } },
    LspTool = 'PreProc',
}

---@class symb
local M = {
    progress = {
        default = {
            icon '⣾',
            icon '⣽',
            icon '⣻',
            icon '⢿',
            icon '⡿',
            icon '⣟',
            icon '⣯',
            icon '⣷',
        },
    },
    tool = {
        formatter = file_type_to_icon_map,
        linter = file_type_to_icon_map,
        lsp = file_type_to_icon_map,
    },
    state = {
        disabled = icon('✗', 'Error'),
    },
}

return table.freeze(M)
