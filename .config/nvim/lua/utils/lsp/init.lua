local icons = require 'utils.icons'
local utils = require 'utils'

local M = {}

local function normalize_capability(method)
    method = method:find("/") and method or "textDocument/" .. method
    return method
end

local function get_null_ls_sources(filetype)
    -- get the registered methods
    local ok, sources = pcall(require, "null-ls.sources")

    if not ok then
        return {}
    end

    local registered = {}
    for _, source in ipairs(sources.get_available(filetype)) do
        utils.list_insert_unique(registered, source.name)
    end

    return registered
end

function M.client_has_capability(client, method)
    return client.supports_method(normalize_capability(method))
end

function M.buffer_has_capability(buffer, method)
    local clients = vim.lsp.get_active_clients({ bufnr = buffer })
    for _, client in ipairs(clients) do
        if M.client_has_capability(client, method) then
            return true
        end
    end

    return false
end

function M.notify_file_renamed(from, to)
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

function M.on_attach(callback)
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local buffer = args.buf
            local client = vim.lsp.get_client_by_id(args.data.client_id)

            callback(client, buffer)
        end,
    })
end

function M.auto_command_on_capability(event, capability, buffer, callback)
    capability = normalize_capability(capability)

    if not M.buffer_has_capability(buffer, capability) then
        return
    end

    local auto_group_name = "pavkam_cap_" .. utils.tbl_join(event, "_") .. "_" .. capability

    local group = vim.api.nvim_create_augroup(auto_group_name, { clear = true })
    vim.api.nvim_create_autocmd(event, {
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

    local filetype = vim.api.nvim_get_option_value("filetype", { buf = buffer })
    local buf_client_names = {}

    for _, client in pairs(vim.lsp.get_active_clients { bufnr = buffer }) do
        if client.name == "null-ls" then
            utils.list_insert_unique(buf_client_names, get_null_ls_sources(filetype))
        elseif client.name ~= "copilot" then
            utils.list_insert_unique(buf_client_names, client.name)
        end
    end

    return buf_client_names
end

function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return #vim.lsp.get_active_clients({ bufnr = buffer }) > 0
end

function M.get_all_clients(...)
    local fn = vim.lsp.get_clients or vim.lsp.get_active_clients
    return fn(...)
end

function M.get_lsp_root_dir(path, buffer)
  path = path or vim.api.nvim_buf_get_name(0)
  path = path ~= "" and vim.loop.fs_realpath(path) or nil

  local roots = {}

  if path then
    for _, client in pairs(M.get_all_clients({ bufnr = buffer })) do
        local workspace = client.config.workspace_folders
        local paths = workspace and vim.tbl_map(function(ws)
            return vim.uri_to_fname(ws.uri)
        end, workspace) or client.config.root_dir and { client.config.root_dir } or {}

        for _, p in ipairs(paths) do
            local r = vim.loop.fs_realpath(p)
            if path:find(r, 1, true) then
            roots[#roots + 1] = r
            end
        end
    end
  end

  table.sort(roots, function(a, b) return #a > #b end)

  return roots[1]
end

return M
