local lsp_keymaps = require "lsp-keymaps"

local M = {}

local function has_capability(buffer, method)
    method = method:find("/") and method or "textDocument/" .. method
    local clients = vim.lsp.get_active_clients({ bufnr = buffer })
    for _, client in ipairs(clients) do
        if client.supports_method(method) then
        return true
        end
    end
    return false
end

local function resolve(buffer)
    local Keys = require("lazy.core.handler.keys")
    local keymaps = {}

    local function add(keymap)
        local keys = Keys.parse(keymap)
        if keys[2] == false then
            keymaps[keys.id] = nil
        else
            keymaps[keys.id] = keys
        end
    end

    for _, keymap in ipairs(lsp_keymaps) do
        add(keymap)
    end

    function lsp_custom_opts()
        local plugin = require("lazy.core.config").plugins["nvim-lspconfig"]
        local Plugin = require("lazy.core.plugin")
        return Plugin.values(plugin, "opts", false)
    end

    local opts = lsp_custom_opts()
    local clients = vim.lsp.get_active_clients({ bufnr = buffer })
    for _, client in ipairs(clients) do
        local maps = opts.servers[client.name] and opts.servers[client.name].keys or {}
        for _, keymap in ipairs(maps) do
        add(keymap)
        end
    end
    return keymaps
end

function M.on_attach(client, buffer)
    local Keys = require("lazy.core.handler.keys")
    local keymaps = resolve(buffer)

    for _, keys in pairs(keymaps) do
        if not keys.has or has_capability(buffer, keys.has) then
            local opts = Keys.opts(keys)
            opts.has = nil
            opts.silent = opts.silent ~= false
            opts.buffer = buffer
            vim.keymap.set(keys.mode or "n", keys[1], keys[2], opts)
        end
    end
end

return M
