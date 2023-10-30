local icons = require 'utils.icons'
local utils = require 'utils'

local M = {}

local function normalize_capability(method)
    method = utils.stringify(method)
    method = method:find("/") and method or "textDocument/" .. method

    return method
end

local function get_null_ls_sources(filetype)
    filetype = utils.stringify(filetype)

    -- get the registered methods
    local ok, sources = pcall(require, "null-ls.sources")

    if not ok then
        return {}
    end

    local registered = {}
    for _, source in ipairs(sources.get_available(filetype)) do
        registered = utils.list_insert_unique(registered, source.name)
    end

    return registered
end

function M.is_special(client)
    assert(client and client.name)

    return client.name == "null-ls" or client.name == "copilot"
end

function M.client_has_capability(client, method)
    assert(client and client.supports_method)

    return client.supports_method(normalize_capability(method))
end

function M.buffer_has_capability(buffer, method)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local clients = vim.lsp.get_active_clients({ bufnr = buffer })
    for _, client in ipairs(clients) do
        if M.client_has_capability(client, method) then
            return true
        end
    end

    return false
end

function M.notify_file_renamed(from, to)
    from = utils.stringify(from)
    from = utils.stringify(to)

    assert(from and to)

    local clients = vim.lsp.get_active_clients()

    for _, client in ipairs(clients) do
        if client:supports_method("workspace/willRenameFiles") then
            local resp = client.request_sync("workspace/willRenameFiles", {
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

function M.on_attach(callback, target)
    return utils.on_event(
        "LspAttach",
        function(evt)
            local client = vim.lsp.get_client_by_id(evt.data.client_id)
            callback(client, evt.buf)
        end,
        target
    )
end

function M.on_capability_event(events, capability, buffer, callback)
    assert(type(callback) == "function")

    capability = normalize_capability(capability)
    events = utils.to_list(events)

    if not M.buffer_has_capability(buffer, capability) then
        return
    end

    local auto_group_name = "pavkam_cap_" .. utils.tbl_join(events, "_") .. "_" .. capability

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
end

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

function M.any_active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_active_clients({ bufnr = buffer })

    return #clients > 1 or (#clients == 1 and not M.is_special(clients[1]))
end

function M.is_active_for_buffer(buffer, name)
    buffer = buffer or vim.api.nvim_get_current_buf()
    name = utils.stringify(name)

    assert(name)

    local ok, clients = pcall(vim.lsp.get_active_clients, { name = name, bufnr = buffer })

    return ok and #clients > 0
end

function M.roots(target, sort)
    buffer, path = utils.expand_target(target)

    local roots = {}
    if path then
        local get = vim.lsp.get_clients or vim.lsp.get_active_clients

        for _, client in pairs(get({ bufnr = buffer })) do
            local workspace = client.config.workspace_folders
            local paths = workspace and vim.tbl_map(function(ws)
                return vim.uri_to_fname(ws.uri)
            end, workspace) or client.config.root_dir and { client.config.root_dir } or {}

            for _, p in ipairs(paths) do
                local r = vim.loop.fs_realpath(p)
                if path:find(r, 1, true) then
                    if not utils.list_contains(roots, r) then
                        roots[#roots + 1] = r
                    end
                end
            end
        end
    end

    if sort then
        table.sort(roots, function(a, b) return #a > #b end)
    end

    return roots
end

function M.clear_diagnostics(sources, buffer)
    if not sources then
        vim.diagnostic.reset(nil, buffer)
        return
    end

    local ns = vim.diagnostic.get_namespaces()

    for _, source in ipairs(utils.to_list(sources)) do
        for id, n in pairs(ns) do
            if n.name == source or n.name:find("vim.lsp." .. source, 1, true) then
                vim.diagnostic.reset(id, buffer)
            end
        end
    end
end

return M
