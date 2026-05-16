-- FormatterRunner: runs external formatters on buffer content and applies results.
-- Resolves formatters per filetype, chains them sequentially, applies diff-based edits
-- to preserve cursor position and undo history. Falls back to LSP formatting when
-- no CLI formatter is available.
--
-- Usage:
--   IDE.formatter:register('lua', {{ cmd = 'stylua', args = { '-' }, stdin = true }})
--   IDE.formatter:format(buffer, { async = true }, function(ok) ... end)

local Buffer = require 'ide.Buffer'

local FormatterRunner = Class('FormatterRunner')

---@class FormatterSpec
---@field cmd string|fun(): string # command name or function returning command
---@field args string[]|fun(buf: Buffer): string[] # arguments (supports $FILENAME, $DIRNAME interpolation)
---@field stdin boolean # whether to pipe buffer content via stdin
---@field cwd string|fun(buf: Buffer): string|nil # working directory
---@field condition fun(buf: Buffer): boolean|nil # optional condition check

function FormatterRunner:init()
    self._registry = {} ---@type table<string, FormatterSpec[][]> filetype -> list of formatter groups
    self._running = {}  ---@type table<integer, ProcessHandle> bufnr -> running process
end

--- Register formatters for a filetype.
--- Each entry in `groups` is a list of alternatives (first available wins).
--- Groups are chained sequentially (output of one -> input of next).
---@param filetype string|string[]
---@param groups FormatterSpec[][] # list of groups, each group is a list of alternatives
function FormatterRunner:register(filetype, groups)
    local fts = type(filetype) == 'string' and { filetype } or filetype
    for _, ft in ipairs(fts) do
        self._registry[ft] = groups
    end
end

--- Cancel a running formatter for a buffer.
---@param bufnr integer
function FormatterRunner:cancel(bufnr)
    local handle = self._running[bufnr]
    if handle then
        handle.kill()
        self._running[bufnr] = nil
    end
end

--- List resolved formatters for a filetype.
--- Returns only those whose command is available and condition passes.
---@param filetype string
---@param buf Buffer|nil
---@return string[] # list of command names
function FormatterRunner:list_for(filetype, buf)
    local groups = self._registry[filetype]
    if not groups then return {} end

    local result = {}
    for _, group in ipairs(groups) do
        local chosen = self:_resolve_group(group, buf)
        if chosen then
            result[#result + 1] = self:_resolve_cmd(chosen.cmd)
        end
    end
    return result
end

--- Format a buffer.
---@param buffer Buffer
---@param opts { timeout_ms?: integer, async?: boolean, lsp_fallback?: boolean }|nil
---@param callback fun(success: boolean)|nil
function FormatterRunner:format(buffer, opts, callback)
    opts = opts or {}
    callback = callback or function() end

    local ft = buffer:filetype()
    local groups = self._registry[ft]

    -- No formatters registered: try LSP fallback
    if not groups or #groups == 0 then
        if opts.lsp_fallback ~= false then
            self:_lsp_format(buffer, opts)
            callback(true)
        else
            callback(false)
        end
        return
    end

    -- Resolve the chain of formatters
    local chain = {}
    for _, group in ipairs(groups) do
        local chosen = self:_resolve_group(group, buffer)
        if chosen then
            chain[#chain + 1] = chosen
        end
    end

    if #chain == 0 then
        if opts.lsp_fallback ~= false then
            self:_lsp_format(buffer, opts)
            callback(true)
        else
            callback(false)
        end
        return
    end

    -- Cancel any running formatter for this buffer
    self:cancel(buffer:id())

    -- Get original content
    local original_lines = buffer:lines()
    local original_text = table.concat(original_lines, '\n') .. '\n'

    -- Run the chain
    if opts.async == false then
        self:_run_chain_sync(buffer, chain, original_text, original_lines, opts, callback)
    else
        self:_run_chain_async(buffer, chain, original_text, original_lines, 1, opts, callback)
    end
end

--- Run the formatter chain synchronously.
---@param buffer Buffer
---@param chain FormatterSpec[]
---@param content string
---@param original_lines string[]
---@param opts table
---@param callback fun(success: boolean)
function FormatterRunner:_run_chain_sync(buffer, chain, content, original_lines, opts, callback)
    local current = content
    local timeout = opts.timeout_ms or 5000

    for _, spec in ipairs(chain) do
        local cmd = self:_resolve_cmd(spec.cmd)
        local args = self:_resolve_args(spec.args, buffer)
        local cwd = self:_resolve_cwd(spec.cwd, buffer)

        local result = IDE.shell:run_sync(cmd, args, {
            stdin = spec.stdin and current or nil,
            cwd = cwd,
            timeout = timeout,
        })

        if result.code ~= 0 then
            -- Formatter failed, skip it but continue with current content
            -- (don't abort the whole chain)
            goto continue
        end

        if spec.stdin and result.stdout ~= '' then
            current = result.stdout
        end

        ::continue::
    end

    -- Apply the result if content changed
    if current ~= content then
        self:_apply_diff(buffer, original_lines, current)
    end
    callback(true)
end

--- Run the formatter chain asynchronously (one at a time).
---@param buffer Buffer
---@param chain FormatterSpec[]
---@param content string
---@param original_lines string[]
---@param index integer
---@param opts table
---@param callback fun(success: boolean)
function FormatterRunner:_run_chain_async(buffer, chain, content, original_lines, index, opts, callback)
    if index > #chain then
        -- All formatters done, apply the result
        local original_text = table.concat(original_lines, '\n') .. '\n'
        if content ~= original_text then
            self:_apply_diff(buffer, original_lines, content)
        end
        self._running[buffer:id()] = nil
        callback(true)
        return
    end

    local spec = chain[index]
    local cmd = self:_resolve_cmd(spec.cmd)
    local args = self:_resolve_args(spec.args, buffer)
    local cwd = self:_resolve_cwd(spec.cwd, buffer)

    local handle = IDE.shell:run(cmd, args, {
        stdin = spec.stdin and content or nil,
        cwd = cwd,
    }, function(result)
        self._running[buffer:id()] = nil

        if not buffer:is_valid() then
            callback(false)
            return
        end

        local next_content = content
        if result.code == 0 and spec.stdin and result.stdout ~= '' then
            next_content = result.stdout
        end

        -- Continue with next formatter in the chain
        self:_run_chain_async(buffer, chain, next_content, original_lines, index + 1, opts, callback)
    end)

    self._running[buffer:id()] = handle
end

--- Apply formatted content using diff-based text edits.
--- Uses vim.diff to compute minimal changes, preserving cursor and undo.
---@param buffer Buffer
---@param original_lines string[]
---@param new_content string
function FormatterRunner:_apply_diff(buffer, original_lines, new_content)
    if not buffer:is_valid() then return end

    local new_lines = vim.split(new_content, '\n', { plain = true })
    -- Remove trailing empty line that comes from the final \n
    if #new_lines > 0 and new_lines[#new_lines] == '' then
        table.remove(new_lines)
    end

    local old_text = table.concat(original_lines, '\n') .. '\n'
    local new_text = table.concat(new_lines, '\n') .. '\n'

    if old_text == new_text then return end

    -- Use vim.diff to get changed hunks
    local ok, hunks = pcall(vim.diff, old_text, new_text, { result_type = 'indices' })
    if not ok or not hunks or #hunks == 0 then
        -- Fallback: full replacement
        buffer:set_lines(0, -1, new_lines)
        return
    end

    -- Apply hunks in reverse order so indices stay valid
    for i = #hunks, 1, -1 do
        local hunk = hunks[i]
        local old_start = hunk[1] -- 1-indexed line in old
        local old_count = hunk[2] -- number of old lines
        local new_start = hunk[3] -- 1-indexed line in new
        local new_count = hunk[4] -- number of new lines

        -- Extract replacement lines from new content
        local replacement = {}
        for j = new_start, new_start + new_count - 1 do
            replacement[#replacement + 1] = new_lines[j] or ''
        end

        -- Convert to 0-indexed for nvim API
        local start_line = old_start - 1
        local end_line = old_start - 1 + old_count

        buffer:set_lines(start_line, end_line, replacement)
    end
end

--- Format using LSP as fallback.
---@param buffer Buffer
---@param opts table
function FormatterRunner:_lsp_format(buffer, opts)
    vim.lsp.buf.format {
        bufnr = buffer:id(),
        timeout_ms = opts.timeout_ms or 5000,
    }
end

--- Resolve a formatter group: pick the first available alternative.
---@param group FormatterSpec[]
---@param buf Buffer|nil
---@return FormatterSpec|nil
function FormatterRunner:_resolve_group(group, buf)
    for _, spec in ipairs(group) do
        local cmd = self:_resolve_cmd(spec.cmd)
        if IDE.shell:has(cmd) then
            if spec.condition and buf then
                if spec.condition(buf) then
                    return spec
                end
            elseif not spec.condition then
                return spec
            end
        end
    end
    return nil
end

--- Resolve a command (string or function).
---@param cmd string|fun(): string
---@return string
function FormatterRunner:_resolve_cmd(cmd)
    if type(cmd) == 'function' then return cmd() end
    return cmd
end

--- Resolve arguments, interpolating $FILENAME and $DIRNAME.
---@param args string[]|fun(buf: Buffer): string[]
---@param buf Buffer
---@return string[]
function FormatterRunner:_resolve_args(args, buf)
    local raw = type(args) == 'function' and args(buf) or args
    if not raw then return {} end

    local path = buf:path() or ''
    local dir = IDE.fs:dirname(path)

    local resolved = {}
    for _, arg in ipairs(raw) do
        if type(arg) == 'string' then
            local s = arg:gsub('%$FILENAME', path):gsub('%$DIRNAME', dir)
            resolved[#resolved + 1] = s
        elseif type(arg) == 'function' then
            resolved[#resolved + 1] = arg(buf)
        else
            resolved[#resolved + 1] = tostring(arg)
        end
    end
    return resolved
end

--- Resolve working directory.
---@param cwd string|fun(buf: Buffer): string|nil
---@param buf Buffer
---@return string|nil
function FormatterRunner:_resolve_cwd(cwd, buf)
    if not cwd then
        local proj = IDE:project()
        return proj and proj:root() or nil
    end
    if type(cwd) == 'function' then return cwd(buf) end
    return cwd
end

--- Format a range of lines in a buffer (used by `gq` via formatexpr).
--- Falls back to LSP range formatting when no CLI formatter is available.
---@param buffer Buffer
---@param start_lnum integer # 1-indexed start line
---@param end_lnum integer # 1-indexed end line (inclusive)
---@param opts { timeout_ms?: integer }|nil
function FormatterRunner:format_range(buffer, start_lnum, end_lnum, opts)
    opts = opts or {}
    local ft = buffer:filetype()
    local groups = self._registry[ft]

    -- If the range covers the whole buffer, delegate to full format
    local total_lines = vim.api.nvim_buf_line_count(buffer:id())
    if start_lnum <= 1 and end_lnum >= total_lines then
        self:format(buffer, { async = false, timeout_ms = opts.timeout_ms })
        return
    end

    -- For range formatting, prefer LSP (most CLI formatters don't support ranges)
    local end_line = vim.fn.getline(end_lnum)
    local end_col = end_line and #end_line or 0

    vim.lsp.buf.format {
        bufnr = buffer:id(),
        timeout_ms = opts.timeout_ms or 5000,
        range = {
            start = { start_lnum, 0 },
            ['end'] = { end_lnum, end_col },
        },
    }
end

--- Implements formatexpr for use with `gq`.
--- Designed to be called as `vim.bo[bufnr].formatexpr = "v:lua.IDE.formatter:formatexpr()"`.
--- Returns 0 on success (handled), 1 to fall back to internal formatting.
---@return integer # 0 = handled, 1 = fall back to internal
function FormatterRunner:formatexpr()
    -- In insert/replace mode, formatexpr is called when exceeding textwidth.
    -- Fall back to internal formatting in that case.
    if vim.tbl_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
        return 1
    end

    local start_lnum = vim.v.lnum
    local end_lnum = start_lnum + vim.v.count - 1

    if start_lnum <= 0 or end_lnum <= 0 then
        return 0
    end

    local bufnr = vim.api.nvim_get_current_buf()
    if not Buffer.is_valid(bufnr) then
        return 1
    end

    local buffer = Buffer.get(bufnr)
    if not buffer:is_normal() then
        return 1
    end

    self:format_range(buffer, start_lnum, end_lnum, { timeout_ms = 5000 })
    return 0
end

---@return string
function FormatterRunner:__tostring()
    local count = vim.tbl_count(self._registry)
    return string.format('FormatterRunner(%d filetypes)', count)
end

return FormatterRunner
