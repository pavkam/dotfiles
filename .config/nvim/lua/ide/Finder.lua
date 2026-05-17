-- Finder: fuzzy search abstraction.
-- All methods use owned TurboVision-style pickers (FilePicker, GrepPicker, SelectPicker).
-- No telescope dependency.

local Finder = Class('Finder')

function Finder:init() end

--- Get the position encoding for the current buffer's LSP client.
---@return string
local function lsp_encoding()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    return clients[1] and clients[1].offset_encoding or 'utf-16'
end

--- Find files in the workspace.
---@param opts { cwd?: string, hidden?: boolean }|nil
function Finder:files(opts)
    opts = opts or {}
    local FilePicker = require 'ide.toolkit.FilePicker'
    FilePicker({
        title = 'Open File',
        cwd = opts.cwd,
        hidden = opts.hidden,
    }):show()
end

--- Grep across the workspace.
---@param opts { cwd?: string, search?: string }|nil
function Finder:grep(opts)
    opts = opts or {}
    local GrepPicker = require 'ide.toolkit.GrepPicker'
    GrepPicker({
        title = 'Search in Files',
        cwd = opts.cwd,
        search = opts.search,
    }):show()
end

--- Search LSP document symbols.
---@param opts { symbols?: string[] }|nil
function Finder:symbols(opts)
    opts = opts or {}
    local buf = require('ide.Buffer').current()
    if not buf:is_valid() then return end

    local params = { textDocument = vim.lsp.util.make_text_document_params(buf:id()) }
    vim.lsp.buf_request(buf:id(), 'textDocument/documentSymbol', params, function(err, result)
        if err or not result then return end
        local items = {}
        local function flatten(symbols, prefix)
            for _, s in ipairs(symbols) do
                local name = (prefix ~= '' and prefix .. '.' or '') .. s.name
                local kind = vim.lsp.protocol.SymbolKind[s.kind] or 'Unknown'
                local icon = _symbol_icons[kind] or '󰀫'
                items[#items + 1] = {
                    text = name,
                    icon = icon,
                    hint = kind,
                    value = { lnum = s.range.start.line + 1, col = s.range.start.character + 1 },
                }
                if s.children then flatten(s.children, name) end
            end
        end
        flatten(result, '')

        vim.schedule(function()
            local Window = require 'ide.Window'
            local Position = require 'ide.Position'
            local SelectPicker = require 'ide.toolkit.SelectPicker'
            SelectPicker({
                title = '  Document Symbols',
                items = items,
                width = 0.5,
                height = math.min(#items + 3, 25),
                on_select = function(item)
                    local win = Window.current()
                    if win then
                        win:set_cursor(Position(item.value.lnum, item.value.col))
                        win:center_cursor()
                    end
                end,
            }):show()
        end)
    end)
end

--- LSP symbol kind icons.
local _symbol_icons = {
    File = '', Module = '', Namespace = '󰦮', Package = '',
    Class = '󰌗', Method = '', Property = '', Field = '',
    Constructor = '', Enum = '', Interface = '',
    Function = '󰊕', Variable = '󰀫', Constant = '󰏿',
    String = '', Number = '󰎠', Boolean = '◩', Array = '󰅪',
    Object = '', Key = '󰌋', Null = '󰟢', EnumMember = '',
    Struct = '', Event = '', Operator = '',
    TypeParameter = '󰗴',
}

--- Search LSP workspace symbols.
---@param opts { query?: string }|nil
function Finder:workspace_symbols(opts)
    opts = opts or {}
    vim.lsp.buf_request(0, 'workspace/symbol', { query = opts.query or '' }, function(err, result)
        if err or not result then return end
        local items = {}
        for _, s in ipairs(result) do
            local kind = vim.lsp.protocol.SymbolKind[s.kind] or 'Unknown'
            local loc = s.location
            local path = vim.uri_to_fname(loc.uri)
            local rel = vim.fn.fnamemodify(path, ':~:.')
            local icon = _symbol_icons[kind] or '󰀫'
            items[#items + 1] = {
                text = s.name,
                icon = icon,
                hint = kind .. '  ' .. rel,
                value = { path = path, lnum = loc.range.start.line + 1, col = loc.range.start.character + 1 },
            }
        end

        vim.schedule(function()
            local Buffer = require 'ide.Buffer'
            local Window = require 'ide.Window'
            local Position = require 'ide.Position'
            local SelectPicker = require 'ide.toolkit.SelectPicker'
            SelectPicker({
                title = '  Workspace Symbols',
                items = items,
                width = 0.6,
                height = math.min(#items + 3, 25),
                on_select = function(item)
                    Buffer.open(item.value.path)
                    local win = Window.current()
                    if win then
                        win:set_cursor(Position(item.value.lnum, item.value.col))
                        win:center_cursor()
                    end
                end,
            }):show()
        end)
    end)
end

--- Browse open buffers.
function Finder:buffers()
    local Buffer = require 'ide.Buffer'
    local bufs = IDE.buffers:listed()
    local cur_id = Buffer.current():id()
    local items = {}
    for _, buf in ipairs(bufs) do
        if buf:is_valid() then
            local name = buf:name() or '[No Name]'
            local modified = buf:is_modified() and ' ●' or ''
            local is_current = buf:id() == cur_id
            -- File icon
            local icon = ''
            if IDE.icons and IDE.icons:is_loaded() and name ~= '[No Name]' then
                local fname = IDE.fs:basename(name)
                local ext = IDE.fs:extension(name)
                local ic = IDE.icons:for_file(fname, ext)
                if ic then icon = ic:char() end
            end
            items[#items + 1] = {
                text = (is_current and '● ' or '  ') .. name .. modified,
                icon = icon,
                hint = buf:filetype(),
                value = buf,
            }
        end
    end

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = '  Buffers',
        items = items,
        on_select = function(item)
            require('ide.Window').current():set_buffer(item.value)
        end,
    }):show()
end

--- Search recent files.
function Finder:recent()
    local Buffer = require 'ide.Buffer'
    local oldfiles = vim.v.oldfiles or {}
    local items = {}
    for _, path in ipairs(oldfiles) do
        if vim.fn.filereadable(path) == 1 then
            local rel = vim.fn.fnamemodify(path, ':~:.')
            local icon = ''
            if IDE.icons and IDE.icons:is_loaded() then
                local fname = IDE.fs:basename(path)
                local ext = IDE.fs:extension(path)
                local ic = IDE.icons:for_file(fname, ext)
                if ic then icon = ic:char() end
            end
            local dir = vim.fn.fnamemodify(rel, ':h')
            items[#items + 1] = {
                text = rel,
                icon = icon,
                hint = dir ~= '.' and dir or '',
                value = path,
            }
            if #items >= 50 then break end
        end
    end

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = '  Recent Files',
        items = items,
        width = 0.5,
        height = math.min(#items + 3, 25),
        on_select = function(item)
            Buffer.open(item.value)
        end,
    }):show()
end

--- Search LSP references.
function Finder:references()
    local params = vim.lsp.util.make_position_params(0, lsp_encoding())
    params.context = { includeDeclaration = true }
    vim.lsp.buf_request(0, 'textDocument/references', params, function(err, result)
        if err or not result or #result == 0 then
            vim.notify('No references found', vim.log.levels.INFO)
            return
        end
        vim.schedule(function()
            self:_show_locations('References', result)
        end)
    end)
end

--- Search LSP definitions.
---@param opts { reuse_win?: boolean }|nil
function Finder:definitions(opts)
    local params = vim.lsp.util.make_position_params(0, lsp_encoding())
    vim.lsp.buf_request(0, 'textDocument/definition', params, function(err, result)
        if err or not result then return end
        if vim.islist(result) and #result == 1 then
            vim.schedule(function() vim.lsp.util.jump_to_location(result[1], 'utf-8', opts and opts.reuse_win) end)
        elseif vim.islist(result) and #result > 1 then
            vim.schedule(function() self:_show_locations('Definitions', result) end)
        else
            vim.schedule(function() vim.lsp.util.jump_to_location(result, 'utf-8', opts and opts.reuse_win) end)
        end
    end)
end

--- Search LSP implementations.
function Finder:implementations()
    local params = vim.lsp.util.make_position_params(0, lsp_encoding())
    vim.lsp.buf_request(0, 'textDocument/implementation', params, function(err, result)
        if err or not result then return end
        if vim.islist(result) and #result == 1 then
            vim.schedule(function() vim.lsp.util.jump_to_location(result[1], 'utf-8', true) end)
        elseif vim.islist(result) then
            vim.schedule(function() self:_show_locations('Implementations', result) end)
        else
            vim.schedule(function() vim.lsp.util.jump_to_location(result, 'utf-8', true) end)
        end
    end)
end

--- Search LSP type definitions.
function Finder:type_definitions()
    local params = vim.lsp.util.make_position_params(0, lsp_encoding())
    vim.lsp.buf_request(0, 'textDocument/typeDefinition', params, function(err, result)
        if err or not result then return end
        if vim.islist(result) and #result == 1 then
            vim.schedule(function() vim.lsp.util.jump_to_location(result[1], 'utf-8', true) end)
        elseif vim.islist(result) then
            vim.schedule(function() self:_show_locations('Type Definitions', result) end)
        else
            vim.schedule(function() vim.lsp.util.jump_to_location(result, 'utf-8', true) end)
        end
    end)
end

--- Search diagnostics.
---@param opts { bufnr?: integer }|nil
function Finder:diagnostics(opts)
    opts = opts or {}
    local Buffer = require 'ide.Buffer'
    local Window = require 'ide.Window'
    local Position = require 'ide.Position'
    local diags = vim.diagnostic.get(opts.bufnr)
    local items = {}
    local sev_names = { 'Error', 'Warn', 'Info', 'Hint' }
    local sev_icons = { ' ', ' ', ' ', '󰌵 ' }
    for _, d in ipairs(diags) do
        local buf = Buffer.get(d.bufnr)
        local fname = buf and buf:name() and vim.fn.fnamemodify(buf:name(), ':t') or '?'
        items[#items + 1] = {
            text = string.format('%s:%d: %s', fname, d.lnum + 1, d.message:gsub('\n', ' ')),
            icon = sev_icons[d.severity] or ' ',
            hint = sev_names[d.severity] or '?',
            value = { bufnr = d.bufnr, lnum = d.lnum + 1, col = d.col + 1 },
        }
    end

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = '  Diagnostics',
        items = items,
        width = 0.6,
        height = math.min(#items + 3, 25),
        on_select = function(item)
            local buf = Buffer.get(item.value.bufnr)
            if buf and buf:is_valid() then
                Window.current():set_buffer(buf)
                Window.current():set_cursor(Position(item.value.lnum, item.value.col))
                Window.current():center_cursor()
            end
        end,
    }):show()
end

--- Search keymaps.
function Finder:keymaps()
    local items = {}
    local seen = {}

    for _, mode in ipairs({ 'n', 'v', 'i' }) do
        local maps = vim.api.nvim_get_keymap(mode)
        for _, m in ipairs(maps) do
            if m.desc and m.desc ~= '' then
                local key = mode .. ':' .. m.lhs
                if not seen[key] then
                    seen[key] = true
                    local mode_label = ({ n = 'N', v = 'V', i = 'I' })[mode] or mode
                    local formatted = m.lhs
                        :gsub('<leader>', 'SPC ')
                        :gsub('<C%-', 'Ctrl+'):gsub('<S%-', 'Shift+')
                        :gsub('<M%-', 'Alt+'):gsub('<CR>', 'Enter')
                        :gsub('<F(%d+)>', 'F%1')
                        :gsub('>', '')
                    items[#items + 1] = {
                        text = m.desc,
                        icon = mode_label,
                        hint = formatted,
                        value = m,
                    }
                end
            end
        end
    end
    table.sort(items, function(a, b) return a.text < b.text end)

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = '  Keymaps',
        items = items,
        width = 0.6,
        height = math.min(#items + 3, 25),
        on_select = function(item)
            IDE.keys:feed(IDE.keys:termcodes(item.value.lhs), 'n')
        end,
    }):show()
end

--- Search help tags.
function Finder:help(query)
    local tags_files = vim.api.nvim_get_runtime_file('doc/tags', true)
    local items = {}
    for _, file in ipairs(tags_files) do
        for line in io.lines(file) do
            local tag = line:match('^(%S+)')
            if tag then
                items[#items + 1] = { text = tag, value = tag }
            end
        end
    end

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = 'Help',
        items = items,
        on_select = function(item)
            vim.cmd('help ' .. item.value)
        end,
    }):show()
end

--- Search git branches.
function Finder:git_branches()
    local result = vim.fn.systemlist({ 'git', 'branch', '-a', '--format=%(refname:short)' })
    local items = {}
    for _, b in ipairs(result) do
        if b ~= '' then items[#items + 1] = { text = b, value = b } end
    end

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = 'Git Branches',
        items = items,
        on_select = function(item)
            vim.fn.system({ 'git', 'checkout', item.value })
            vim.cmd('checktime')
        end,
    }):show()
end

--- Search git commits.
function Finder:git_commits()
    local result = vim.fn.systemlist({ 'git', 'log', '--oneline', '-50' })
    local items = {}
    for _, line in ipairs(result) do
        local hash, msg = line:match('^(%S+)%s+(.*)$')
        if hash then items[#items + 1] = { text = hash .. '  ' .. msg, value = hash } end
    end

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = 'Git Commits',
        items = items,
        on_select = function(item)
            vim.cmd('Git show ' .. item.value)
        end,
    }):show()
end

--- Generic picker using vim.ui.select.
---@generic T
---@param items T[]
---@param opts { prompt?: string, format_item?: fun(item: T): string }
---@param on_choice fun(item: T|nil, idx: integer|nil)
function Finder:select(items, opts, on_choice)
    local formatted = {}
    for i, item in ipairs(items) do
        local text = opts.format_item and opts.format_item(item) or tostring(item)
        formatted[#formatted + 1] = { text = text, value = item, _index = i }
    end

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = opts.prompt or 'Select',
        items = formatted,
        on_select = function(sel)
            on_choice(sel.value, sel._index)
        end,
    }):show()
end

--- Prompt for input.
---@param opts { prompt?: string, default?: string }
---@param on_confirm fun(input: string|nil)
function Finder:input(opts, on_confirm)
    vim.ui.input(opts, on_confirm)
end

--- Show LSP locations in a SelectPicker.
---@param title string
---@param locations table[]
function Finder:_show_locations(title, locations)
    local Buffer = require 'ide.Buffer'
    local Window = require 'ide.Window'
    local Position = require 'ide.Position'
    local items = {}
    for _, loc in ipairs(locations) do
        local uri = loc.uri or loc.targetUri
        local range = loc.range or loc.targetSelectionRange
        if uri and range then
            local path = vim.uri_to_fname(uri)
            local rel = vim.fn.fnamemodify(path, ':~:.')
            local lnum = range.start.line + 1
            local icon = ''
            if IDE.icons and IDE.icons:is_loaded() then
                local fname = IDE.fs:basename(path)
                local ext = IDE.fs:extension(path)
                local ic = IDE.icons:for_file(fname, ext)
                if ic then icon = ic:char() end
            end
            items[#items + 1] = {
                text = string.format('%s:%d', rel, lnum),
                icon = icon,
                value = { path = path, lnum = lnum, col = range.start.character + 1 },
            }
        end
    end

    local SelectPicker = require 'ide.toolkit.SelectPicker'
    SelectPicker({
        title = title,
        items = items,
        on_select = function(item)
            Buffer.open(item.value.path)
            local win = Window.current()
            if win then
                win:set_cursor(Position(item.value.lnum, item.value.col))
                win:center_cursor()
            end
        end,
    }):show()
end

---@return string
function Finder:__tostring() return 'Finder()' end

return Finder
