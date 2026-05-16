-- Completion Extension: native LSP completion with IDE integration.
-- Uses Neovim 0.12's LSP completion via BufferLSP abstraction.
-- Provides buffer word completion, path completion, ghost text preview,
-- smart sorting, comment suppression, and source-aware icons.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local Completion = Class('Completion', Extension)

function Completion:init()
    Extension.init(self, 'Completion')
    self._ghost_ns = Buffer.create_namespace('ide_completion_ghost')
    self._doc_winid = nil
    self._doc_bufnr = nil
end

-- ═══════════════════════════════════════════════════════════════════
-- LSP completion kind -> icon mapping (matches icons.lua Symbols)
-- ═══════════════════════════════════════════════════════════════════

local _kind_icons = {
    Text = '', Method = '', Function = '', Constructor = '',
    Field = '', Variable = '', Class = '󰌗', Interface = '',
    Module = '', Property = '', Unit = '', Value = '',
    Enum = '', Keyword = '', Snippet = '', Color = '',
    File = '', Reference = '', Folder = '', EnumMember = '',
    Constant = '', Struct = '', Event = '', Operator = '',
    TypeParameter = '',
}

-- Source labels for non-LSP completions
local _source_icons = {
    buffer = '󰈙',
    path = '',
    snippet = '',
}

-- ═══════════════════════════════════════════════════════════════════
-- Buffer word collection: collects unique words from listed buffers
-- ═══════════════════════════════════════════════════════════════════

--- Collect words from listed buffers (excluding current line).
---@param min_length integer # minimum word length
---@param max_items integer # maximum items to return
---@param prefix string # filter prefix
---@return table[] # complete-items
local function _collect_buffer_words(min_length, max_items, prefix)
    local seen = {}
    local items = {}
    local current_bufnr = vim.api.nvim_get_current_buf()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]

    -- Collect from all listed buffers
    local buffers = IDE.buffers:listed()
    for _, buf in ipairs(buffers) do
        if buf:is_valid() and buf:is_loaded() then
            local lines = buf:lines()
            for lnum, line in ipairs(lines) do
                -- Skip current line in current buffer to avoid self-completion
                if buf:id() ~= current_bufnr or lnum ~= current_line then
                    -- Max line length guard (avoid huge lines)
                    if #line <= 500 then
                        for word in line:gmatch('[%w_]+') do
                            if #word >= min_length and not seen[word] then
                                -- Prefix filter (case-insensitive)
                                if prefix == '' or word:lower():find(prefix:lower(), 1, true) == 1 then
                                    seen[word] = true
                                    items[#items + 1] = {
                                        word = word,
                                        abbr = word,
                                        kind = 'Text',
                                        menu = _source_icons.buffer .. ' buf',
                                        kind_hlgroup = 'LspKindText',
                                        icase = 1,
                                        dup = 0,
                                        user_data = { source = 'buffer' },
                                    }
                                    if #items >= max_items then return items end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return items
end

-- ═══════════════════════════════════════════════════════════════════
-- Path completion: completes file/directory paths
-- ═══════════════════════════════════════════════════════════════════

--- Check if the text before cursor looks like a path.
---@param line_to_cursor string
---@return string|nil # the path prefix to complete, or nil
local function _extract_path_prefix(line_to_cursor)
    -- Match path-like patterns: ./foo, ../foo, /foo, ~/foo, or word/word
    local path = line_to_cursor:match('[%.~/][%w_./-]*$')
        or line_to_cursor:match('[%w_.-]+/[%w_./-]*$')
    return path
end

--- Resolve a path prefix to an absolute directory and partial name.
---@param path_prefix string
---@return string|nil dir, string partial
local function _resolve_path(path_prefix)
    local dir, partial
    if path_prefix:sub(-1) == '/' then
        dir = path_prefix
        partial = ''
    else
        dir = vim.fn.fnamemodify(path_prefix, ':h')
        partial = vim.fn.fnamemodify(path_prefix, ':t')
    end

    -- Expand ~ and relative paths
    dir = vim.fn.expand(dir)
    if not vim.startswith(dir, '/') then
        local cwd = IDE.fs:cwd()
        dir = IDE.fs:join(cwd, dir)
    end

    return dir, partial
end

--- Collect path completions.
---@param path_prefix string
---@param max_items integer
---@return table[] # complete-items
local function _collect_paths(path_prefix, max_items)
    local dir, partial = _resolve_path(path_prefix)
    if not dir or not IDE.fs:is_directory(dir) then return {} end

    local items = {}
    local entries = IDE.fs:list(dir)
    for _, entry in ipairs(entries) do
        if entry.name:sub(1, 1) ~= '.' or partial:sub(1, 1) == '.' then
            if partial == '' or entry.name:lower():find(partial:lower(), 1, true) == 1 then
                local is_dir = entry.type == 'directory'
                local word = entry.name .. (is_dir and '/' or '')
                items[#items + 1] = {
                    word = word,
                    abbr = word,
                    kind = is_dir and 'Folder' or 'File',
                    menu = _source_icons.path .. ' path',
                    kind_hlgroup = is_dir and 'LspKindFolder' or 'LspKindFile',
                    icase = 1,
                    dup = 0,
                    user_data = { source = 'path' },
                }
                if #items >= max_items then break end
            end
        end
    end
    return items
end

-- ═══════════════════════════════════════════════════════════════════
-- Smart sorting: exact > prefix > fuzzy, with kind priority
-- ═══════════════════════════════════════════════════════════════════

--- Sort completion items with smart ordering.
---@param items table[] # complete-items array
---@param prefix string # current input prefix
---@return table[]
local function _smart_sort(items, prefix)
    if prefix == '' or #items == 0 then return items end
    local lprefix = prefix:lower()
    local plen = #lprefix

    table.sort(items, function(a, b)
        local aw = (a.word or a.abbr or ''):lower()
        local bw = (b.word or b.abbr or ''):lower()

        -- Priority 1: exact match
        local a_exact = aw == lprefix
        local b_exact = bw == lprefix
        if a_exact ~= b_exact then return a_exact end

        -- Priority 2: prefix match (starts with)
        local a_prefix = aw:sub(1, plen) == lprefix
        local b_prefix = bw:sub(1, plen) == lprefix
        if a_prefix ~= b_prefix then return a_prefix end

        -- Priority 3: LSP fuzzy score (if present)
        local a_score = a._fuzzy_score or 0
        local b_score = b._fuzzy_score or 0
        if a_score ~= b_score then return a_score > b_score end

        -- Priority 4: shorter items first
        if #aw ~= #bw then return #aw < #bw end

        -- Fallback: alphabetical
        return aw < bw
    end)

    return items
end

-- ═══════════════════════════════════════════════════════════════════
-- Ghost text: show completion preview as virtual text
-- ═══════════════════════════════════════════════════════════════════

--- Clear ghost text.
---@param self Completion
local function _clear_ghost_text(self)
    local bufnr = vim.api.nvim_get_current_buf()
    local ok, buf = pcall(Buffer.get, bufnr)
    if ok and buf and buf:is_valid() then
        buf:clear_extmarks(self._ghost_ns)
    end
end

--- Show ghost text for the selected completion item.
---@param self Completion
local function _show_ghost_text(self)
    local info = vim.v.event and vim.v.event.completed_item
    if not info or not info.word or info.word == '' then
        _clear_ghost_text(self)
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local buf = Buffer.get(bufnr)
    if not buf:is_valid() then return end

    -- Clear previous ghost text
    buf:clear_extmarks(self._ghost_ns)

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1 -- 0-indexed
    local col = cursor[2]
    local line = buf:line(cursor[1])

    -- Calculate what text would be inserted beyond what's already typed
    local prefix_on_line = line:sub(1, col)
    local word_start = prefix_on_line:match('()[%w_]*$') or (col + 1)
    local already_typed = line:sub(word_start, col)
    local remaining = info.word:sub(#already_typed + 1)

    if remaining == '' then return end

    buf:set_extmark(self._ghost_ns, row, col, {
        virt_text = { { remaining, 'CompletionGhostText' } },
        virt_text_pos = 'inline',
        priority = 1000,
    })
end

-- ═══════════════════════════════════════════════════════════════════
-- Documentation popup: resolve and show LSP documentation
-- ═══════════════════════════════════════════════════════════════════

--- Close the custom documentation popup.
---@param self Completion
local function _close_doc_popup(self)
    if self._doc_winid and vim.api.nvim_win_is_valid(self._doc_winid) then
        vim.api.nvim_win_close(self._doc_winid, true)
    end
    self._doc_winid = nil
    if self._doc_bufnr and vim.api.nvim_buf_is_valid(self._doc_bufnr) then
        vim.api.nvim_buf_delete(self._doc_bufnr, { force = true })
    end
    self._doc_bufnr = nil
end

--- Show documentation for a non-LSP completion item (buffer/path).
--- LSP items use Neovim's built-in completionItem/resolve + popup.
---@param self Completion
---@param item table # completed_item from vim.v.event
local function _show_source_doc(self, item)
    local source = vim.tbl_get(item, 'user_data', 'source')
    if not source then return end

    local doc_lines = {}
    if source == 'buffer' then
        doc_lines = { 'Source: buffer words', '', 'Word found in open buffers.' }
    elseif source == 'path' then
        local word = item.word or ''
        local kind = item.kind or ''
        if kind == 'Folder' then
            doc_lines = { 'Directory: ' .. word, '', 'Tab to enter directory.' }
        else
            doc_lines = { 'File: ' .. word }
            -- Try to get file size
            local dir_prefix = _extract_path_prefix(
                vim.api.nvim_get_current_line():sub(1, vim.api.nvim_win_get_cursor(0)[2])
            )
            if dir_prefix then
                local dir = _resolve_path(dir_prefix)
                if dir then
                    local full = IDE.fs:join(dir, word)
                    local stat = IDE.fs:stat(full)
                    if stat then
                        local size = stat.size < 1024 and (stat.size .. ' B')
                            or (math.floor(stat.size / 1024) .. ' KB')
                        doc_lines[#doc_lines + 1] = ''
                        doc_lines[#doc_lines + 1] = 'Size: ' .. size
                    end
                end
            end
        end
    end

    if #doc_lines == 0 then return end

    -- Close previous popup
    _close_doc_popup(self)

    -- Create scratch buffer for documentation
    self._doc_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(self._doc_bufnr, 0, -1, false, doc_lines)
    vim.bo[self._doc_bufnr].modifiable = false
    vim.bo[self._doc_bufnr].bufhidden = 'wipe'

    -- Position relative to the popup menu
    local pum = vim.fn.pum_getpos()
    if not pum or vim.tbl_isempty(pum) then return end

    local width = 40
    local height = math.min(#doc_lines, 10)
    local row = pum.row or 0
    local col = (pum.col or 0) + (pum.width or 0) + 2

    -- Check if we'd go off screen
    if col + width > Window.editor_width() then
        col = (pum.col or 0) - width - 2
        if col < 0 then return end
    end

    local win = Window.open_float(self._doc_bufnr, {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        focusable = false,
        zindex = 100,
    })
    self._doc_winid = win:id()
    win:set_option('winblend', 10)
    win:set_option('winhighlight', 'Normal:NormalFloat,FloatBorder:FloatBorder')
end

-- ═══════════════════════════════════════════════════════════════════
-- Comment suppression: check treesitter context before completing
-- ═══════════════════════════════════════════════════════════════════

--- Check if cursor is inside a comment or string.
---@return boolean
local function _in_comment_or_string()
    if not IDE.treesitter then return false end
    local ctx = IDE.treesitter:context()
    return ctx == 'comment' or ctx == 'string'
end

-- ═══════════════════════════════════════════════════════════════════
-- Manual completefunc for buffer + path sources
-- ═══════════════════════════════════════════════════════════════════

--- completefunc implementation that provides buffer words + path items.
--- This runs as a fallback when the user invokes Ctrl+Space and LSP
--- has no results, or as a secondary source via TextChangedI.
---@param findstart integer
---@param base string
---@return integer|table
local function _completefunc(findstart, base)
    if findstart == 1 then
        -- Find the start of the word
        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local line_to_cursor = line:sub(1, col)

        -- Check for path prefix first
        local path_prefix = _extract_path_prefix(line_to_cursor)
        if path_prefix then
            return col - #path_prefix
        end

        -- Find word start
        local word_start = line_to_cursor:match('()[%w_]*$')
        return (word_start or col + 1) - 1
    end

    -- findstart == 0: return matches
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local line_to_cursor = line:sub(1, col)

    local items = {}

    -- Path completion
    local path_prefix = _extract_path_prefix(line_to_cursor)
    if path_prefix then
        items = _collect_paths(path_prefix, 20)
    end

    -- Buffer word completion
    local buf_items = _collect_buffer_words(3, 10, base)
    for _, item in ipairs(buf_items) do
        items[#items + 1] = item
    end

    return _smart_sort(items, base)
end

-- ═══════════════════════════════════════════════════════════════════
-- Extension lifecycle
-- ═══════════════════════════════════════════════════════════════════

function Completion:on_register(ctx)
    local keys = IDE.keys
    local self_ref = self

    -- Define highlight for ghost text
    ctx:highlight('CompletionGhostText', { link = 'Comment' })

    -- Enable native completion on LSP attach with icon-enhanced kind display
    IDE.lsp:on_attach(function(client, bufnr)
        if client:supports_method('textDocument/completion') then
            local buf = Buffer.get(bufnr)
            if buf and buf:is_valid() then
                vim.lsp.completion.enable(true, client.id, bufnr, {
                    autotrigger = true,
                    convert = function(item)
                        -- Add icon prefix to the kind text for source-aware display
                        local kind_name = vim.lsp.protocol.CompletionItemKind[item.kind] or 'Text'
                        local icon = _kind_icons[kind_name] or ''
                        return {
                            kind = icon .. ' ' .. kind_name,
                        }
                    end,
                })
            end
        end
    end)

    -- ── Comment suppression: suppress completion in comments/strings ──
    ctx:hook('TextChangedI', function()
        if _in_comment_or_string() and keys:popup_visible() then
            -- Dismiss the popup when we detect we're in a comment
            vim.api.nvim_feedkeys(
                keys:termcodes('<C-e>'),
                'n', false
            )
        end
    end)

    -- ── Ghost text: show preview on CompleteChanged ──
    ctx:hook('CompleteChanged', function()
        _show_ghost_text(self_ref)

        -- Show documentation popup for non-LSP items
        -- (LSP items use Neovim's built-in completionItem/resolve)
        local item = vim.v.event and vim.v.event.completed_item
        if item and vim.tbl_get(item, 'user_data', 'source') then
            _show_source_doc(self_ref, item)
        else
            _close_doc_popup(self_ref)
        end
    end)

    -- ── Clear ghost text and doc popup when completion is done ──
    ctx:hook('CompleteDone', function()
        _clear_ghost_text(self_ref)
        _close_doc_popup(self_ref)
    end)

    -- ── Clear ghost text on InsertLeave ──
    ctx:hook('InsertLeave', function()
        _clear_ghost_text(self_ref)
        _close_doc_popup(self_ref)
    end)

    -- ── Confirm completion with Enter ──
    ctx:keymap('i', '<CR>', function()
        if keys:popup_visible() then
            return keys:termcodes('<C-y>')
        end
        return keys:termcodes('<CR>')
    end, { desc = 'Confirm completion', expr = true })

    -- ── Toggle/trigger completion with Ctrl+Space ──
    ctx:keymap('i', '<C-Space>', function()
        if keys:popup_visible() then
            return keys:termcodes('<C-e>')
        end

        -- Suppress in comments/strings
        if _in_comment_or_string() then
            return ''
        end

        -- Try LSP completion first
        local buf = Buffer.current()
        if buf:is_normal() and buf:lsp():is_attached() then
            buf:lsp():trigger_completion()
            return ''
        end

        -- Fallback: trigger buffer + path completion via completefunc
        vim.bo.completefunc = 'v:lua.IDE_completefunc'
        return keys:termcodes('<C-x><C-u>')
    end, { desc = 'Trigger completion', expr = true })

    -- Register global completefunc
    _G.IDE_completefunc = _completefunc

    -- ── Navigate completion with Tab/S-Tab ──
    ctx:keymap('i', '<Tab>', function()
        if keys:popup_visible() then
            return keys:termcodes('<C-n>')
        end
        return keys:termcodes('<Tab>')
    end, { desc = 'Next completion', expr = true })

    ctx:keymap('i', '<S-Tab>', function()
        if keys:popup_visible() then
            return keys:termcodes('<C-p>')
        end
        return keys:termcodes('<S-Tab>')
    end, { desc = 'Previous completion', expr = true })

    -- ── Scroll docs in popup with C-b/C-f ──
    ctx:keymap('i', '<C-b>', function()
        if keys:popup_visible() then
            local info = vim.fn.complete_info({ 'preview_winid' })
            if info.preview_winid and info.preview_winid > 0
                and vim.api.nvim_win_is_valid(info.preview_winid) then
                vim.api.nvim_win_call(info.preview_winid, function()
                    vim.cmd('normal! 4k')
                end)
            end
            return ''
        end
        return keys:termcodes('<C-b>')
    end, { desc = 'Scroll docs up', expr = true })

    ctx:keymap('i', '<C-f>', function()
        if keys:popup_visible() then
            local info = vim.fn.complete_info({ 'preview_winid' })
            if info.preview_winid and info.preview_winid > 0
                and vim.api.nvim_win_is_valid(info.preview_winid) then
                vim.api.nvim_win_call(info.preview_winid, function()
                    vim.cmd('normal! 4j')
                end)
            end
            return ''
        end
        return keys:termcodes('<C-f>')
    end, { desc = 'Scroll docs down', expr = true })

    -- ── Buffer + path completion trigger on TextChangedI ──
    -- When LSP popup is NOT visible and user types a path separator,
    -- trigger path completion automatically.
    ctx:hook('TextChangedI', function()
        -- Don't interfere with active LSP completion
        if keys:popup_visible() then return end

        -- Suppress in comments/strings
        if _in_comment_or_string() then return end

        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local line_to_cursor = line:sub(1, col)

        -- Auto-trigger path completion when typing after /
        if line_to_cursor:match('[/]$') then
            local path_prefix = _extract_path_prefix(line_to_cursor)
            if path_prefix then
                vim.bo.completefunc = 'v:lua.IDE_completefunc'
                vim.schedule(function()
                    if vim.fn.mode() == 'i' and not keys:popup_visible() then
                        vim.api.nvim_feedkeys(
                            keys:termcodes('<C-x><C-u>'),
                            'n', false
                        )
                    end
                end)
            end
        end
    end)

    -- ── Register action ──
    ctx:action('editor.completion', 'Trigger completion', function(action_ctx)
        if _in_comment_or_string() then return end
        if action_ctx.buf:is_normal() then
            action_ctx.buf:lsp():trigger_completion()
        end
    end)

    ctx:action('editor.completion.buffer', 'Trigger buffer completion', function()
        vim.bo.completefunc = 'v:lua.IDE_completefunc'
        vim.api.nvim_feedkeys(
            keys:termcodes('<C-x><C-u>'),
            'n', false
        )
    end)
end

function Completion:on_unregister()
    _clear_ghost_text(self)
    _close_doc_popup(self)
    _G.IDE_completefunc = nil
end

---@return string
function Completion:__tostring()
    return 'Completion()'
end

return Completion
