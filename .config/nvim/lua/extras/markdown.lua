local utils = require 'core.utils'

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

--- Escapes a value for markdown
---@param str any # the value to escape
---@return string # the escaped value
local function escape_markdown(str)
    str = type(str) == 'string' and str or vim.inspect(str)
    if not str then
        return '*nil*'
    end

    for _, replacement in ipairs(markdown_substitutions) do
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

return M
