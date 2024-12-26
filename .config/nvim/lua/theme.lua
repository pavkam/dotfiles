--- Theme API
---@class theme
local M = {}

---@alias rgb { [1]: integer, [2]: integer, [3]: integer } # the RGB color.

-- Converts a hex color to RGB.
---@param hex string # the hex color.
---@return rgb # the RGB color.
M.hex_to_rgb = memoize(function(hex)
    xassert {
        hex = {
            hex,
            {
                { 'string', ['*'] = '^#?%x%x%x%x%x%x$' },
                { 'string', ['*'] = '^#?%x%x%x$' },
            },
        },
    }

    local rgb = hex:gsub('#', '')

    if #rgb == 3 then
        local r = rgb:sub(1, 1)
        local g = rgb:sub(2, 2)
        local b = rgb:sub(3, 3)

        rgb = string.format('%s%s%s%s%s%s', r, r, g, g, b, b)
    end

    local r = tonumber(rgb:sub(1, 2), 16)
    local g = tonumber(rgb:sub(3, 4), 16)
    local b = tonumber(rgb:sub(5, 6), 16)

    return { r, g, b }
end)

local cterm_color_mapping = table.map({
    [16] = '#000000',
    [17] = '#00005f',
    [18] = '#000087',
    [19] = '#0000af',
    [20] = '#0000d7',
    [21] = '#0000ff',
    [22] = '#005f00',
    [23] = '#005f5f',
    [24] = '#005f87',
    [25] = '#005faf',
    [26] = '#005fd7',
    [27] = '#005fff',
    [28] = '#008700',
    [29] = '#00875f',
    [30] = '#008787',
    [31] = '#0087af',
    [32] = '#0087d7',
    [33] = '#0087ff',
    [34] = '#00af00',
    [35] = '#00af5f',
    [36] = '#00af87',
    [37] = '#00afaf',
    [38] = '#00afd7',
    [39] = '#00afff',
    [40] = '#00d700',
    [41] = '#00d75f',
    [42] = '#00d787',
    [43] = '#00d7af',
    [44] = '#00d7d7',
    [45] = '#00d7ff',
    [46] = '#00ff00',
    [47] = '#00ff5f',
    [48] = '#00ff87',
    [49] = '#00ffaf',
    [50] = '#00ffd7',
    [51] = '#00ffff',
    [52] = '#5f0000',
    [53] = '#5f005f',
    [54] = '#5f0087',
    [55] = '#5f00af',
    [56] = '#5f00d7',
    [57] = '#5f00ff',
    [58] = '#5f5f00',
    [59] = '#5f5f5f',
    [60] = '#5f5f87',
    [61] = '#5f5faf',
    [62] = '#5f5fd7',
    [63] = '#5f5fff',
    [64] = '#5f8700',
    [65] = '#5f875f',
    [66] = '#5f8787',
    [67] = '#5f87af',
    [68] = '#5f87d7',
    [69] = '#5f87ff',
    [70] = '#5faf00',
    [71] = '#5faf5f',
    [72] = '#5faf87',
    [73] = '#5fafaf',
    [74] = '#5fafd7',
    [75] = '#5fafff',
    [76] = '#5fd700',
    [77] = '#5fd75f',
    [78] = '#5fd787',
    [79] = '#5fd7af',
    [80] = '#5fd7d7',
    [81] = '#5fd7ff',
    [82] = '#5fff00',
    [83] = '#5fff5f',
    [84] = '#5fff87',
    [85] = '#5fffaf',
    [86] = '#5fffd7',
    [87] = '#5fffff',
    [88] = '#870000',
    [89] = '#87005f',
    [90] = '#870087',
    [91] = '#8700af',
    [92] = '#8700d7',
    [93] = '#8700ff',
    [94] = '#875f00',
    [95] = '#875f5f',
    [96] = '#875f87',
    [97] = '#875faf',
    [98] = '#875fd7',
    [99] = '#875fff',
    [100] = '#878700',
    [101] = '#87875f',
    [102] = '#878787',
    [103] = '#8787af',
    [104] = '#8787d7',
    [105] = '#8787ff',
    [106] = '#87af00',
    [107] = '#87af5f',
    [108] = '#87af87',
    [109] = '#87afaf',
    [110] = '#87afd7',
    [111] = '#87afff',
    [112] = '#87d700',
    [113] = '#87d75f',
    [114] = '#87d787',
    [115] = '#87d7af',
    [116] = '#87d7d7',
    [117] = '#87d7ff',
    [118] = '#87ff00',
    [119] = '#87ff5f',
    [120] = '#87ff87',
    [121] = '#87ffaf',
    [122] = '#87ffd7',
    [123] = '#87ffff',
    [124] = '#af0000',
    [125] = '#af005f',
    [126] = '#af0087',
    [127] = '#af00af',
    [128] = '#af00d7',
    [129] = '#af00ff',
    [130] = '#af5f00',
    [131] = '#af5f5f',
    [132] = '#af5f87',
    [133] = '#af5faf',
    [134] = '#af5fd7',
    [135] = '#af5fff',
    [136] = '#af8700',
    [137] = '#af875f',
    [138] = '#af8787',
    [139] = '#af87af',
    [140] = '#af87d7',
    [141] = '#af87ff',
    [142] = '#afaf00',
    [143] = '#afaf5f',
    [144] = '#afaf87',
    [145] = '#afafaf',
    [146] = '#afafd7',
    [147] = '#afafff',
    [148] = '#afd700',
    [149] = '#afd75f',
    [150] = '#afd787',
    [151] = '#afd7af',
    [152] = '#afd7d7',
    [153] = '#afd7ff',
    [154] = '#afff00',
    [155] = '#afff5f',
    [156] = '#afff87',
    [157] = '#afffaf',
    [158] = '#afffd7',
    [159] = '#afffff',
    [160] = '#d70000',
    [161] = '#d7005f',
    [162] = '#d70087',
    [163] = '#d700af',
    [164] = '#d700d7',
    [165] = '#d700ff',
    [166] = '#d75f00',
    [167] = '#d75f5f',
    [168] = '#d75f87',
    [169] = '#d75faf',
    [170] = '#d75fd7',
    [171] = '#d75fff',
    [172] = '#d78700',
    [173] = '#d7875f',
    [174] = '#d78787',
    [175] = '#d787af',
    [176] = '#d787d7',
    [177] = '#d787ff',
    [178] = '#d7af00',
    [179] = '#d7af5f',
    [180] = '#d7af87',
    [181] = '#d7afaf',
    [182] = '#d7afd7',
    [183] = '#d7afff',
    [184] = '#d7d700',
    [185] = '#d7d75f',
    [186] = '#d7d787',
    [187] = '#d7d7af',
    [188] = '#d7d7d7',
    [189] = '#d7d7ff',
    [190] = '#d7ff00',
    [191] = '#d7ff5f',
    [192] = '#d7ff87',
    [193] = '#d7ffaf',
    [194] = '#d7ffd7',
    [195] = '#d7ffff',
    [196] = '#ff0000',
    [197] = '#ff005f',
    [198] = '#ff0087',
    [199] = '#ff00af',
    [200] = '#ff00d7',
    [201] = '#ff00ff',
    [202] = '#ff5f00',
    [203] = '#ff5f5f',
    [204] = '#ff5f87',
    [205] = '#ff5faf',
    [206] = '#ff5fd7',
    [207] = '#ff5fff',
    [208] = '#ff8700',
    [209] = '#ff875f',
    [210] = '#ff8787',
    [211] = '#ff87af',
    [212] = '#ff87d7',
    [213] = '#ff87ff',
    [214] = '#ffaf00',
    [215] = '#ffaf5f',
    [216] = '#ffaf87',
    [217] = '#ffafaf',
    [218] = '#ffafd7',
    [219] = '#ffafff',
    [220] = '#ffd700',
    [221] = '#ffd75f',
    [222] = '#ffd787',
    [223] = '#ffd7af',
    [224] = '#ffd7d7',
    [225] = '#ffd7ff',
    [226] = '#ffff00',
    [227] = '#ffff5f',
    [228] = '#ffff87',
    [229] = '#ffffaf',
    [230] = '#ffffd7',
    [231] = '#ffffff',
    [232] = '#080808',
    [233] = '#121212',
    [234] = '#1c1c1c',
    [235] = '#262626',
    [236] = '#303030',
    [237] = '#3a3a3a',
    [238] = '#444444',
    [239] = '#4e4e4e',
    [240] = '#585858',
    [241] = '#626262',
    [242] = '#6c6c6c',
    [243] = '#767676',
    [244] = '#808080',
    [245] = '#8a8a8a',
    [246] = '#949494',
    [247] = '#9e9e9e',
    [248] = '#a8a8a8',
    [249] = '#b2b2b2',
    [250] = '#bcbcbc',
    [251] = '#c6c6c6',
    [252] = '#d0d0d0',
    [253] = '#dadada',
    [254] = '#e4e4e4',
    [255] = '#eeeeee',
}, M.hex_to_rgb)

-- Gets the closest cterm color to a hex color.
---@param hex string # the hex color.
---@return integer|nil # the cterm color.
M.closest_cterm_color = memoize(function(hex)
    local rgb2 = M.hex_to_rgb(hex)

    ---@type integer|nil
    local cterm_color
    ---@type number|nil
    local closest_distance

    for color, rgb1 in ipairs(cterm_color_mapping) do
        local distance = math.sqrt((rgb1[1] - rgb2[1]) ^ 2 + (rgb1[2] - rgb2[2]) ^ 2 + (rgb1[3] - rgb2[3]) ^ 2)

        if closest_distance == nil or distance < closest_distance then
            closest_distance = distance
            cterm_color = color
        end
    end

    return cterm_color
end)

---@class (exact) highlight_group_definition # The definition of a highlight group.
---@field bold boolean|nil # whether the text should be bold.
---@field standout boolean|nil # whether the text should standout.
---@field strikethrough boolean|nil # whether the text should have a strikethrough.
---@field underline 'single'|'curl'|'double'|'dotted'|'dashed'|nil # the underline style.
---@field italic boolean|nil # whether the text should be italic.
---@field foreground string|nil # the foreground color.
---@field cterm_foreground integer|nil # the cterm foreground color.
---@field background string|nil # the background color.
---@field cterm_background integer|nil # the cterm background color.

-- Gets the highlight group details.
---@param name string # the name of the highlight group.
---@return highlight_group_definition|nil # the details of the highlight group.
function M.get_highlight_group_details(name)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
    }

    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    if not hl then
        return nil
    end

    local res = {
        bold = hl.bold or hl.cterm and hl.cterm.bold,
        standout = hl.standout or hl.cterm and hl.cterm.standout,
        strikethrough = hl.strikethrough or hl.cterm and hl.cterm.strikethrough,
        underline = (hl.undercurl or hl.cterm and hl.cterm.undercurl) and 'curl'
            or (hl.underdotted or hl.cterm and hl.cterm.underdotted) and 'dotted'
            or (hl.underdashed or hl.cterm and hl.cterm.underdashed) and 'dashed'
            or (hl.underline or hl.cterm and hl.cterm.underline) and 'single'
            or (hl.underdouble or hl.cterm and hl.cterm.underdouble) and 'double'
            or nil,
        italic = hl.italic or hl.cterm and hl.cterm.italic,
        foreground = hl.fg ~= nil and string.format('#%06x', hl.fg) or nil,
        background = hl.bg ~= nil and string.format('#%06x', hl.bg) or nil,
        cterm_foreground = hl.cterm ~= nil and (hl.cterm.foreground or hl.cterm.ctermfg) or nil,
        cterm_background = hl.cterm ~= nil and (hl.cterm.background or hl.cterm.ctermbg) or nil,
    }

    if res.cterm_background == nil and res.background ~= nil then
        res.cterm_background = M.closest_cterm_color(res.background)
    end
    if res.cterm_foreground == nil and res.foreground ~= nil then
        res.cterm_foreground = M.closest_cterm_color(res.foreground)
    end

    ---@type highlight_group_definition
    return res
end

--- Sets the options for a highlight group.
---@param name string # the name of the highlight group.
---@param ... highlight_group_definition|string # the attributes to set.
local function register_highlight_group(name, ...)
    local args = { ... }
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        args = {
            args,
            {
                'list',
                ['>'] = 0,
                ['*'] = {
                    'string',
                    {
                        bold = { 'nil', 'boolean' },
                        standout = { 'nil', 'boolean' },
                        strikethrough = { 'nil', 'boolean' },
                        underline = { 'nil', { 'string', ['*'] = '^single|curl|double|dotted|dashed$' } },
                        italic = { 'nil', 'boolean' },
                        foreground = { 'nil', { 'string', ['*'] = '^#%x%x%x%x%x%x$' } },
                        background = { 'nil', { 'string', ['*'] = '^#%x%x%x%x%x%x$' } },
                        cterm_foreground = { 'nil', { 'integer', ['>'] = -1, ['<'] = 256 } },
                        cterm_background = { 'nil', { 'integer', ['>'] = -1, ['<'] = 256 } },
                    },
                },
            },
        },
    }

    if #args == 1 and xtype(args[1]) == 'string' then
        vim.api.nvim_set_hl(0, name, { link = args[1] })
        return
    end

    ---@type table<string, any>
    local hls = {}
    for _, m in ipairs(args) do
        local _, ty = xtype(m)

        if ty == 'table' then
            table.insert(hls, {
                bold = m.bold,
                standout = m.standout,
                strikethrough = m.strikethrough,
                underline = m.underline == 'single' or nil,
                undercurl = m.underline == 'curl' or nil,
                underdouble = m.underline == 'double' or nil,
                underdotted = m.underline == 'dotted' or nil,
                underdashed = m.underline == 'dashed' or nil,
                italic = m.italic,
                foreground = m.foreground,
                background = m.background,
                ctermfg = m.cterm_foreground,
                ctermbg = m.cterm_background,
            })
        elseif ty == 'string' then
            table.insert(
                hls,
                vim.api.nvim_get_hl(0, {
                    name = m --[[@as string]],
                    link = false,
                })
            )
        elseif ty == 'integer' then
            table.insert(
                hls,
                vim.api.nvim_get_hl(0, {
                    id = m --[[@as integer]],
                    link = false,
                })
            )
        else
            error(string.format('invalid highlight group type `%s`.', ty))
        end
    end

    local merged = table.merge(unpack(hls))
    vim.api.nvim_set_hl(0, name, merged)
end

---@alias highlight_group_definitions
---|table<string, (highlight_group_definition|string)[]|highlight_group_definition|string>

---@type highlight_group_definitions
local registered_highlight_groups = {}

-- Applies the registered highlight groups.
local function apply_registered_highlight_groups()
    for name, definition in pairs(registered_highlight_groups) do
        local _, ty = xtype(definition)
        if ty == 'string' then
            register_highlight_group(name, definition)
        elseif ty == 'list' then
            register_highlight_group(name, unpack(definition --[[@as table]]))
        elseif ty == 'table' then
            register_highlight_group(name, definition)
        end
    end
end

-- Registers a highlight group.
---@param groups highlight_group_definitions # the groups.
function M.register_highlight_groups(groups)
    xassert {
        groups = {
            groups,
            {
                'table',
                ['*'] = { 'string', 'list', 'table' },
            },
        },
    }

    registered_highlight_groups = table.merge(registered_highlight_groups, groups)
    apply_registered_highlight_groups()
end

--- Sets the current theme.
---@param name string|nil
function M.set(name)
    xassert {
        name = { name, { 'nil', { 'string', ['>'] = 0 } } },
    }

    vim.cmd.colorscheme(name) --TODO: pcall
end

---@type string|nil
M.current = vim.api.nvim_exec2('colorscheme', { output = true }).output

-- Triggered when the theme changes.
---@param callback fun(data: { color_scheme: string, before: boolean, after: boolean })
function M.on_change(callback)
    xassert { callback = { callback, 'callable' } }

    return ide.sched.subscribe_event({ 'ColorSchemePre', 'ColorScheme' }, function(args)
        callback(table.merge(args, {
            before = args.event == 'ColorSchemePre',
            after = args.event == 'ColorScheme',
            color_scheme = args.match,
        }))
    end, {
        description = 'Triggers when the theme changes.',
        group = 'theme.change',
    })
end

M.on_change(function(args)
    if args.after then
        M.current = args.color_scheme
        apply_registered_highlight_groups()
    end
end)

return table.freeze(M)
