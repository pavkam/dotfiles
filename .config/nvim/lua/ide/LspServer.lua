-- LspServer: OOP abstraction over a single LSP server.
-- Wraps vim.lsp.config() + vim.lsp.enable() with reactive events.
--
-- Events: 'attach', 'detach'

local EventEmitter = require 'ide.EventEmitter'

local LspServer = Class('LspServer')
Class.include(LspServer, EventEmitter)

---@param name string
---@param config table|nil # server config (settings, root_markers, etc.)
function LspServer:init(name, config)
    assert(type(name) == 'string' and name ~= '', 'server name required')
    self._name = name
    self._config = config or {}
    self._enabled = false
end

---@return string
function LspServer:name()
    return self._name
end

--- Apply config and enable this server.
---@return LspServer
function LspServer:enable()
    if self._enabled then return self end
    if next(self._config) then
        vim.lsp.config(self._name, self._config)
    end
    vim.lsp.enable(self._name)
    self._enabled = true
    return self
end

--- Disable this server.
---@return LspServer
function LspServer:disable()
    vim.lsp.enable(self._name, false)
    self._enabled = false
    return self
end

---@return boolean
function LspServer:is_enabled()
    return self._enabled
end

--- Get running clients for this server.
---@param bufnr integer|nil
---@return vim.lsp.Client[]
function LspServer:clients(bufnr)
    local opts = { name = self._name }
    if bufnr then opts.bufnr = bufnr end
    return vim.lsp.get_clients(opts)
end

--- Check if this server has any active clients.
---@return boolean
function LspServer:is_active()
    return #self:clients() > 0
end

-- Fluent builder methods for config

---@param settings table
---@return LspServer
function LspServer:settings(settings)
    self._config.settings = settings
    return self
end

---@param markers string[]
---@return LspServer
function LspServer:root_markers(markers)
    self._config.root_markers = markers
    return self
end

---@param opts table
---@return LspServer
function LspServer:init_options(opts)
    self._config.init_options = opts
    return self
end

---@param fn fun(params: table, config: table)
---@return LspServer
function LspServer:before_init(fn)
    self._config.before_init = fn
    return self
end

---@return string
function LspServer:__tostring()
    return string.format('LspServer(%s, %s)', self._name,
        self._enabled and 'enabled' or 'disabled')
end

return LspServer
