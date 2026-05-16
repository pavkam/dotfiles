-- Treesitter: syntax tree abstraction.
-- Wraps vim.treesitter into a clean API for node inspection,
-- scope detection, and text extraction.

local Treesitter = Class('Treesitter')

function Treesitter:init() end

--- Get the treesitter node at the cursor (or a position).
---@param opts { bufnr?: integer, pos?: integer[] }|nil
---@return TSNode|nil
function Treesitter:node_at_cursor(opts)
    opts = opts or {}
    local ok, node = pcall(vim.treesitter.get_node, {
        bufnr = opts.bufnr or 0,
        pos = opts.pos,
    })
    return ok and node or nil
end

--- Get the type of the node at cursor.
---@return string|nil
function Treesitter:node_type(opts)
    local node = self:node_at_cursor(opts)
    return node and node:type() or nil
end

--- Get the text of the node at cursor.
---@param opts { bufnr?: integer }|nil
---@return string|nil
function Treesitter:node_text(opts)
    opts = opts or {}
    local node = self:node_at_cursor(opts)
    if not node then return nil end
    return vim.treesitter.get_node_text(node, opts.bufnr or 0)
end

--- Get the text of a specific treesitter node.
---@param node TSNode
---@param bufnr integer|nil # buffer number (default 0)
---@return string
function Treesitter:text_of(node, bufnr)
    return vim.treesitter.get_node_text(node, bufnr or 0)
end

--- Detect what kind of syntax context the cursor is in.
---@param opts { bufnr?: integer }|nil
---@return 'identifier'|'comment'|'string'|'jsx'|'keyword'|nil
function Treesitter:context(opts)
    local node = self:node_at_cursor(opts)
    if not node then return nil end

    local ntype = node:type()

    if ntype:match('^jsx_') then return 'jsx' end

    local ident_types = {
        identifier = true, field_identifier = true, type_identifier = true,
        property_identifier = true, shorthand_property_identifier = true,
    }
    if ident_types[ntype] then return 'identifier' end

    -- Walk parents for comment/string context
    local current = node
    while current do
        local t = current:type()
        if t == 'comment' or t == 'line_comment' or t == 'block_comment' then
            return 'comment'
        end
        if t == 'string' or t == 'string_content' or t == 'template_string' then
            return 'string'
        end
        current = current:parent()
    end

    return nil
end

--- Get the enclosing scope chain (function, class, method names).
---@param opts { bufnr?: integer }|nil
---@return string[] # ordered from outermost to innermost
function Treesitter:scope_chain(opts)
    opts = opts or {}
    local node = self:node_at_cursor(opts)
    if not node then return {} end

    local scope_types = {
        function_declaration = true, method_declaration = true,
        method_definition = true, function_definition = true,
        arrow_function = true, class_definition = true,
        class_declaration = true, type_declaration = true,
        type_spec = true, interface_declaration = true,
    }

    local parts = {}
    local current = node
    while current do
        if scope_types[current:type()] then
            local name_node = current:field('name')[1]
            if name_node then
                local name = vim.treesitter.get_node_text(name_node, opts.bufnr or 0)
                parts[#parts + 1] = name
            end
        end
        current = current:parent()
    end

    -- Reverse to get outermost first
    local result = {}
    for i = #parts, 1, -1 do
        result[#result + 1] = parts[i]
    end
    return result
end

--- Get the enclosing scope as a formatted breadcrumb string.
---@param opts { bufnr?: integer, separator?: string }|nil
---@return string
function Treesitter:breadcrumb(opts)
    opts = opts or {}
    local chain = self:scope_chain(opts)
    return table.concat(chain, opts.separator or ' › ')
end

--- Check if the parser is available for a filetype.
---@param lang string|nil # language (defaults to current buffer's filetype)
---@return boolean
function Treesitter:has_parser(lang)
    local buf = vim.api.nvim_get_current_buf()
    local ok = pcall(vim.treesitter.get_parser, buf, lang)
    return ok
end

--- Start treesitter highlighting for a buffer.
---@param bufnr integer|nil
---@param lang string|nil
function Treesitter:start(bufnr, lang)
    pcall(vim.treesitter.start, bufnr or 0, lang)
end

--- Stop treesitter highlighting for a buffer.
---@param bufnr integer|nil
function Treesitter:stop(bufnr)
    pcall(vim.treesitter.stop, bufnr or 0)
end

--- Get the range of the enclosing scope node at a position.
--- Returns the start and end rows (0-indexed) of the nearest scope-like node.
---@param bufnr integer
---@param row integer # 0-indexed
---@return integer?, integer? # scope start, scope end (0-indexed)
function Treesitter:scope_range(bufnr, row)
    local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, 0 } })
    if not ok or not node then return nil, nil end

    local scope_types = {
        'function_definition', 'function_declaration', 'method_definition',
        'method_declaration', 'arrow_function', 'if_statement', 'if_expression',
        'for_statement', 'for_in_statement', 'while_statement', 'do_statement',
        'switch_statement', 'match_expression', 'try_statement',
        'class_definition', 'class_declaration', 'struct_type',
        'block', 'chunk', 'table_constructor', 'arguments',
        'func_literal', 'function_item',
        'jsx_element', 'jsx_self_closing_element',
    }

    while node do
        if vim.tbl_contains(scope_types, node:type()) then
            local sr, _, er, _ = node:range()
            if er > sr then return sr, er end
        end
        node = node:parent()
    end
    return nil, nil
end

--- Get a parser for a buffer.
---@param bufnr integer
---@return TSParser|nil
function Treesitter:get_parser(bufnr)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    return ok and parser or nil
end

--- Get a treesitter query for a language.
---@param lang string
---@param query_name string # e.g. 'textobjects', 'highlights'
---@return vim.treesitter.Query|nil
function Treesitter:query(lang, query_name)
    local ok, query = pcall(vim.treesitter.query.get, lang, query_name)
    return ok and query or nil
end

---@return string
function Treesitter:__tostring()
    return 'Treesitter()'
end

return Treesitter
