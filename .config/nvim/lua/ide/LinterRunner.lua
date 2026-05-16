-- LinterRunner: runs external linters and publishes diagnostics.
-- Resolves linters per filetype, spawns processes, parses output into
-- vim.Diagnostic objects, and publishes via vim.diagnostic.set().
-- Supports pattern-based and JSON-based parsers.
--
-- Usage:
--   IDE.linter:register('sh', {{ cmd = 'shellcheck', args = { '--format=json', '-' }, stdin = true, parser = 'json', parse_fn = ... }})
--   IDE.linter:lint(buffer, function(ok) ... end)

local Buffer = require 'ide.Buffer'

local LinterRunner = Class('LinterRunner')

---@class LinterSpec
---@field cmd string|fun(): string # command name or function returning command
---@field args string[]|fun(buf: Buffer): string[] # arguments (supports $FILENAME, $DIRNAME interpolation)
---@field stdin boolean # whether to pipe buffer content via stdin
---@field cwd string|fun(buf: Buffer): string|nil # working directory
---@field condition fun(buf: Buffer): boolean|nil # optional condition check (e.g. eslint config exists)
---@field parser 'json'|'pattern'|nil # output parser type
---@field parse_fn fun(output: string, bufnr: integer): vim.Diagnostic[] # custom parser function
---@field ignore_exitcode boolean|nil # whether to ignore non-zero exit codes
---@field source string|nil # diagnostic source name (defaults to cmd name)

function LinterRunner:init()
    self._registry = {}    ---@type table<string, LinterSpec[]> filetype -> linter specs
    self._running = {}     ---@type table<integer, ProcessHandle[]> bufnr -> running processes
    self._namespaces = {}  ---@type table<string, integer> linter name -> namespace id
end

--- Register linters for a filetype.
---@param filetype string|string[]
---@param linters LinterSpec[]
function LinterRunner:register(filetype, linters)
    local fts = type(filetype) == 'string' and { filetype } or filetype
    for _, ft in ipairs(fts) do
        self._registry[ft] = linters
    end
end

--- Cancel running linters for a buffer.
---@param bufnr integer
function LinterRunner:cancel(bufnr)
    local handles = self._running[bufnr]
    if handles then
        for _, handle in ipairs(handles) do
            handle.kill()
        end
        self._running[bufnr] = nil
    end
end

--- List resolved linters for a filetype.
--- Returns only those whose command is available and condition passes.
---@param filetype string
---@param buf Buffer|nil
---@return string[] # list of command names
function LinterRunner:list_for(filetype, buf)
    local specs = self._registry[filetype]
    if not specs then return {} end

    local result = {}
    for _, spec in ipairs(specs) do
        local cmd = self:_resolve_cmd(spec.cmd)
        if IDE.shell:has(cmd) then
            if spec.condition then
                if buf and spec.condition(buf) then
                    result[#result + 1] = cmd
                end
            else
                result[#result + 1] = cmd
            end
        end
    end
    return result
end

--- Get or create a diagnostic namespace for a linter.
---@param name string
---@return integer
function LinterRunner:_namespace(name)
    if not self._namespaces[name] then
        self._namespaces[name] = vim.api.nvim_create_namespace('ide_lint_' .. name)
    end
    return self._namespaces[name]
end

--- Lint a buffer.
---@param buffer Buffer
---@param callback fun(success: boolean)|nil
function LinterRunner:lint(buffer, callback)
    callback = callback or function() end

    if not buffer:is_valid() or not buffer:is_normal() then
        callback(false)
        return
    end

    local ft = buffer:filetype()
    local specs = self._registry[ft]
    if not specs or #specs == 0 then
        callback(false)
        return
    end

    -- Cancel any running linters for this buffer
    self:cancel(buffer:id())

    local bufnr = buffer:id()
    local content = table.concat(buffer:lines(), '\n') .. '\n'
    local handles = {}
    local pending = 0

    for _, spec in ipairs(specs) do
        local cmd = self:_resolve_cmd(spec.cmd)

        -- Check availability
        if not IDE.shell:has(cmd) then
            goto continue
        end

        -- Check condition
        if spec.condition and not spec.condition(buffer) then
            goto continue
        end

        local args = self:_resolve_args(spec.args, buffer)
        local cwd = self:_resolve_cwd(spec.cwd, buffer)
        local source = spec.source or cmd
        local ns = self:_namespace(source)

        pending = pending + 1

        local handle = IDE.shell:run(cmd, args, {
            stdin = spec.stdin and content or nil,
            cwd = cwd,
        }, function(result)
            if not Buffer.is_valid(bufnr) then return end

            -- Parse output if exit code is acceptable
            if result.code == 0 or spec.ignore_exitcode then
                local diagnostics = {}
                if spec.parse_fn then
                    local ok, parsed = pcall(spec.parse_fn, result.stdout, bufnr)
                    if ok and parsed then
                        diagnostics = parsed
                    end
                end
                vim.diagnostic.set(ns, bufnr, diagnostics)
            elseif result.code ~= 0 then
                -- Non-zero exit without ignore: clear diagnostics for this linter
                vim.diagnostic.set(ns, bufnr, {})
            end

            pending = pending - 1
            if pending == 0 then
                self._running[bufnr] = nil
                callback(true)
            end
        end)

        handles[#handles + 1] = handle

        ::continue::
    end

    if #handles > 0 then
        self._running[bufnr] = handles
    else
        callback(false)
    end
end

--- Clear all diagnostics for a buffer (from all linter namespaces).
---@param bufnr integer
function LinterRunner:clear(bufnr)
    for _, ns in pairs(self._namespaces) do
        vim.diagnostic.set(ns, bufnr, {})
    end
end

--- Resolve a command (string or function).
---@param cmd string|fun(): string
---@return string
function LinterRunner:_resolve_cmd(cmd)
    if type(cmd) == 'function' then return cmd() end
    return cmd
end

--- Resolve arguments, interpolating $FILENAME and $DIRNAME.
---@param args string[]|fun(buf: Buffer): string[]
---@param buf Buffer
---@return string[]
function LinterRunner:_resolve_args(args, buf)
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
function LinterRunner:_resolve_cwd(cwd, buf)
    if not cwd then
        local proj = IDE:project()
        return proj and proj:root() or nil
    end
    if type(cwd) == 'function' then return cwd(buf) end
    return cwd
end

---@return string
function LinterRunner:__tostring()
    local count = vim.tbl_count(self._registry)
    return string.format('LinterRunner(%d filetypes)', count)
end

return LinterRunner
