local icons = require 'utils.icons'

M = {}

---@param from string
---@param to string
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

---@param on_attach fun(client, buffer)
function M.on_attach(on_attach)
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local buffer = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      on_attach(client, buffer)
    end,
  })
end

local function null_ls_providers(filetype)
    local registered = {}

    local sources_avail, sources = pcall(require, "null-ls.sources")
    if sources_avail then
        for _, source in ipairs(sources.get_available(filetype)) do
            for method in pairs(source.methods) do
                registered[method] = registered[method] or {}
                table.insert(registered[method], source.name)
            end
        end
    end

    return registered
end

local function null_ls_sources(filetype, method)
    local methods_avail, methods = pcall(require, "null-ls.methods")
    return methods_avail and null_ls_providers(filetype)[methods.internal[method]] or {}
end

function M.client_names(buffer)
    local buf_client_names = {}

    for _, client in pairs(vim.lsp.get_active_clients { bufnr = buffer }) do
        if client.name == "null-ls" then
            local nl_sources = {}

            for _, type in ipairs { "FORMATTING", "DIAGNOSTICS" } do
                for _, source in ipairs(null_ls_sources(vim.bo.filetype, type)) do
                    nl_sources[source] = true
                end
            end

            vim.list_extend(buf_client_names, vim.tbl_keys(nl_sources))
        else
            table.insert(buf_client_names, client.name)
        end
    end

    local str = table.concat(buf_client_names, ", ")

    local width = vim.o.laststatus == 3 and vim.o.columns or vim.api.nvim_win_get_width(0)
    local max_width = math.floor(width * 0.25)
    if #str > max_width then str = string.sub(str, 0, max_width) .. icons.ellipsis end

    return str
end

return M
