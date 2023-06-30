local null_ls = require("null-ls")
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

local opts = {
  sources = {
    -- go
    null_ls.builtins.formatting.gofmt,
    null_ls.builtins.formatting.goimports_reviser,
    null_ls.builtins.formatting.golines,
    null_ls.builtins.diagnostics.golangci_lint,
    null_ls.builtins.diagnostics.staticcheck,
    null_ls.builtins.code_actions.gomodifytags,
    null_ls.builtins.code_actions.impl,

    -- shell
    null_ls.builtins.formatting.shfmt,
    null_ls.builtins.diagnostics.shellcheck,
    null_ls.builtins.code_actions.shellcheck,

    -- js/ts
    null_ls.builtins.diagnostics.eslint,

    -- general
    null_ls.builtins.formatting.prettier,
    null_ls.builtins.code_actions.gitsigns,
  },
  on_attach = function (client, bufnr)
    if client.supports_method("textDocument/formatting") then
      vim.api.nvim_clear_autocmds({
        group = augroup,
        buffer = bufnr,
      })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr })
        end,
      })
    end
  end,
}

return opts
