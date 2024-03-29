---@class extra.markdown
local M = {}

local markdown_special_chars = { '\\', '`', '*', '_', '{', '}', '[', ']', '(', ')', '#', '+', '-', '.', '!', '|' }

-- Escapes a string for Markdown
---@param str string # The string to escape
---@return string # The escaped string
local function escape_markdown(str)
    assert(type(str) == 'string')

    for _, char in ipairs(markdown_special_chars) do
        str = str:gsub('%' .. char, '\\' .. char)
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
