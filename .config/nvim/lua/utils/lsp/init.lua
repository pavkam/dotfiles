local utils = require 'utils'
local settings = require 'utils.settings'
local progress = require 'utils.progress'

local progress_class = 'lsp'

---@class LspClient
---@field name string
---@field supports_method fun(method: string): boolean
---@field request_sync fun(method: string, params: any, timeout: integer): any
---@field stop fun()
---@field offset_encoding string
---@field config { workspace_folders: { uri: string }[], root_dir: string, capabilities: table }
---@field server_capabilities table

---@class utils.lsp
local M = {}

-- emit a warning when an LSP is dettached!

--- Gets the name of the setting for dettaching a client
---@param client LspClient # the client to get the setting name for
---@return string # the name of the setting
local function detach_processed_setting_name(client)
    return string.format('%s_dettach_processed', client.name)
end

---@type table<string, any>
local lsp_tasks = {}

utils.on_event('LspDetach', function(evt)
    ---@type LspClient
    local client = vim.lsp.get_client_by_id(evt.data.client_id)
    if not client or M.is_special(client) then
        return
    end

    local key = detach_processed_setting_name(client)
    if not settings.get(key, { default = false }) then
        utils.warn('Language Server *' .. client.name .. '* has detached!')
        settings.set(key, true)
    end

    -- clear the tasks for the all clients to prevent infinite loops
    lsp_tasks = {}
end)

utils.on_event('LspAttach', function(evt)
    ---@type LspClient
    local client = vim.lsp.get_client_by_id(evt.data.client_id)
    if not client or M.is_special(client) then
        return
    end

    settings.set(detach_processed_setting_name(client), false)
end)

--- Checks whether there are any active LSP tasks
---@return boolean # whether there are any active tasks
local function lsp_status()
    local finished = vim.tbl_isempty(lsp_tasks)
    return not finished
end

utils.on_user_event('LspProgress', function(_, evt)
    local key = string.format('%s.%s', evt.data.client_id, evt.data.token)
    if evt.data.value.kind ~= 'end' then
        lsp_tasks[key] = evt.data.value
        progress.register_task(progress_class, { prv = true, fn = lsp_status, ctx = evt.data.value.message })
    else
        lsp_tasks[key] = nil
    end
end)

--- Gets the unified progress of all LSP tasks
---@return string|nil,any|nil # the progress of the LSP tasks or nil if not running
function M.progress()
    return progress.status(progress_class)
end

--- Normalizes the name of a capability
---@param capability string # the name of the capability
---@return string # the normalized name of the capability
local function normalize_capability(capability)
    assert(type(capability) == 'string' and capability ~= '')

    capability = capability:find '/' and capability or 'textDocument/' .. capability

    return capability
end

--- Gets all active clients
---@param opts? vim.lsp.get_active_clients.filter # the options to get the clients with
---@return LspClient[] # the active clients
local function get_active_clients(opts)
    local call = vim.lsp.get_active_clients or vim.lsp.get_clients
    return call(opts)
end

--- Checks whether a client is a special client
---@param client LspClient # the client to check
function M.is_special(client)
    assert(client and client.name)

    return client.name == 'copilot'
end

--- Checks whether a client has a capability
---@param client LspClient # the client to check
---@param capability string # the name of the capability
---@return boolean # whether the client has the capability
function M.client_has_capability(client, capability)
    assert(client and client.supports_method)

    return client.supports_method(normalize_capability(capability))
end

--- Checks whether a buffer has a capability
---@param buffer integer|nil # the buffer to check the capability for or 0 or nil for current
---@param method string # the name of the capability
---@return boolean # whether the buffer has the capability
function M.buffer_has_capability(buffer, method)
    buffer = buffer or vim.api.nvim_get_current_buf()

    for _, client in ipairs(get_active_clients { bufnr = buffer }) do
        if M.client_has_capability(client, method) then
            return true
        end
    end

    return false
end

--- Notifies all clients that a file has been renamed
---@param from string # the old name of the file
---@param to string # the new name of the file
function M.notify_file_renamed(from, to)
    assert(type(from) == 'string' and from ~= '')
    assert(type(to) == 'string' and to ~= '')

    local cap = 'workspace/willRenameFiles'
    for _, client in ipairs(get_active_clients()) do
        if M.client_has_capability(client, cap) then
            local resp = client.request_sync(cap, {
                files = {
                    {
                        oldUri = vim.uri_from_fname(from),
                        newUri = vim.uri_from_fname(to),
                    },
                },
            }, 1000)

            if resp and resp.result ~= nil then
                vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
            end
        end
    end
end

--- Registers a callback for a client attach event
---@param callback fun(client: LspClient, buffer: integer) # the callback to register
---@param target string|integer|any[]|nil # the target to register the callback for
function M.on_attach(callback, target)
    assert(type(callback) == 'function' and callback)

    return utils.on_event('LspAttach', function(evt)
        local client = vim.lsp.get_client_by_id(evt.data.client_id)
        callback(client, evt.buf)
    end, target)
end

--- Registers a callback for as long a buffer has a capability
---@param events string|string[] # the events to register the callback for
---@param capability string # the name of the capability
---@param buffer integer|nil # the buffer to register the callback for or 0 or nil for current
---@param callback function # the callback to register
---@return integer|nil # the ID of the auto group
function M.on_capability_event(events, capability, buffer, callback)
    assert(type(callback) == 'function')

    buffer = buffer or vim.api.nvim_get_current_buf()

    capability = normalize_capability(capability)
    events = utils.to_list(events)

    if not M.buffer_has_capability(buffer, capability) then
        return
    end

    local auto_group_name = utils.tbl_join({ 'pavkam', 'buf', 'cap', buffer, unpack(events), capability }, '_')
    ---@cast auto_group_name string

    local group = vim.api.nvim_create_augroup(auto_group_name, { clear = true })

    vim.api.nvim_create_autocmd(events, {
        callback = function()
            if not M.buffer_has_capability(buffer, capability) then
                vim.api.nvim_del_augroup_by_name(auto_group_name)
                return
            end
            callback(buffer)
        end,
        group = group,
        buffer = buffer,
    })
    vim.api.nvim_create_autocmd('BufDelete', {
        callback = function()
            vim.api.nvim_del_augroup_by_name(auto_group_name)
        end,
        group = group,
        buffer = buffer,
    })

    return group
end

--- Gets the names of all active clients for a buffer
---@param buffer integer|nil # the buffer to get the clients for or 0 or nil for current
---@return string[] # the names of the active clients
function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local buf_client_names = {}

    for _, client in ipairs(get_active_clients { bufnr = buffer }) do
        if not M.is_special(client) then
            buf_client_names[#buf_client_names + 1] = client.name
        end
    end

    return buf_client_names
end

--- Checks whether there are any active clients for a buffer
---@param buffer integer|nil # the buffer to check the clients for or 0 or nil for current
---@return boolean # whether there are any active clients
function M.any_active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    local clients = get_active_clients { bufnr = buffer }

    return #clients > 1 or (#clients == 1 and not M.is_special(clients[1]))
end

--- Checks whether a client is active for a buffer
---@param buffer integer|nil # the buffer to check the client for or 0 or nil for current
---@param name string # the name of the client
---@return boolean # whether the client is active
function M.is_active_for_buffer(buffer, name)
    assert(type(name) == 'string' and name ~= '')

    buffer = buffer or vim.api.nvim_get_current_buf()

    local ok, clients = pcall(get_active_clients, { name = name, bufnr = buffer })
    return ok and #clients > 0
end

--- Restarts all active, not-special clients
---@param buffer integer|nil # the buffer to check the client for or 0 or nil for current
function M.restart_all_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    local clients = vim.tbl_filter(function(client)
        return not M.is_special(client)
    end, get_active_clients { bufnr = buffer })

    if #clients == 0 then
        utils.warn 'No active clients to restart. Starting all.'
        vim.cmd 'LspStart'
        return
    end

    for _, client in ipairs(clients) do
        utils.warn('Restarting client ' .. client.name .. '...')
        vim.cmd(string.format('LspRestart %s', client.name))
    end
end

--- Gets the root directories of all active clients for a target buffer or path
---@param target integer|string|function|nil # the target to get the roots for or 0 or nil for current
---@param sort boolean|nil # whether to sort the roots by length
---@return string[] # the root directories of the active clients
function M.roots(target, sort)
    local buffer, path = utils.expand_target(target)

    local roots = {}
    if path then
        for _, client in ipairs(get_active_clients { bufnr = buffer }) do
            local workspace = client.config.workspace_folders
            local paths = workspace and vim.tbl_map(function(ws)
                return vim.uri_to_fname(ws.uri)
            end, workspace) or client.config.root_dir and { client.config.root_dir } or {}

            for _, p in ipairs(paths) do
                local r = vim.loop.fs_realpath(p)
                if r and path:find(r, 1, true) then
                    if not vim.tbl_contains(roots, r) then
                        roots[#roots + 1] = r
                    end
                end
            end
        end
    end

    if sort then
        table.sort(roots, function(a, b)
            return #a > #b
        end)
    end

    return roots
end

--- Clears the diagnostics for a buffer or globally
---@param sources string|string[]|nil # the sources to clear the diagnostics for, or nil for all
---@param buffer integer|nil # the buffer to clear the diagnostics for or 0 or nil for all
function M.clear_diagnostics(sources, buffer)
    if not sources then
        vim.diagnostic.reset(nil, buffer)
        return
    end

    local ns = vim.diagnostic.get_namespaces()

    for _, source in ipairs(utils.to_list(sources)) do
        assert(type(source) == 'string' and source)
        for id, n in pairs(ns) do
            if n.name == source or n.name:find('vim.lsp.' .. source, 1, true) then
                vim.diagnostic.reset(id, buffer)
            end
        end
    end
end

return M
