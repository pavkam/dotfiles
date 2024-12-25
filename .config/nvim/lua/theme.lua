--- Theme API
---@class theme
local M = {}

---@class highlight_group_definition # The definition of a highlight group.
---@field bold boolean|nil # whether the text should be bold.
---@field standout boolean|nil # whether the text should standout.
---@field strikethrough boolean|nil # whether the text should have a strikethrough.
---@field underline 'single'|'curl'|'double'|'dotted'|'dashed'|nil # the underline style.
---@field italic boolean|nil # whether the text should be italic.
---@field foreground string|nil # the foreground color.
---@field background string|nil # the background color.

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
