-- Text manipulation utilities.
---@class text
local M = {}

---@class (exact) text_abbreviate_options # Options for abbreviating a string.
---@field max number|nil # The maximum length of the string (default: 40).
---@field ellipsis string|nil # The ellipsis to append to the cut-off string (default: '...').

-- Abbreviate a string with an optional maximum length and ellipsis.
---@param str string # the string to abbreviate.
---@param opts text_abbreviate_options|nil # the options for the abbreviation.
---@return string # the abbreviated string.
function M.abbreviate(str, opts)
    opts = table.merge(opts, { max = 40, ellipsis = require('icons').TUI.Ellipsis })
    str = str or ''

    xassert {
        str = { str, 'string' },
        opts = {
            opts,
            {
                max = { 'integer', ['>'] = 0, ['<'] = 250 },
                ellipsis = 'string',
            },
        },
    }

    assert(type(str) == 'string')
    assert(type(opts.max) == 'number' and opts.max > 0)
    assert(type(opts.ellipsis) == 'string')

    if vim.fn.strwidth(str) > opts.max then
        return vim.fn.strcharpart(str, 0, opts.max - vim.fn.strwidth(opts.ellipsis)) .. opts.ellipsis
    end

    return str
end

---@type table<string, string>
local markdown_substitutions = {
    { '%*', '\\*' },
    { '#', '\\#' },
    { '/', '\\/' },
    { '%(', '\\(' },
    { '%)', '\\)' },
    { '%[', '\\[' },
    { '%]', '\\]' },
    { '<', '&lt;' },
    { '>', '&gt;' },
    { '_', '\\_' },
    { '`', '\\`' },
}

local essential_markdown_substitutions = {
    { '<', '&lt;' },
    { '>', '&gt;' },
    { '`', '\\`' },
    { '\n', ' ' },
}

---@class (exact) markdown_escape_options # Options for escaping a string for markdown.
---@field use_nil boolean|nil # whether to use 'nil' for nil values (default: true).
---@field full boolean|nil # whether to escape all characters (default: false).

--- Escapes a value for markdown.
---@param value any # the value to escape.
---@param opts markdown_escape_options|nil # the options to use.
---@return string # the escaped value
local function escape_markdown(value, opts)
    opts = table.merge(opts, { use_nil = true, full = false })

    xassert {
        opts = {
            opts,
            {
                use_nil = 'boolean',
                full = 'boolean',
            },
        },
    }

    local substitutions = opts.full and markdown_substitutions or essential_markdown_substitutions

    local str = inspect(value, { new_line = '' })

    for _, replacement in ipairs(substitutions) do
        str = str:gsub(replacement[1], replacement[2])
    end

    return str
end

-- Escapes a table for markdown.
---@param t table # the table to escape.
---@return string # the escaped table as a string.
local function escape_table(t)
    xassert {
        t = { t, 'table' },
    }

    local res = {
        '| Key | Value |',
        '|-----|-------|',
    }

    for key, val in pairs(t) do
        table.insert(res, '| ' .. escape_markdown(key) .. ' | ' .. escape_markdown(val) .. ' |')
    end

    return table.concat(res, '\n')
end

-- Escapes a list for markdown.
---@param list any[] # the list to escape.
---@return string # the escaped list as a string.
local function escape_list(list)
    xassert {
        list = { list, 'list' },
    }

    return table.concat(
        table.list_map(list, function(v)
            return string.format('`%s`', escape_markdown(v))
        end),
        ', '
    )
end

-- Converts a value to a markdown string.
---@param value any # the value to convert.
---@param indent integer # the indentation level.
---@param max_length integer # the maximum length of an expanded list.
---@param path table<table, boolean> # the path to the value.
---@return string # The markdown string
local function from_value(value, indent, max_length, path)
    xassert {
        indent = { indent, { 'integer', ['>'] = -1 } },
        max_length = { max_length, { 'integer', ['>'] = 0 } },
    }

    ---@type string[]
    local markdown_parts = {}
    local prefix = string.rep('  ', indent)

    local t, ty = xtype(value)
    if t == 'table' then
        if path[value] then
            return string.format('%s- **[circular reference]**', prefix)
        end

        path[value] = true
    end

    if ty == 'list' then
        local list_length = #value

        if list_length == 1 then
            local single_value = value[1]

            _, ty = xtype(single_value)
            if ty == 'table' then
                table.insert(markdown_parts, from_value(single_value, indent, max_length, path))
            else
                table.insert(markdown_parts, string.format('%s- `%s`', prefix, escape_markdown(single_value)))
            end
        elseif list_length > 1 then
            local escaped_list = escape_list(value)
            if #escaped_list <= max_length then
                table.insert(markdown_parts, string.format('%s- %s', prefix, escaped_list))
            else
                for i, v in ipairs(value) do
                    _, ty = xtype(v)
                    if ty == 'table' then
                        table.insert(
                            markdown_parts,
                            string.format('%s- (%d):\n%s', prefix, i, from_value(v, indent + 1, max_length, path))
                        )
                    else
                        table.insert(markdown_parts, string.format('%s- (%d): `%s`', prefix, i, escape_markdown(v)))
                    end
                end
            end
        end
    elseif ty == 'table' then
        for k, v in pairs(value) do
            _, ty = xtype(v)
            if ty == 'table' then
                table.insert(
                    markdown_parts,
                    string.format(
                        '%s- **%s**:\n%s',
                        prefix,
                        escape_markdown(k),
                        from_value(v, indent + 1, max_length, path)
                    )
                )
            elseif ty == 'list' then
                local escaped_list = escape_list(v)

                if #escaped_list <= max_length then
                    table.insert(
                        markdown_parts,
                        string.format('%s- **%s**: %s', prefix, escape_markdown(k), escaped_list)
                    )
                else
                    table.insert(
                        markdown_parts,
                        string.format(
                            '%s- **%s**:\n%s',
                            prefix,
                            escape_markdown(k),
                            from_value(v, indent + 1, max_length, path)
                        )
                    )
                end
            else
                table.insert(
                    markdown_parts,
                    string.format('%s- **%s**: `%s`', prefix, escape_markdown(k), escape_markdown(v))
                )
            end
        end
    else
        table.insert(markdown_parts, string.format('%s- `%s`', prefix, escape_markdown(value)))
    end

    if t == 'table' then
        path[value] = nil
    end

    return table.concat(markdown_parts, '\n')
end

---@class (exact) markdown_format_options # Options for formatting a value as markdown.
---@field max_length number|nil # The maximum length of an expanded list (default: 60)

-- Markdown utilities.
M.markdown = {
    -- Converts a value to a markdown string.
    ---@param value any # the value to convert.
    ---@param opts markdown_format_options|nil # the options to use.
    format = function(value, opts)
        ---@type markdown_format_options
        opts = table.merge(opts, { max_length = 60 })

        xassert {
            opts = {
                opts,
                {
                    max_length = { 'integer', ['>'] = 0 },
                },
            },
        }

        return from_value(value, 0, opts.max_length, {})
    end,

    -- Escapes a value for markdown.
    ---@param value any # the value to escape.
    ---@return string # the escaped value.
    escape = function(value)
        local _, ty = type(value)
        if ty == 'table' then
            return escape_table(value)
        else
            return escape_markdown(tostring(value))
        end
    end,
}

return table.freeze(M)
