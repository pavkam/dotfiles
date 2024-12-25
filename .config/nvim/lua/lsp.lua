local events = require 'events'

---@class utils.lsp
local M = {}

--- Checks whether a client is a special client
---@param client vim.lsp.Client # the client to check
function M.is_special(client)
    assert(client and client.name)

    return client.name == 'copilot' or client.name == 'typos_lsp'
end

--- Checks whether a buffer has a capability
---@param buffer integer|nil # the buffer to check the capability for or 0 or nil for current
---@param method string # the name of the capability
---@return boolean # whether the buffer has the capability
function M.buffer_has_capability(buffer, method)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local clients = vim.lsp.get_clients { bufnr = buffer, method = method }

    return clients and #clients > 0
end

--- Notifies all clients that a file has been renamed
---@param from string # the old name of the file
---@param to string # the new name of the file
function M.notify_file_renamed(from, to)
    assert(type(from) == 'string' and from ~= '')
    assert(type(to) == 'string' and to ~= '')

    local method = 'workspace/willRenameFiles'
    for _, client in ipairs(vim.lsp.get_clients { method = method }) do
        local resp = client.request_sync(method, {
            files = {
                {
                    oldUri = vim.uri_from_fname(from),
                    newUri = vim.uri_from_fname(to),
                },
            },
        }, 1000, 0)

        if resp and resp.result ~= nil then
            vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
        end
    end
end

--- Registers a callback for a client attach event
---@param callback fun(client: vim.lsp.Client, buffer: integer) # the callback to register
---@param target string|integer|any[]|nil # the target to register the callback for
function M.on_attach(callback, target)
    assert(type(callback) == 'function' and callback)

    return events.on_event('LspAttach', function(evt)
        local client = vim.lsp.get_client_by_id(evt.data.client_id)
        if client then
            callback(client, evt.buf)
        end
    end, target)
end

--- Registers a callback for as long a buffer has a capability
---@param event string|string[] # the events to register the callback for
---@param capability string # the name of the capability
---@param buffer integer|nil # the buffer to register the callback for or 0 or nil for current
---@param callback function # the callback to register
---@param run_on_register boolean|nil # whether to run the callback on register
---@return string|nil # the name of the auto group
function M.on_capability_event(event, capability, buffer, callback, run_on_register)
    assert(type(callback) == 'function')
    assert(type(capability) == 'string' and capability ~= '')

    buffer = buffer or vim.api.nvim_get_current_buf()

    event = table.to_list(event)

    if not M.buffer_has_capability(buffer, capability) then
        return
    end

    local auto_group_name = table.concat({ 'pavkam', 'buf', 'cap', buffer, unpack(event), capability }, '_')
    ---@cast auto_group_name string

    if vim.fn.exists('#' .. auto_group_name) == 1 then
        return
    end

    if run_on_register then
        callback(buffer)
    end

    vim.api.nvim_create_augroup(auto_group_name, { clear = true })

    vim.api.nvim_create_autocmd(event, {
        callback = function()
            if not M.buffer_has_capability(buffer, capability) then
                if vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_is_loaded(buffer) then
                    ide.tui.warn('Buffer lost capability `' .. capability .. '`')
                end

                vim.api.nvim_del_augroup_by_name(auto_group_name)
                return
            end
            if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buftype == '' then
                callback(buffer)
            end
        end,
        group = auto_group_name,
        buffer = buffer,
    })
    vim.api.nvim_create_autocmd('BufDelete', {
        callback = function()
            vim.api.nvim_del_augroup_by_name(auto_group_name)
        end,
        group = auto_group_name,
        buffer = buffer,
    })

    return auto_group_name
end

--- Gets all active clients
---@param buffer integer|nil # the buffer to get the clients for or 0 or nil for current
---@return vim.lsp.Client[] # the active clients
function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    ---@type vim.lsp.Client[]
    return vim.iter(vim.lsp.get_clients { bufnr = buffer })
        :filter(
            ---@param client vim.lsp.Client
            function(client)
                return not M.is_special(client)
            end
        )
        :totable()
end

--- Gets the names of all active clients for a buffer
---@param buffer integer|nil # the buffer to get the clients for or 0 or nil for current
---@return string[] # the names of the active clients
function M.active_names_for_buffer(buffer)
    return vim.iter(M.active_for_buffer(buffer))
        :map(function(client)
            return client.name
        end)
        :totable()
end

--- Checks whether there are any active clients for a buffer
---@param buffer integer|nil # the buffer to check the clients for or 0 or nil for current
---@return boolean # whether there are any active clients
function M.any_active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients { bufnr = buffer }

    return #clients > 1 or (#clients == 1 and not M.is_special(clients[1]))
end

--- Checks whether a client is active for a buffer
---@param buffer integer|nil # the buffer to check the client for or 0 or nil for current
---@param name string # the name of the client
---@return boolean # whether the client is active
function M.is_active_for_buffer(buffer, name)
    assert(type(name) == 'string' and name ~= '')

    buffer = buffer or vim.api.nvim_get_current_buf()

    local clients = vim.lsp.get_clients { name = name, bufnr = buffer }
    return #clients > 0
end

--- Gets the root directories of all active clients for a target buffer or path
---@param target integer|string|nil # the target to get the roots for or 0 or nil for current
---@param sort boolean|nil # whether to sort the roots by length
---@return string[] # the root directories of the active clients
function M.roots(target, sort)
    local buffer, path = vim.fn.expand_target(target)

    local roots = {}
    if path then
        for _, client in ipairs(vim.lsp.get_clients { bufnr = buffer }) do
            local workspace = client.config.workspace_folders

            ---@type string[]
            local paths = workspace
                    and vim.iter(workspace)
                        :map(
                            ---@param ws lsp.WorkspaceFolder
                            function(ws)
                                return vim.uri_to_fname(ws.uri)
                            end
                        )
                        :totable()
                or client.config.root_dir and { client.config.root_dir }
                or {}

            for _, p in ipairs(paths) do
                local r = vim.uv.fs_realpath(p)
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

return M
