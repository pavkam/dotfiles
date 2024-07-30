---@class extra.markdown
local M = {}

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

---@class extra.markdown.EscapeMarkdownOpts
---@field use_nil boolean|nil # Whether to use 'nil' for nil values (default: true)
---@field full boolean|nil # Whether to escape all characters (default: false)

--- Escapes a value for markdown
---@param str any # the value to escape
---@param opts extra.markdown.EscapeMarkdownOpts|nil # the options to use
---@return string # the escaped value
local function escape_markdown(str, opts)
    str = type(str) == 'string' and str or vim.inspect(str)
    opts = opts or {}

    opts.use_nil = opts.use_nil == nil and true or opts.use_nil

    if not str and opts.use_nil then
        return 'nil'
    end

    local substitutions = opts.full and markdown_substitutions or essential_markdown_substitutions

    for _, replacement in ipairs(substitutions) do
        str = str:gsub(replacement[1], replacement[2])
    end

    return str
end

-- Makes a table Markdown-safe
---@param tbl table # The table to serialize
---@return string # The serialized table
local function escape_table(tbl)
    local res = {}

    table.insert(res, '| Key | Value |')
    table.insert(res, '|-----|-------|')

    for key, val in pairs(tbl) do
        table.insert(res, '| ' .. escape_markdown(tostring(key)) .. ' | ' .. escape_markdown(tostring(val)) .. ' |')
    end

    return table.concat(res, '\n')
end

-- Makes a value Markdown-safe
---@param value any # The value to make safe
---@return string # The Markdown-safe value
function M.escape(value)
    if type(value) == 'table' then
        return escape_table(value)
    else
        return escape_markdown(tostring(value))
    end
end

--- Checks if a table is a list of short number of elements that can be represented as a string
---@param list any[] # The list to check
---@return boolean, string # The string representation of the list and whether it fits
local function flatten_list(list, max_length)
    assert(vim.islist(list))

    local result = ''

    for _, v in ipairs(list) do
        if type(v) == 'table' then
            return false, ''
        end

        if #result > 0 then
            result = result .. ', '
        end
        result = result .. '`' .. escape_markdown(v) .. '`'
    end

    return (#result <= max_length), result
end

--- Converts a value to a markdown string
---@param value any # The value to convert
---@param indent number # The current indentation level
---@param max_length number # The maximum length of an expanded list
---@return string # The markdown string
local function from_value(value, indent, max_length)
    assert(type(indent) == 'number' and indent >= 0)
    assert(type(max_length) == 'number' and max_length > 0)

    local markdown_str = ''
    local prefix = string.rep('  ', indent)

    if vim.islist(value) then
        local list_length = #value

        if list_length == 1 then
            local single_value = value[1]
            if type(single_value) == 'table' then
                markdown_str = markdown_str .. from_value(single_value, indent, max_length)
            else
                markdown_str = markdown_str .. prefix .. '- `' .. escape_markdown(single_value) .. '`\n'
            end
        elseif list_length > 0 then
            local fits, flattened = flatten_list(value, max_length)
            if fits then
                markdown_str = markdown_str .. prefix .. '- ' .. flattened .. '\n'
            else
                for i, v in ipairs(value) do
                    if type(v) == 'table' then
                        markdown_str = markdown_str
                            .. prefix
                            .. '- ('
                            .. i
                            .. '):\n'
                            .. from_value(v, indent + 1, max_length)
                    else
                        markdown_str = markdown_str .. prefix .. '- (' .. i .. '): `' .. escape_markdown(v) .. '`\n'
                    end
                end
            end
        end
    elseif type(value) == 'table' then
        for k, v in pairs(value) do
            if type(v) == 'table' then
                ---@type boolean|nil, string|nil
                local fits, flattened
                if vim.islist(v) then
                    fits, flattened = flatten_list(v, max_length)
                end

                if fits then
                    markdown_str = markdown_str .. prefix .. '- **' .. escape_markdown(k) .. '**: ' .. flattened .. '\n'
                else
                    markdown_str = markdown_str .. prefix .. '- **' .. escape_markdown(k) .. '**:\n'
                    markdown_str = markdown_str .. from_value(v, indent + 1, max_length)
                end
            else
                markdown_str = markdown_str
                    .. prefix
                    .. '- **'
                    .. escape_markdown(k)
                    .. '**: `'
                    .. escape_markdown(v)
                    .. '`\n'
            end
        end
    else
        markdown_str = markdown_str .. prefix .. '- `' .. escape_markdown(value) .. '`\n'
    end

    return markdown_str
end

---@class extra.markdown.FromValueOpts
---@field max_length number|nil # The maximum length of an expanded list (default: 60)

--- Converts a value to a markdown string
---@param value any # The value to convert
---@param opts extra.markdown.FromValueOpts|nil # The options to use
function M.from_value(value, opts)
    opts = opts or {}
    return from_value(value, 0, opts.max_length or 200)
end

return M
