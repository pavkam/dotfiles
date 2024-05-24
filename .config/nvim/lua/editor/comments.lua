local syntax = require 'editor.syntax'

---@class editor.comments
local M = {}
M.langs = {}

M.langs.xml = '<!-- %s -->'
M.langs.xaml = M.langs.xml
M.langs.cs_project = M.langs.xml
M.langs.fsharp_project = M.langs.xml
M.langs.html = M.langs.xml
M.langs.c = { '// %s', '/* %s */' }
M.langs.c_sharp = M.langs.c
M.langs.cpp = M.langs.c
M.langs.fsharp = M.langs.c
M.langs.css = '/* %s */'
M.langs.ini = '; %s'
M.langs.javascript = vim.tbl_extend('keep', M.langs.c, {
    call_expression = '// %s',
    jsx_attribute = '// %s',
    jsx_element = '{/* %s */}',
    jsx_fragment = '{/* %s */}',
    spread_element = '// %s',
    statement_block = '// %s',
})
M.langs.jsx = M.langs.javascript
M.langs.javascriptreact = M.langs.jsx
M.langs['javascript.jsx'] = M.langs.jsx
M.langs.typescript = M.langs.javascript
M.langs.tsx = M.langs.typescript
M.langs.typescriptreact = M.langs.tsx
M.langs['typescript.tsx'] = M.langs.tsx

M.langs.vim = '" %s'
M.langs.lua = { '-- %s', '--- %s' }

-- backup the original get_option function
M.original_get_option = vim.filetype.get_option

local option_name = 'commentstring'

-- Resolve the commentstring for the current buffer
---@param window? integer # The window to resolve the commentstring for
---@param file_type string # The filetype to resolve the commentstring for
---@return string[] # The resolved commentstrings
local function resolve(window, file_type)
    assert(type(file_type) == 'string')

    -- find the correct commentstring for the current language
    local lang = vim.treesitter.language.get_lang(file_type) or file_type
    local spec = M.langs[lang]

    ---@type string[]
    local result = {}

    if type(spec) == 'string' then
        table.insert(result, spec)
    elseif vim.islist(spec) then
        for _, v in ipairs(spec) do
            table.insert(result, v)
        end
    elseif type(spec) == 'table' then
        local node = syntax.node_under_cursor(window, { ignore_indent = true, lang = lang })
        while node do
            if spec[node:type()] then
                table.insert(result, spec[node:type()])
                break
            end
            node = node:parent()
        end
    end

    dbg(result)

    -- add the original commentstring
    local original = M.original_get_option(file_type, option_name)
    if type(original) == 'string' then
        table.insert(result, original)
    end

    return result
end

--- Get the commentstring for the given file type.
---@param window? integer # The window to get the commentstring for.
---@param file_type string # The filetype to get the commentstring for.
---@return string|nil # The commentstring for the given file type.
function M.select_matching(window, file_type)
    local patterns = resolve(window, file_type)

    ---@type string|nil
    local best_option
    local n = math.huge

    local line = syntax.current_line(window)
    for _, pattern in ipairs(patterns) do
        local left, right = pattern:match '^%s*(.-)%s*%%s%s*(.-)%s*$'

        if left and right then
            local l, m, r = line:match('^%s*' .. vim.pesc(left) .. '(%s*)(.-)(%s*)' .. vim.pesc(right) .. '%s*$')

            if m and #m < n then
                best_option = vim.trim(left .. l .. '%s' .. r .. right)
                n = #m
            end

            if not best_option then
                best_option = vim.trim(left .. ' %s ' .. right)
            end
        end
    end

    return best_option
end

--- Override the default commentstring for a filetype
---@param file_type string # The filetype to override the commentstring for
---@param option string # The requested option
---@return boolean|integer|string # The commentstring for the filetype or whatever the original get_option function returns
function M.get_option(file_type, option)
    if option ~= option_name then
        return M.original_get_option(file_type, option)
    end

    local c = M.select_matching(nil, file_type) or M.original_get_option(file_type, option)
    dbg(file_type, c)
    return c
end

---@diagnostic disable-next-line: duplicate-set-field
vim.filetype.get_option = M.get_option

return M
