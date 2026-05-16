-- BufferAST: per-buffer TreeSitter AST facade.
-- Accessed via buf:ast(). Wraps all treesitter operations scoped to a specific buffer.

local BufferAST = Class('BufferAST')

---@param bufnr integer
function BufferAST:init(bufnr)
    self._bufnr = bufnr
end

--- Check if a treesitter parser is available for this buffer's filetype.
---@return boolean
function BufferAST:has_parser()
    local ok = pcall(vim.treesitter.get_parser, self._bufnr)
    return ok
end

--- Get the treesitter parser for this buffer.
---@return vim.treesitter.LanguageTree|nil
function BufferAST:parser()
    local ok, parser = pcall(vim.treesitter.get_parser, self._bufnr)
    return ok and parser or nil
end

--- Get the language of this buffer's parser.
---@return string|nil
function BufferAST:language()
    local p = self:parser()
    return p and p:lang() or nil
end

--- Get a treesitter query for this buffer's language.
---@param query_name string # e.g. 'textobjects', 'highlights', 'folds'
---@return vim.treesitter.Query|nil
function BufferAST:query(query_name)
    local lang = self:language()
    if not lang then return nil end
    local ok, query = pcall(vim.treesitter.query.get, lang, query_name)
    return ok and query or nil
end

--- Get the root syntax tree node.
---@return TSNode|nil
function BufferAST:root()
    local p = self:parser()
    if not p then return nil end
    local trees = p:parse()
    return trees and trees[1] and trees[1]:root() or nil
end

--- Get the treesitter node at a position.
---@param row integer|nil # 0-indexed (nil = cursor row)
---@param col integer|nil # 0-indexed (nil = cursor col)
---@return TSNode|nil
function BufferAST:node_at(row, col)
    if not self:has_parser() then return nil end
    if not row then
        local win = vim.fn.bufwinid(self._bufnr)
        if win == -1 then win = 0 end
        local cursor = vim.api.nvim_win_get_cursor(win)
        row, col = cursor[1] - 1, cursor[2]
    end
    local ok, node = pcall(vim.treesitter.get_node, { bufnr = self._bufnr, pos = { row, col } })
    return ok and node or nil
end

--- Get the type of the node under the cursor.
---@return string|nil # e.g. 'identifier', 'string', 'function_declaration'
function BufferAST:node_type()
    local node = self:node_at()
    return node and node:type() or nil
end

--- Get the category of the node under the cursor.
---@return string|nil # 'identifier', 'string', 'comment', 'keyword', 'operator', 'number', 'type', nil
function BufferAST:node_category()
    local node = self:node_at()
    if not node then return nil end
    local t = node:type()
    if t:match('identifier') or t:match('name') or t:match('field') then return 'identifier' end
    if t:match('string') then return 'string' end
    if t:match('comment') then return 'comment' end
    if t:match('keyword') or t == 'if' or t == 'else' or t == 'for' or t == 'while' or t == 'return' or t == 'function' then return 'keyword' end
    if t:match('operator') or t == '+' or t == '-' or t == '=' or t == '==' then return 'operator' end
    if t:match('number') or t:match('integer') or t:match('float') then return 'number' end
    if t:match('type') then return 'type' end
    return nil
end

--- Get the scope chain from cursor to root (function names, class names, etc.)
---@return string[]
function BufferAST:scope_chain()
    local node = self:node_at()
    if not node then return {} end
    local scopes = {}
    local current = node
    while current do
        local t = current:type()
        if t:match('function') or t:match('method') or t:match('class') or t:match('module') then
            local name_node = current:field('name')[1]
            if name_node then
                scopes[#scopes + 1] = vim.treesitter.get_node_text(name_node, self._bufnr)
            end
        end
        current = current:parent()
    end
    -- Reverse so outermost scope is first
    local reversed = {}
    for i = #scopes, 1, -1 do reversed[#reversed + 1] = scopes[i] end
    return reversed
end

--- Get a breadcrumb string showing the scope hierarchy.
---@return string
function BufferAST:breadcrumb()
    local chain = self:scope_chain()
    return table.concat(chain, ' > ')
end

--- Start treesitter highlighting for this buffer.
function BufferAST:start()
    pcall(vim.treesitter.start, self._bufnr)
end

--- Stop treesitter highlighting for this buffer.
function BufferAST:stop()
    pcall(vim.treesitter.stop, self._bufnr)
end

--- Replace the text of a treesitter node.
---@param node TSNode
---@param text string
function BufferAST:replace_node(node, text)
    local Buffer = require 'ide.Buffer'
    local sr, sc, er, ec = node:range()
    Buffer.get(self._bufnr):set_text(sr, sc, er, ec, { text })
end

--- Increment a number or toggle a boolean at the cursor.
--- Returns true if a value was modified.
---@param delta integer # amount to increment (use -1 for decrement)
---@return boolean
function BufferAST:increment_at_cursor(delta)
    local node = self:node_at()
    if not node then return false end

    local Buffer = require 'ide.Buffer'
    local buf = Buffer.get(self._bufnr)
    local sr, sc, er, ec = node:range()
    local lines = vim.api.nvim_buf_get_text(self._bufnr, sr, sc, er, ec, {})
    local str = table.concat(lines, '\n')
    local ntype = node:type()

    if ntype == 'number' or ntype == 'integer' or ntype == 'float' then
        local n = tonumber(str)
        if n then
            self:replace_node(node, tostring(n + delta))
            return true
        end
    elseif ntype == 'true' or ntype == 'false' then
        local cur = (ntype == 'true') and 1 or 0
        local new = (cur + delta) > 0
        local ft = buf:filetype()
        local t_str = ft == 'python' and (new and 'True' or 'False') or (new and 'true' or 'false')
        self:replace_node(node, t_str)
        return true
    end

    return false
end

---@return string
function BufferAST:__tostring()
    return string.format('BufferAST(buf=%d, parser=%s)', self._bufnr, self:has_parser() and 'yes' or 'no')
end

return BufferAST
