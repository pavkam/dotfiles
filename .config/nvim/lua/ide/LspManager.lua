-- LspManager: manages all LSP servers as objects.
-- Wraps vim.lsp.config/enable with server registration, capability
-- merging, and attach/detach events.
--
-- Events: 'attach', 'detach', 'progress'

local EventEmitter = require 'ide.EventEmitter'
local LspServer = require 'ide.LspServer'

local LspManager = Class('LspManager')
Class.include(LspManager, EventEmitter)

function LspManager:init()
    self._servers = {} ---@type table<string, LspServer>
    self._capabilities = nil ---@type table|nil
end

--- Set global capabilities (merged with each server's config).
---@param caps table
---@return LspManager
function LspManager:set_capabilities(caps)
    self._capabilities = caps
    vim.lsp.config('*', {
        capabilities = vim.deepcopy(caps),
        root_markers = { '.git' },
    })
    return self
end

--- Register a server. Does NOT enable it yet.
---@param name string
---@param config table|nil
---@return LspServer
function LspManager:register(name, config)
    local server = LspServer(name, config)
    self._servers[name] = server
    return server
end

--- Register and immediately enable a server.
---@param name string
---@param config table|nil
---@return LspServer
function LspManager:add(name, config)
    return self:register(name, config):enable()
end

--- Get a registered server by name.
---@param name string
---@return LspServer|nil
function LspManager:get(name)
    return self._servers[name]
end

--- Enable all registered servers.
function LspManager:enable_all()
    local names = {}
    for name, server in pairs(self._servers) do
        if next(server._config) then
            vim.lsp.config(name, server._config)
        end
        table.insert(names, name)
        server._enabled = true
    end
    if #names > 0 then
        vim.lsp.enable(names)
    end
end

--- All registered server names.
---@return string[]
function LspManager:server_names()
    return vim.tbl_keys(self._servers)
end

--- All active servers (have running clients).
---@return LspServer[]
function LspManager:active()
    local result = {}
    for _, server in pairs(self._servers) do
        if server:is_active() then
            table.insert(result, server)
        end
    end
    return result
end

--- All clients attached to a buffer.
---@param bufnr integer
---@return vim.lsp.Client[]
function LspManager:clients_for_buffer(bufnr)
    return vim.lsp.get_clients { bufnr = bufnr }
end

--- Wire autocommands for LSP lifecycle events.
function LspManager:_wire_events()
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client then
                local server = self._servers[client.name]
                if server then
                    server:emit('attach', client, args.buf)
                end
                self:emit('attach', client, args.buf)
            end
        end,
    })

    vim.api.nvim_create_autocmd('LspDetach', {
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client then
                local server = self._servers[client.name]
                if server then
                    server:emit('detach', client, args.buf)
                end
                self:emit('detach', client, args.buf)
            end
        end,
    })
end

--- Iterator over all registered servers.
---@return fun(): string|nil, LspServer|nil
function LspManager:iter()
    return pairs(self._servers)
end

-- LSP actions — wraps vim.lsp.buf.* into clean methods

function LspManager:go_to_definition()
    vim.lsp.buf.definition()
end

function LspManager:rename()
    vim.lsp.buf.rename()
end

function LspManager:code_action()
    vim.lsp.buf.code_action()
end

function LspManager:hover()
    vim.lsp.buf.hover()
end

function LspManager:signature_help()
    vim.lsp.buf.signature_help()
end

--- Go to declaration.
function LspManager:declaration()
    vim.lsp.buf.declaration()
end

--- Run code lens on current line.
function LspManager:run_codelens()
    vim.lsp.codelens.run()
end

--- Highlight references of symbol under cursor.
function LspManager:highlight_references()
    vim.lsp.buf.document_highlight()
end

--- Clear reference highlights.
function LspManager:clear_references()
    vim.lsp.buf.clear_references()
end

--- Jump to the next/prev occurrence of the highlighted token under cursor.
---@param direction integer # 1 for next, -1 for prev
---@return boolean # whether a jump was made
function LspManager:jump_reference(direction)
    local forward = direction > 0
    local Window = require 'ide.Window'
    local win = Window.current()
    local buf_id = vim.api.nvim_win_get_buf(win:id())

    local clients = vim.lsp.get_clients({ bufnr = buf_id })
    if not clients or #clients == 0 then return false end

    local reply = vim.lsp.buf_request_sync(
        buf_id,
        vim.lsp.protocol.Methods.textDocument_documentHighlight,
        vim.lsp.util.make_position_params(0, clients[1].offset_encoding),
        1000
    )

    local first = reply and next(reply) and reply[next(reply)]
    if not first or not first.result then return false end

    local highlights = {}
    for _, h in ipairs(first.result) do
        highlights[#highlights + 1] = h.range
    end
    table.sort(highlights, function(a, b)
        return a.start.line < b.start.line
            or (a.start.line == b.start.line and a.start.character < b.start.character)
    end)

    local cursor = win:cursor()
    local cur_row, cur_col = cursor.row - 1, cursor.col - 1

    for i, range in ipairs(highlights) do
        if range.start.line == cur_row
            and range.start.character <= cur_col
            and range['end'].character >= cur_col then
            local target
            if forward then
                target = highlights[i < #highlights and i + 1 or 1]
            else
                target = highlights[i > 1 and i - 1 or #highlights]
            end
            if target then
                local Position = require 'ide.Position'
                win:set_cursor(Position(target.start.line + 1, target.start.character + 1))
                return true
            end
        end
    end
    return false
end

function LspManager:show_diagnostic()
    vim.diagnostic.open_float()
end

--- Get an LSP client by id.
---@param id integer
---@return vim.lsp.Client|nil
function LspManager:client_by_id(id)
    return vim.lsp.get_client_by_id(id)
end

--- Get all LSP clients matching a server name.
---@param name string
---@return vim.lsp.Client[]
function LspManager:clients_by_name(name)
    return vim.lsp.get_clients({ name = name })
end

--- Enable/disable inlay hints.
---@param enabled boolean
---@param opts { bufnr?: integer }|nil
function LspManager:enable_inlay_hints(enabled, opts)
    vim.lsp.inlay_hint.enable(enabled, opts and { bufnr = opts.bufnr } or nil)
end

--- Enable/disable codelens.
---@param enabled boolean
---@param opts { bufnr?: integer }|nil
function LspManager:enable_codelens(enabled, opts)
    vim.lsp.codelens.enable(enabled, opts and { bufnr = opts.bufnr } or nil)
end

--- Enable/disable semantic tokens.
---@param enabled boolean
---@param opts { bufnr?: integer, client_id?: integer }|nil
function LspManager:enable_semantic_tokens(enabled, opts)
    if opts and (opts.bufnr or opts.client_id) then
        vim.lsp.semantic_tokens.enable(enabled, { bufnr = opts.bufnr, client_id = opts.client_id })
    else
        for _, client in ipairs(vim.lsp.get_clients()) do
            vim.lsp.semantic_tokens.enable(enabled, { bufnr = 0, client_id = client.id })
        end
    end
end

function LspManager:enable_diagnostics(enabled)
    vim.diagnostic.enable(enabled)
end

--- Notify all LSP clients that a file was renamed.
---@param old_path string
---@param new_path string
function LspManager:notify_file_renamed(old_path, new_path)
    local method = 'workspace/willRenameFiles'
    for _, client in ipairs(vim.lsp.get_clients({ method = method })) do
        local resp = client:request_sync(method, {
            files = {{
                oldUri = vim.uri_from_fname(old_path),
                newUri = vim.uri_from_fname(new_path),
            }},
        }, 1000, 0)
        if resp and resp.result then
            vim.lsp.util.apply_workspace_edit(resp.result, 'utf-16')
        end
    end
end

--- Check if a buffer has a specific LSP capability.
---@param bufnr integer|nil # buffer (nil for current)
---@param method string # LSP method name
---@return boolean
function LspManager:buffer_has_capability(bufnr, method)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    return #vim.lsp.get_clients({ bufnr = bufnr, method = method }) > 0
end

--- Register a callback for LspAttach events.
---@param callback fun(client: vim.lsp.Client, bufnr: integer)
function LspManager:on_attach(callback)
    local id = vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(evt)
            local client = vim.lsp.get_client_by_id(evt.data.client_id)
            if client then callback(client, evt.buf) end
        end,
    })
    return function() pcall(vim.api.nvim_del_autocmd, id) end
end

--- Get LSP workspace roots for a buffer.
---@param bufnr integer|nil
---@return string[]
function LspManager:roots(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local roots = {}
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        local ws = client.config.workspace_folders
        local paths = ws and vim.iter(ws):map(function(w) return vim.uri_to_fname(w.uri) end):totable()
            or client.config.root_dir and { client.config.root_dir }
            or {}
        for _, p in ipairs(paths) do
            local r = vim.uv.fs_realpath(p)
            if r and not vim.tbl_contains(roots, r) then
                roots[#roots + 1] = r
            end
        end
    end
    return roots
end

---@return string
function LspManager:__tostring()
    local active = #self:active()
    local total = vim.tbl_count(self._servers)
    return string.format('LspManager(%d/%d active)', active, total)
end

return LspManager
