-- TreeSitter-aware commenting extension.
-- Replaces Comment.nvim + nvim-ts-context-commentstring with native nvim 0.12 gc/gcc
-- enhanced by per-node-type commentstring resolution via treesitter.
--
-- NOTE: This extension monkey-patches vim.filetype.get_option and
-- vim._comment.operator — these are inherent integration points with
-- Neovim's native comment system that cannot be abstracted.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local TsComments = Class('TsComments', Extension)

function TsComments:init()
    Extension.init(self, 'TsComments')

    self._node_overrides = {
        typescriptreact = {
            jsx_element = '{/* %s */}',
            jsx_fragment = '{/* %s */}',
            jsx_self_closing_element = '{/* %s */}',
            jsx_opening_element = '{/* %s */}',
        },
        javascriptreact = {
            jsx_element = '{/* %s */}',
            jsx_fragment = '{/* %s */}',
            jsx_self_closing_element = '{/* %s */}',
            jsx_opening_element = '{/* %s */}',
        },
    }

    self._ft_overrides = {
        astro = '<!-- %s -->',
        css = '/* %s */',
        graphql = '# %s',
        handlebars = '{{! %s }}',
        html = '<!-- %s -->',
        ini = '; %s',
        markdown = '<!-- %s -->',
        scss = '// %s',
        sql = '-- %s',
        svelte = '<!-- %s -->',
        vue = '<!-- %s -->',
    }
end

---@param bufnr integer
---@param row integer # 0-indexed
---@return string|nil
function TsComments:_resolve_from_line(bufnr, row)
    local buf = Buffer.get(bufnr)
    local ft = buf:filetype()
    if not self._node_overrides[ft] then return nil end

    local line = buf:line(row + 1)
    local trimmed = line:match('^%s*(.-)%s*$')

    if trimmed:match('^<[A-Z]')
        or trimmed:match('^<[a-z]')
        or trimmed:match('^</')
        or trimmed:match('^/>')
        or trimmed:match('^{/%*')
    then
        return '{/* %s */}'
    end

    local node = IDE.treesitter:node_at_cursor({ bufnr = bufnr, pos = { row, #line - #trimmed } })
    if node then
        local check = node
        while check do
            if self._node_overrides[ft][check:type()] then
                return self._node_overrides[ft][check:type()]
            end
            check = check:parent()
        end
    end

    return nil
end

function TsComments:on_register(ctx)
    local ext = self

    -- Monkey-patch vim.filetype.get_option for commentstring resolution.
    -- This is an inherent Neovim integration point — no IDE abstraction possible.
    local orig_get_option = vim.filetype.get_option
    vim.filetype.get_option = function(filetype, option)
        if option ~= 'commentstring' then
            return orig_get_option(filetype, option)
        end

        local ft = filetype
        if ft == 'comment' then
            ft = Buffer.current():filetype()
        end

        if ext._node_overrides[ft] then
            return Buffer.current():option('commentstring')
        end

        if ext._ft_overrides[ft] then
            return ext._ft_overrides[ft]
        end

        return orig_get_option(filetype, option)
    end

    local jsx_fts = vim.tbl_keys(ext._node_overrides)
    ctx:hook({ 'CursorMoved', 'CursorMovedI' }, function(evt)
        local buf = Buffer.get(evt.buf)
        if not vim.tbl_contains(jsx_fts, buf:filetype()) then return end
        local cursor_row = Window.current():cursor().row
        local cs = ext:_resolve_from_line(evt.buf, cursor_row - 1)
        buf:set_option('commentstring', cs or '// %s')
    end, { desc = 'Update commentstring for JSX context' })

    -- Monkey-patch the native comment operator for line-aware JSX resolution.
    -- This is an inherent Neovim integration point — no IDE abstraction possible.
    local comment_mod = require('vim._comment')
    local orig_operator = comment_mod.operator
    comment_mod.operator = function(mode)
        if mode ~= nil then
            local lnum = IDE.marks:line("'[")
            local buf = Buffer.current()
            if ext._node_overrides[buf:filetype()] then
                local cs = ext:_resolve_from_line(buf:id(), lnum - 1)
                if cs then buf:set_option('commentstring', cs) end
            end
        end
        return orig_operator(mode)
    end

    ctx:notify('Native commenting with treesitter context')
end

return TsComments
