local utils = require 'utils'

local M = {}

--- Normalizes the name of a capability
---@param method string # the name of the capability
---@return string # the normalized name of the capability
local function normalize_capability(method)
    assert(type(method) == 'string' and method)

    method = method:find '/' and method or 'textDocument/' .. method

    return method
end

--- Checks whether a client is a special client
---@param client { name: string } # the client to check
function M.is_special(client)
    assert(client and client.name)

    return client.name == 'copilot'
end

--- Checks whether a client has a capability
---@param client { supports_method: function } # the client to check
---@param method string # the name of the capability
---@return boolean # whether the client has the capability
function M.client_has_capability(client, method)
    assert(client and client.supports_method)

    return client.supports_method(normalize_capability(method))
end

--- Checks whether a buffer has a capability
---@param buffer integer|nil # the buffer to check the capability for or 0 or nil for current
---@param method string # the name of the capability
---@return boolean # whether the buffer has the capability
function M.buffer_has_capability(buffer, method)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local clients = vim.lsp.get_active_clients { bufnr = buffer }
    for _, client in ipairs(clients) do
        if M.client_has_capability(client, method) then
            return true
        end
    end

    return false
end

--- Notifies all clients that a file has been renamed
---@param from any # the old name of the file
---@param to any # the new name of the file
function M.notify_file_renamed(from, to)
    from = utils.stringify(from)
    from = utils.stringify(to)

    assert(from and to)

    local clients = vim.lsp.get_active_clients()

    for _, client in ipairs(clients) do
        if client:supports_method 'workspace/willRenameFiles' then
            local resp = client.request_sync('workspace/willRenameFiles', {
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
---@param callback function # the callback to register
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

    capability = normalize_capability(capability)
    events = utils.to_list(events)

    if not M.buffer_has_capability(buffer, capability) then
        return
    end

    local auto_group_name = 'pavkam_cap_' .. utils.tbl_join(events, '_') .. '_' .. capability

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

    return group
end

--- Gets the names of all active clients for a buffer
---@param buffer integer|nil # the buffer to get the clients for or 0 or nil for current
---@return string[] # the names of the active clients
function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local buf_client_names = {}

    for _, client in pairs(vim.lsp.get_active_clients { bufnr = buffer }) do
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
    local clients = vim.lsp.get_active_clients { bufnr = buffer }

    return #clients > 1 or (#clients == 1 and not M.is_special(clients[1]))
end

--- Checks whether a client is active for a buffer
---@param buffer integer|nil # the buffer to check the client for or 0 or nil for current
---@param name any # the name of the client
---@return boolean # whether the client is active
function M.is_active_for_buffer(buffer, name)
    buffer = buffer or vim.api.nvim_get_current_buf()
    name = utils.stringify(name)

    assert(name)

    local ok, clients = pcall(vim.lsp.get_active_clients, { name = name, bufnr = buffer })

    return ok and #clients > 0
end

--- Gets the root directories of all active clients for a target buffer or path
---@param target integer|string|function|nil # the target to get the roots for or 0 or nil for current
---@param sort boolean|nil # whether to sort the roots by length
---@return string[] # the root directories of the active clients
function M.roots(target, sort)
    local buffer, path = utils.expand_target(target)

    local roots = {}
    if path then
        local get = vim.lsp.get_clients or vim.lsp.get_active_clients

        for _, client in pairs(get { bufnr = buffer }) do
            local workspace = client.config.workspace_folders
            local paths = workspace and vim.tbl_map(function(ws)
                return vim.uri_to_fname(ws.uri)
            end, workspace) or client.config.root_dir and { client.config.root_dir } or {}

            for _, p in ipairs(paths) do
                local r = vim.loop.fs_realpath(p)
                if r and path:find(r, 1, true) then
                    if not utils.list_contains(roots, r) then
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
