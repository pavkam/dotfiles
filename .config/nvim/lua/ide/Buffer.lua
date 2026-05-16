-- Buffer: OOP abstraction over neovim buffers.
-- Wraps vim.api.nvim_buf_* and vim.bo[] with reactive events.
-- Internalizes formatting (conform) and linting (nvim-lint).
--
-- Events: 'change', 'save', 'close', 'filetype', 'attach', 'detach'

local EventEmitter = require 'ide.EventEmitter'
local Position = require 'ide.Position'

local Buffer = Class('Buffer')
Class.include(Buffer, EventEmitter)

--- Instance cache: same buffer ID always returns the same object.
---@type table<integer, Buffer>
local _cache = {}

--- Create a Buffer wrapper. Use Buffer.get(id) for cached access.
---@param id integer
function Buffer:init(id)
    assert(type(id) == 'number' and vim.api.nvim_buf_is_valid(id), 'invalid buffer id')
    self._id = id
end

--- Get or create a cached Buffer instance. Same ID = same object.
--- Preferred over Buffer(id) when you need identity stability.
---@param id integer
---@return Buffer
function Buffer.get(id)
    if type(id) ~= 'number' then return nil end
    if not vim.api.nvim_buf_is_valid(id) then
        _cache[id] = nil
        return nil
    end
    local cached = _cache[id]
    if cached then return cached end
    local buf = Buffer(id)
    _cache[id] = buf
    return buf
end

--- Clean up subsystem facades and tracked autocmds.
function Buffer:destroy()
    self._lsp = nil
    self._ast = nil
    self._git = nil
    self._diagnostics = nil
    self:clear()
end

--- Evict a buffer from the instance cache (called on BufDelete).
---@param id integer
function Buffer._evict(id)
    local buf = _cache[id]
    if buf then buf:destroy() end
    _cache[id] = nil
end

--- Get the cached instance count (for diagnostics).
---@return integer
function Buffer._cache_size()
    return vim.tbl_count(_cache)
end

-- Properties

---@return integer
function Buffer:id()
    return self._id
end

--- Check validity. Works as instance method (buf:is_valid()) or static (Buffer.is_valid(id)).
---@return boolean
function Buffer:is_valid()
    local id = type(self) == 'number' and self or (type(self) == 'table' and self._id or nil)
    return type(id) == 'number' and vim.api.nvim_buf_is_valid(id) or false
end

---@return boolean
function Buffer:is_loaded()
    return vim.api.nvim_buf_is_loaded(self._id)
end

--- A normal buffer is a regular file buffer (not terminal, help, nofile, etc.)
---@return boolean
function Buffer:is_normal()
    return self:is_valid() and vim.bo[self._id].buftype == ''
end

-- Buffer classification — dynamic registries.
-- Extensions register their own special/transient filetypes rather than hardcoding.
Buffer.SPECIAL_FILETYPES = {}
Buffer.SPECIAL_BUFTYPES = { 'prompt', 'nofile', 'terminal', 'help' }
Buffer.TRANSIENT_BUFTYPES = { 'nofile', 'terminal' }
Buffer.TRANSIENT_FILETYPES = { 'gitcommit', 'gitrebase', 'hgcommit' }

-- Default special filetypes (from plugins that may or may not be loaded)
for _, ft in ipairs({
    'ide-filetree', 'ide-searchable-list', 'ide-panel', 'ide-desktop', 'ide-terminal',
    'dap-float', 'dap-repl', 'dapui_console', 'dapui_watches',
    'dapui_stacks', 'dapui_breakpoints', 'dapui_scopes', 'PlenaryTestPopup',
    'help', 'lspinfo', 'man', 'notify', 'Outline', 'qf', 'query',
    'spectre_panel', 'startuptime', 'tsplayground', 'checkhealth', 'Trouble',
    'terminal', 'neotest-summary', 'neotest-output', 'neotest-output-panel',
    'WhichKey', 'TelescopePrompt', 'TelescopeResults',
}) do
    Buffer.SPECIAL_FILETYPES[#Buffer.SPECIAL_FILETYPES + 1] = ft
end

--- Register a filetype as special (non-editing UI panel).
---@param ft string
function Buffer.register_special_filetype(ft)
    if not vim.tbl_contains(Buffer.SPECIAL_FILETYPES, ft) then
        Buffer.SPECIAL_FILETYPES[#Buffer.SPECIAL_FILETYPES + 1] = ft
    end
end

--- Unregister a filetype from the special list.
---@param ft string
function Buffer.unregister_special_filetype(ft)
    for i, v in ipairs(Buffer.SPECIAL_FILETYPES) do
        if v == ft then table.remove(Buffer.SPECIAL_FILETYPES, i); return end
    end
end

--- Check if this buffer is a special (non-editing) buffer.
---@return boolean
function Buffer:is_special()
    local id = type(self) == 'number' and self or self._id
    if not vim.api.nvim_buf_is_valid(id) then return true end
    local ft = vim.bo[id].filetype
    local bt = vim.bo[id].buftype
    return (bt ~= '' and vim.tbl_contains(Buffer.SPECIAL_BUFTYPES, bt)) or vim.tbl_contains(Buffer.SPECIAL_FILETYPES, ft)
end

--- Check if this buffer is transient (temporary editing like git commits).
---@return boolean
function Buffer:is_transient()
    local id = type(self) == 'number' and self or self._id
    if not vim.api.nvim_buf_is_valid(id) then return false end
    local ft = vim.bo[id].filetype
    local bt = vim.bo[id].buftype
    if bt == '' and ft == '' then return true end
    return vim.tbl_contains(Buffer.TRANSIENT_BUFTYPES, bt) or vim.tbl_contains(Buffer.TRANSIENT_FILETYPES, ft)
end

--- Check if this buffer is a regular file buffer (not special, not transient).
---@return boolean
function Buffer:is_regular()
    local id = type(self) == 'number' and self or self._id
    if not vim.api.nvim_buf_is_valid(id) then return false end
    return not Buffer.is_special(id) and not Buffer.is_transient(id)
end

--- Check if this buffer is modifiable.
---@return boolean
function Buffer:is_modifiable()
    return self:is_valid() and vim.bo[self._id].modifiable
end

--- Set modifiable state.
---@param value boolean
function Buffer:set_modifiable(value)
    if self:is_valid() then vim.bo[self._id].modifiable = value end
end

---@return boolean
function Buffer:is_modified()
    return self:is_valid() and vim.bo[self._id].modified
end

---@return boolean
function Buffer:is_listed()
    return self:is_valid() and vim.bo[self._id].buflisted
end

---@param value boolean
function Buffer:set_listed(value)
    if self:is_valid() then
        vim.bo[self._id].buflisted = value
    end
end

--- The canonical file path, or nil for unnamed/special buffers.
---@return string|nil
function Buffer:path()
    if not self:is_normal() then return nil end
    local name = vim.api.nvim_buf_get_name(self._id)
    if name == '' then return nil end
    local real = vim.uv.fs_realpath(name)
    return real or name
end

--- The file name (basename).
---@return string|nil
function Buffer:name()
    local p = self:path()
    return p and vim.fs.basename(p) or nil
end

---@return string
function Buffer:filetype()
    if not self:is_valid() then return '' end
    return vim.bo[self._id].filetype
end

---@return integer
function Buffer:line_count()
    if not self:is_valid() then return 0 end
    return vim.api.nvim_buf_line_count(self._id)
end

---@return integer
function Buffer:changedtick()
    return vim.api.nvim_buf_get_changedtick(self._id)
end

--- Get buffer lines.
---@param start_line integer|nil # 0-indexed (default 0)
---@param end_line integer|nil # 0-indexed exclusive (default -1)
---@return string[]
function Buffer:lines(start_line, end_line)
    return vim.api.nvim_buf_get_lines(self._id, start_line or 0, end_line or -1, false)
end

--- Get a single line (1-indexed).
---@param lnum integer # 1-indexed line number
---@return string
function Buffer:line(lnum)
    return vim.fn.getbufoneline(self._id, lnum)
end

--- Get the line at the cursor position in the current window.
---@return string
function Buffer:current_line()
    local cursor = self:cursor()
    if not cursor then return '' end
    return self:line(cursor.row) or ''
end

--- Set buffer lines (0-indexed, end-exclusive).
---@param start_line integer # 0-indexed
---@param end_line integer # 0-indexed exclusive (-1 = end)
---@param lines string[]
function Buffer:set_lines(start_line, end_line, lines)
    if not self:is_valid() then return end
    vim.api.nvim_buf_set_lines(self._id, start_line, end_line, false, lines)
end

--- Replace text in a region (0-indexed coordinates).
---@param start_row integer # 0-indexed
---@param start_col integer # 0-indexed
---@param end_row integer # 0-indexed
---@param end_col integer # 0-indexed
---@param lines string[]
function Buffer:set_text(start_row, start_col, end_row, end_col, lines)
    vim.api.nvim_buf_set_text(self._id, start_row, start_col, end_row, end_col, lines)
end

--- Set an extmark in this buffer.
---@param ns integer # namespace id
---@param row integer # 0-indexed row
---@param col integer # 0-indexed column
---@param opts table # extmark options
---@return integer # extmark id
function Buffer:set_extmark(ns, row, col, opts)
    return vim.api.nvim_buf_set_extmark(self._id, ns, row, col, opts)
end

--- Clear extmarks in a namespace.
---@param ns integer # namespace id
---@param start_row? integer # 0-indexed (default 0)
---@param end_row? integer # 0-indexed (default -1)
function Buffer:clear_extmarks(ns, start_row, end_row)
    vim.api.nvim_buf_clear_namespace(self._id, ns, start_row or 0, end_row or -1)
end

--- Get extmarks in a region.
---@param ns integer # namespace id (-1 for all namespaces)
---@param start any # start position {row, col} (0-indexed)
---@param end_ any # end position {row, col} (0-indexed)
---@param opts? table # options (details, type, etc.)
---@return table[] # array of {id, row, col, details?}
function Buffer:get_extmarks(ns, start, end_, opts)
    if not self:is_valid() then return {} end
    return vim.api.nvim_buf_get_extmarks(self._id, ns, start, end_, opts or {})
end

--- Get text from a buffer region (0-indexed coordinates).
---@param start_row integer # 0-indexed
---@param start_col integer # 0-indexed
---@param end_row integer # 0-indexed
---@param end_col integer # 0-indexed
---@return string[]
function Buffer:get_text(start_row, start_col, end_row, end_col)
    if not self:is_valid() then return {} end
    return vim.api.nvim_buf_get_text(self._id, start_row, start_col, end_row, end_col, {})
end

--- Run a function in the context of this buffer.
---@param fn function
---@return any
function Buffer:call(fn)
    if not self:is_valid() then return end
    return vim.api.nvim_buf_call(self._id, fn)
end

--- Get cursor position in this buffer's first window.
---@return Position
function Buffer:cursor()
    local wins = vim.fn.getbufinfo(self._id)[1].windows
    if wins and #wins > 0 then
        return Position.from_cursor(vim.api.nvim_win_get_cursor(wins[1]))
    end
    return Position(1, 1)
end

--- Get the windows displaying this buffer.
---@return integer[] # window ids
function Buffer:window_ids()
    local info = vim.fn.getbufinfo(self._id)
    return info[1] and info[1].windows or {}
end

-- Diagnostics

--- Get the diagnostics facade for this buffer.
---@return DiagnosticSet
function Buffer:diagnostics()
    if not self._diagnostics then
        self._diagnostics = require('ide.DiagnosticSet')(self._id)
    end
    return self._diagnostics
end

--- Legacy alias.
Buffer.diagnostic_set = Buffer.diagnostics

--- Count diagnostics by severity.
---@param severity integer|nil
---@return integer
function Buffer:diagnostic_count(severity)
    return self:diagnostics():count(severity)
end

--- Jump to next diagnostic.
---@param severity integer|nil
function Buffer:next_diagnostic(severity)
    self:diagnostics():next(severity)
end

--- Jump to previous diagnostic.
---@param severity integer|nil
function Buffer:prev_diagnostic(severity)
    self:diagnostics():prev(severity)
end

-- Buffer-scoped subsystems

--- Get the LSP facade for this buffer.
---@return BufferLSP
function Buffer:lsp()
    if not self._lsp then
        self._lsp = require('ide.BufferLSP')(self._id)
    end
    return self._lsp
end

--- Get the AST (TreeSitter) facade for this buffer.
---@return BufferAST
function Buffer:ast()
    if not self._ast then
        self._ast = require('ide.BufferAST')(self._id)
    end
    return self._ast
end

--- Get the git facade for this buffer.
---@return BufferGit
function Buffer:git()
    if not self._git then
        self._git = require('ide.BufferGit')(self._id)
    end
    return self._git
end

-- Legacy compatibility (delegates to buf:lsp())

--- Get LSP clients attached to this buffer.
---@return vim.lsp.Client[]
function Buffer:lsp_clients()
    return self:lsp():clients()
end

--- Check if a specific LSP server is active.
---@param name string
---@return boolean
function Buffer:has_lsp(name)
    return self:lsp():has_server(name)
end

-- Actions

--- Format this buffer using the owned FormatterRunner.
--- Falls back to LSP formatting when no CLI formatter is available.
---@param opts { timeout_ms?: integer, async?: boolean, lsp_fallback?: boolean }|nil
---@param callback fun(success: boolean)|nil
function Buffer:format(opts, callback)
    if not self:is_valid() then return end
    opts = opts or {}
    local self_ref = self
    IDE.formatter:format(self, opts, function(ok)
        self_ref:emit('format')
        if callback then callback(ok) end
    end)
end

--- Lint this buffer using the owned LinterRunner.
---@param callback fun(success: boolean)|nil
function Buffer:lint(callback)
    local self_ref = self
    IDE.linter:lint(self, function(ok)
        self_ref:emit('lint')
        if callback then callback(ok) end
    end)
end

--- Save this buffer.
function Buffer:save()
    if self:is_valid() and self:is_modified() then
        local ok = pcall(vim.api.nvim_buf_call, self._id, function()
            vim.cmd.write { mods = { silent = true } }
        end)
        if not ok then return end
    end
end

--- Reload the buffer from disk, discarding unsaved changes.
function Buffer:reload()
    if self:is_valid() then
        vim.api.nvim_buf_call(self._id, function() vim.cmd('edit!') end)
    end
end

--- Close/delete this buffer.
---@param force boolean|nil
function Buffer:close(force)
    if self:is_valid() then
        pcall(vim.api.nvim_buf_delete, self._id, { force = force or false })
    end
end

--- Undo the last change.
function Buffer:undo()
    if self:is_valid() then
        vim.api.nvim_buf_call(self._id, function() vim.cmd('undo') end)
    end
end

--- Redo the last undone change.
function Buffer:redo()
    if self:is_valid() then
        vim.api.nvim_buf_call(self._id, function() vim.cmd('redo') end)
    end
end

--- Toggle comment on the current line or visual selection.
function Buffer:toggle_comment()
    if self:is_valid() then
        vim.api.nvim_buf_call(self._id, function() vim.cmd('normal gcc') end)
    end
end

--- Move the current line up.
function Buffer:move_line_up()
    if self:is_valid() then
        vim.api.nvim_buf_call(self._id, function()
            pcall(vim.cmd, 'move .-2')
        end)
    end
end

--- Move the current line down.
function Buffer:move_line_down()
    if self:is_valid() then
        vim.api.nvim_buf_call(self._id, function()
            pcall(vim.cmd, 'move .+1')
        end)
    end
end

--- Duplicate the current line.
function Buffer:duplicate_line()
    if self:is_valid() then
        vim.api.nvim_buf_call(self._id, function() vim.cmd('normal! yyp') end)
    end
end

--- Select all text in the buffer (enters visual mode).
function Buffer:select_all()
    if self:is_valid() then
        vim.api.nvim_buf_call(self._id, function() vim.cmd('normal! ggVG') end)
    end
end

--- Open a file and switch to its buffer.
---@param path string
---@return Buffer
function Buffer.open(path)
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    return Buffer.current()
end

--- Mark a word as good or bad in the spell dictionary.
---@param word string
---@param good boolean # true = spellgood, false = spellbad
function Buffer:spell_word(word, good)
    local cmd = good and 'spellgood' or 'spellbad'
    vim.api.nvim_buf_call(self._id, function()
        vim.cmd[cmd](word)
    end)
end

--- Context action provider registry.
--- Components register providers that contribute context menu items
--- based on buffer state at a given cursor position.
---@type fun(buf: Buffer, row: integer): { group: string, items: { text: string, icon: string|nil, action: fun(), hl: string|nil }[] }[]
Buffer._context_providers = {}

--- Register a context action provider.
--- Providers are called with (buffer, row) and return action groups.
---@param provider fun(buf: Buffer, row: integer): { group: string, items: table[] }[]|nil
function Buffer.add_context_provider(provider)
    Buffer._context_providers[#Buffer._context_providers + 1] = provider
end

--- Get context-aware actions from all registered providers.
---@param row integer|nil
---@return { group: string, items: table[] }[]
function Buffer:context_actions(row)
    row = row or self:cursor().row
    local all_actions = {}
    for _, provider in ipairs(Buffer._context_providers) do
        local ok, groups = pcall(provider, self, row)
        if ok and groups then
            for _, g in ipairs(groups) do
                if g.items and #g.items > 0 then
                    all_actions[#all_actions + 1] = g
                end
            end
        end
    end
    return all_actions
end

--- Get the alternate (#) buffer.
---@return Buffer|nil
function Buffer:alternate()
    local alt = vim.fn.bufnr('#')
    if alt > 0 and vim.api.nvim_buf_is_valid(alt) then
        return Buffer.get(alt)
    end
    return nil
end

--- Get the word under the cursor (vim <cword>).
---@return string
function Buffer:word_under_cursor()
    return vim.fn.expand('<cword>')
end

--- Get the WORD under the cursor (vim <cWORD>).
---@return string
function Buffer:WORD_under_cursor()
    return vim.fn.expand('<cWORD>')
end

--- Prompt to save if modified, then invoke callback.
--- If the buffer is not modified, callback fires immediately.
---@param callback fun()
function Buffer:confirm_saved(callback)
    if not self:is_modified() then
        callback()
        return
    end
    IDE.ui:confirm('Save changes to ' .. (self:name() or 'buffer') .. '?', function(yes)
        if yes then
            self:save()
        end
        callback()
    end)
end

--- Close all buffers except the current one.
--- Only closes valid, non-special, listed buffers.
function Buffer.close_others()
    local current_id = Buffer.current():id()
    for _, id in ipairs(vim.api.nvim_list_bufs()) do
        if id ~= current_id and vim.api.nvim_buf_is_valid(id)
            and vim.bo[id].buflisted and vim.bo[id].buftype == '' then
            pcall(vim.api.nvim_buf_delete, id, { force = false })
        end
    end
end

---@return string
function Buffer:__tostring()
    return string.format('Buffer(%d, %s)', self._id, self:name() or '<unnamed>')
end

-- Class methods

--- Get a buffer option by name.
---@param name string
---@return any
function Buffer:option(name)
    return vim.bo[self._id][name]
end

--- Set a buffer option by name.
---@param name string
---@param value any
function Buffer:set_option(name, value)
    vim.bo[self._id][name] = value
end

--- Get a buffer-scoped variable.
---@param name string
---@return any
function Buffer:var(name)
    return vim.b[self._id][name]
end

--- Get a mark position in this buffer.
---@param name string # single character mark name (e.g. '"', 'a', etc.)
---@return integer[] # {row, col} (1-indexed row, 0-indexed col)
function Buffer:mark(name)
    return vim.api.nvim_buf_get_mark(self._id, name)
end

--- Set the buffer name.
---@param name string
function Buffer:set_name(name)
    vim.api.nvim_buf_set_name(self._id, name)
end

--- Bind a buffer-local keymap.
---@param mode string|string[]
---@param key string
---@param fn function
---@param opts? { desc?: string, expr?: boolean }
function Buffer:bind_key(mode, key, fn, opts)
    opts = opts or {}
    opts.buffer = self._id
    IDE.keys:map(mode, key, fn, opts)
end

--- Set a buffer-scoped variable.
---@param name string
---@param value any
function Buffer:set_var(name, value)
    vim.b[self._id][name] = value
end

--- Create or get a namespace for extmarks.
---@param name string
---@return integer
function Buffer.create_namespace(name)
    return vim.api.nvim_create_namespace(name)
end

--- Load a file into a buffer (creates if needed).
---@param path string
---@return Buffer|nil
function Buffer.load(path)
    local bufnr = vim.fn.bufadd(path)
    if bufnr == 0 then return nil end
    vim.fn.bufload(bufnr)
    return Buffer.get(bufnr)
end

--- Wrap the current buffer (cached — same buf ID = same object).
---@return Buffer
function Buffer.current()
    return Buffer.get(vim.api.nvim_get_current_buf())
end

--- Create a new empty buffer.
---@param opts { listed?: boolean, scratch?: boolean }|nil
---@return Buffer
function Buffer.create(opts)
    opts = opts or {}
    local id = vim.api.nvim_create_buf(
        opts.listed ~= false,
        opts.scratch or false
    )
    return Buffer.get(id)
end

-- ── Reactive event helpers ──────────────────────────────────────
-- These abstract autocmds into buffer-scoped event handlers.
-- Usage: buf:on_enter(fn), buf:on_save(fn), buf:on_modify(fn)

local _buf_hooks = {} -- bufnr → { event → autocmd_id[] }

--- Subscribe to a buffer-scoped event (abstracts autocmds).
---@param event string # 'enter', 'leave', 'save', 'modify', 'close', 'filetype'
---@param fn function
---@return integer # autocmd id for cleanup
function Buffer:on_event(event, fn)
    local map = {
        enter    = 'BufEnter',
        leave    = 'BufLeave',
        save     = 'BufWritePost',
        modify   = 'TextChanged',
        close    = 'BufDelete',
        filetype = 'FileType',
        insert   = 'InsertEnter',
    }
    local autocmd = map[event]
    if not autocmd then
        error('Unknown buffer event: ' .. event)
    end

    local buf = self
    local id = vim.api.nvim_create_autocmd(autocmd, {
        buffer = self._id,
        callback = function(ev)
            fn(buf, ev)
        end,
    })

    _buf_hooks[self._id] = _buf_hooks[self._id] or {}
    _buf_hooks[self._id][event] = _buf_hooks[self._id][event] or {}
    table.insert(_buf_hooks[self._id][event], id)

    return id
end

--- Convenience: buffer enter.
function Buffer:on_enter(fn) return self:on_event('enter', fn) end
--- Convenience: buffer leave.
function Buffer:on_leave(fn) return self:on_event('leave', fn) end
--- Convenience: buffer save.
function Buffer:on_save(fn) return self:on_event('save', fn) end
--- Convenience: text modified.
function Buffer:on_modify(fn) return self:on_event('modify', fn) end

return Buffer
