-- Outline Extension: document symbol outline panel.
-- Shows functions, classes, methods, and other symbols from treesitter/LSP
-- in a navigable floating panel. Jump to any symbol with Enter.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'
local Panel = require 'ide.toolkit.Panel'

local Outline = Class('Outline', Extension)

function Outline:init()
    Extension.init(self, 'Outline')
end

--- Collect document symbols from LSP.
---@param bufnr integer
---@return table[] # { name, kind, icon, lnum, col, children? }
local function collect_lsp_symbols(bufnr)
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if #clients == 0 then return {} end

    local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    local results = vim.lsp.buf_request_sync(bufnr, 'textDocument/documentSymbol', params, 2000)
    if not results then return {} end

    local kind_names = {
        [1] = 'File', [2] = 'Module', [3] = 'Namespace', [4] = 'Package',
        [5] = 'Class', [6] = 'Method', [7] = 'Property', [8] = 'Field',
        [9] = 'Constructor', [10] = 'Enum', [11] = 'Interface', [12] = 'Function',
        [13] = 'Variable', [14] = 'Constant', [15] = 'String', [16] = 'Number',
        [17] = 'Boolean', [18] = 'Array', [19] = 'Object', [20] = 'Key',
        [21] = 'Null', [22] = 'EnumMember', [23] = 'Struct', [24] = 'Event',
        [25] = 'Operator', [26] = 'TypeParameter',
    }

    local kind_icons = {
        Class = '󰠱', Method = '󰊕', Function = '󰊕', Constructor = '',
        Field = '󰜢', Variable = '󰀫', Interface = '', Enum = '',
        Module = '󰏗', Property = '󰜢', Struct = '󰙅', Constant = '󰏿',
        EnumMember = '', Event = '', Operator = '󰆕', TypeParameter = '󰊄',
        Namespace = '󰌗', Package = '󰏗', String = '󰉿', Number = '󰎠',
        Boolean = '◩', Array = '󰅪', Object = '󰅩', Key = '󰌋',
        Null = '󰟢', File = '󰈙',
    }

    local function flatten(symbols, depth)
        local result = {}
        for _, sym in ipairs(symbols) do
            local kind = kind_names[sym.kind] or 'Unknown'
            local range = sym.selectionRange or sym.range or sym.location and sym.location.range
            local lnum = range and (range.start.line + 1) or 0
            local col = range and (range.start.character + 1) or 0

            result[#result + 1] = {
                name = sym.name,
                kind = kind,
                icon = kind_icons[kind] or '󰙅',
                lnum = lnum,
                col = col,
                depth = depth,
            }

            if sym.children then
                for _, child in ipairs(flatten(sym.children, depth + 1)) do
                    result[#result + 1] = child
                end
            end
        end
        return result
    end

    local symbols = {}
    for _, res in pairs(results) do
        if res.result then
            symbols = flatten(res.result, 0)
            break
        end
    end
    return symbols
end

--- Fallback: collect symbols from treesitter.
---@param bufnr integer
---@return table[]
local function collect_ts_symbols(bufnr)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not ok or not parser then return {} end

    local tree = parser:parse()[1]
    if not tree then return {} end
    local root = tree:root()

    local result = {}
    local query_str = '(function_declaration name: (identifier) @name) @func'
    local lang = parser:lang()

    local qok, query = pcall(vim.treesitter.query.parse, lang, query_str)
    if not qok then
        -- Try a simpler query
        qok, query = pcall(vim.treesitter.query.parse, lang, '((function_declaration) @func)')
        if not qok then return {} end
    end

    for _, match, _ in query:iter_matches(root, bufnr) do
        for id, nodes in pairs(match) do
            local node = type(nodes) == 'table' and nodes[1] or nodes
            local name_cap = query.captures[id]
            if name_cap == 'name' or name_cap == 'func' then
                local sr, sc = node:range()
                local text = vim.treesitter.get_node_text(node, bufnr)
                if text and #text < 60 then
                    result[#result + 1] = {
                        name = text,
                        kind = 'Function',
                        icon = '󰊕',
                        lnum = sr + 1,
                        col = sc + 1,
                        depth = 0,
                    }
                end
            end
        end
    end

    return result
end

--- Function component for outline content.
local function OutlineView(props)
    local symbols = props.symbols or {}
    local selected, setSelected = hooks.useState(1)

    props._state = { selected = selected, setSelected = setSelected }

    local sel = math.max(1, math.min(selected, #symbols))
    if sel ~= selected then setSelected(sel) end

    local children = {}

    if #symbols == 0 then
        children[#children + 1] = { type = 'text', text = '  No symbols found', indent = 1, hl = 'IDEPanelDim' }
        return children
    end

    for i, sym in ipairs(symbols) do
        local indent = string.rep('  ', sym.depth or 0)
        local text = indent .. sym.icon .. ' ' .. sym.name
        local kind_text = '  ' .. sym.kind

        if i == sel then
            children[#children + 1] = {
                type = 'row', hl = 'IDEPanelSelected',
                children = {
                    { type = 'text', text = '▸ ' .. text, hl = 'IDEPanelSelected' },
                },
            }
        else
            children[#children + 1] = {
                type = 'row',
                children = {
                    { type = 'text', text = '  ' .. text, hl = 'Normal' },
                },
            }
        end
    end

    children[#children + 1] = {
        type = 'status',
        text = string.format('%d/%d ', sel, #symbols),
        hl = 'IDEPanelDim',
        text_hl = 'IDEPanelCounter',
    }

    return children
end

function Outline:show()
    local buf = IDE.buffers:current()
    if not buf:is_normal() then
        IDE.ui:info('No symbols for this buffer')
        return
    end

    local symbols = collect_lsp_symbols(buf:id())
    if #symbols == 0 then
        symbols = collect_ts_symbols(buf:id())
    end

    local panel = Panel({
        title = '  Outline',
        width = 0.35,
        height = math.min(#symbols + 2, 30),
        enter = true,
    })

    local component = nil
    local source_buf = buf

    function panel:_on_mount()
        component = C.mount(OutlineView, {
            symbols = symbols,
            _state = {},
        }, self:buffer(), self._win)

        local function state()
            return component and component.ctx.props._state or {}
        end

        local function move(delta)
            local s = state()
            if s.setSelected then
                s.setSelected(math.max(1, math.min((s.selected or 1) + delta, #symbols)))
            end
        end

        self:map('n', 'j', function() move(1) end)
        self:map('n', 'k', function() move(-1) end)
        self:map('n', '<Down>', function() move(1) end)
        self:map('n', '<Up>', function() move(-1) end)
        self:map('n', 'G', function()
            local s = state()
            if s.setSelected then s.setSelected(#symbols) end
        end)
        self:map('n', 'gg', function()
            local s = state()
            if s.setSelected then s.setSelected(1) end
        end)

        self:map('n', '<CR>', function()
            local s = state()
            local sym = symbols[s.selected or 1]
            if sym and sym.lnum > 0 then
                self:hide()
                vim.schedule(function()
                    if source_buf:is_valid() then
                        Window.current():set_buffer(source_buf)
                        pcall(vim.api.nvim_win_set_cursor, 0, { sym.lnum, (sym.col or 1) - 1 })
                        vim.cmd('normal! zz')
                    end
                end)
            end
        end)
    end

    local orig_hide = panel.hide
    panel.hide = function(self)
        if component then C.unmount(component); component = nil end
        orig_hide(self)
    end

    panel:show()
end

function Outline:on_register(ctx)
    ctx:action('view.outline', 'Document outline', function()
        self:show()
    end)

    ctx:command('IDEOutline', function()
        self:show()
    end, { desc = 'Show document outline' })

    ctx:keymap('n', '<leader>o', 'view.outline', { desc = 'Document outline' })
end

return Outline
