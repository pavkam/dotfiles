local syntax = require 'syntax'

---@class editor.comments
local M = {}

---@alias editor.comments.CommentSpec { prefix: string, suffix?: string }

---@type editor.comments.CommentSpec
local markup_spec = { prefix = '<!--', suffix = '-->' }
---@type editor.comments.CommentSpec
local c_line_spec = { prefix = '//' }
---@type editor.comments.CommentSpec
local c_block_spec = { prefix = '/*', suffix = '*/' }
---@type editor.comments.CommentSpec[]
local c_spec = { c_line_spec, c_block_spec }
---@type editor.comments.CommentSpec
local jsx_block_spec = { prefix = '{/*', suffix = '*/}' }

---@alias editor.comments.CommentSpecDef
---|editor.comments.CommentSpec
---|editor.comments.CommentSpec[]
---|table<string, editor.comments.CommentSpec[]>

---@type table<string, editor.comments.CommentSpecDef>
M.langs = {}
M.langs.xml = markup_spec
M.langs.xaml = markup_spec
M.langs.cs_project = markup_spec
M.langs.fsharp_project = markup_spec
M.langs.html = markup_spec
M.langs.sh = { prefix = '#' }
M.langs.bash = M.langs.sh
M.langs.c = c_spec
M.langs.c_sharp = c_spec
M.langs.cpp = c_spec
M.langs.fsharp = c_spec
M.langs.css = c_block_spec
M.langs.ini = { prefix = ';' }
M.langs.javascript = vim.tbl_extend('keep', M.langs.c, {
    call_expression = c_line_spec,
    jsx_attribute = c_line_spec,
    jsx_element = jsx_block_spec,
    jsx_fragment = jsx_block_spec,
    spread_element = c_line_spec,
    statement_block = c_line_spec,
}) --[[@as table<string, editor.comments.CommentSpec[]>]]
M.langs.jsx = M.langs.javascript
M.langs.javascriptreact = M.langs.jsx
M.langs['javascript.jsx'] = M.langs.jsx
M.langs.typescript = M.langs.javascript
M.langs.tsx = M.langs.typescript
M.langs.typescriptreact = M.langs.tsx
M.langs['typescript.tsx'] = M.langs.tsx
M.langs.vim = { prefix = '"' }
M.langs.lua = { { prefix = '--' }, { prefix = '---' }, { prefix = '--[[', suffix = ']]' } }

-- backup the original get_option function
M.original_get_option = vim.filetype.get_option

local option_name = 'commentstring'

-- Resolve the comment-string for the current buffer
---@param window integer|nil # The window to resolve the comment-string for
---@param file_type string # The file-type to resolve the comment-string for
---@return editor.comments.CommentSpec[] # The resolved comment-string
function M.resolve(window, file_type)
    assert(type(file_type) == 'string')

    -- find the correct comment-string for the current language
    local lang = vim.treesitter.language.get_lang(file_type) or file_type
    local spec = M.langs[lang]

    ---@type string[]
    local result = {}

    if spec and spec.prefix then
        table.insert(result, spec)
    elseif vim.islist(spec) then
        for _, v in ipairs(spec) do
            table.insert(result, v)
        end
    elseif type(spec) == 'table' then
        local node = syntax.node { window = window, ignore_indent = true, lang = lang }
        while node do
            if spec[node:type()] then
                table.insert(result, spec[node:type()])
                break
            end
            node = node:parent()
        end
    end

    return result
end

---@class (exact) editor.comments.CommentOptions # The comment options for the given window.
---@field single_line string # The single line comment string.
---@field multi_line_start string # The multi line comment start string.
---@field multi_line_end string # The multi line comment end string.

--- Get the comment options for the given window.
---@param window integer|nil # The window to get the comment options for.
---@return editor.comments.CommentOptions|nil # The comment options for the given window.
function M.comment_options(window)
    window = window or vim.api.nvim_get_current_win()

    local buffer = vim.api.nvim_win_get_buf(window)
    local file_type
    if vim.api.nvim_buf_is_valid(buffer) then
        file_type = vim.api.nvim_buf_get_option_value('filetype', { bufnr = buffer })
        local comments = M.resolve(window, file_type)

        ---@type string|nil
        local single_line
        ---@type string|nil
        local multi_line_start
        ---@type string|nil
        local multi_line_end

        for _, comment in ipairs(comments) do
            if comment.prefix and not comment.suffix then
                single_line = comment.prefix
            else
                multi_line_start = comment.prefix
                multi_line_end = comment.suffix
            end
        end

        return {
            single_line = single_line,
            multi_line_start = multi_line_start,
            multi_line_end = multi_line_end,
        }
    end

    return nil
end

--- Get the comment-string for the given file type.
---@param window integer|nil # The window to get the comment-string for.
---@param file_type string # The file-type to get the comment-string for.
---@return string|nil # The comment-string for the given file type.
function M.select_matching(window, file_type)
    ---@type string[]
    local patterns = vim.iter(M.resolve(window, file_type))
        :map(
            ---@param item editor.comments.CommentSpec
            function(item)
                return string.format('%s %%s %s', item.prefix, item.suffix or '')
            end
        )
        :totable()

    -- add the original comment-string
    local original = M.original_get_option(file_type, option_name)
    if type(original) == 'string' then
        table.insert(patterns, original)
    end

    ---@type string|nil
    local best_option
    local n = math.huge

    local line = syntax.current_line_text { window = window }
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

--- Override the default comment-string for a file-type
---@param file_type string # The file-type to override the comment-string for
---@param option string # The requested option
---@return boolean|integer|string # The comment-string for the file-type
function M.get_option(file_type, option)
    if option ~= option_name then
        return M.original_get_option(file_type, option)
    end

    local c = M.select_matching(nil, file_type) or M.original_get_option(file_type, option)
    return c
end

---@diagnostic disable-next-line: duplicate-set-field
vim.filetype.get_option = M.get_option

return M
