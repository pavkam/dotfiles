local function diagnostic_goto(next, severity)
    local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
    severity = severity and vim.diagnostic.severity[severity] or nil
    return function()
        go({ severity = severity })
    end
end

return {
      { "M", vim.diagnostic.open_float, desc = "Line Diagnostics" },
      { "<leader>sm", "M", desc = "Line Diagnostics (M)" },

      { "gd", function() require("telescope.builtin").lsp_definitions({ reuse_win = true }) end, desc = "Goto Definition", has = "definition" },
      { "<leader>sd", "gd", desc = "Goto Definition (gd)", has = "definition" },

      { "gr", "<cmd>Telescope lsp_references<cr>", desc = "References" },
      { "<leader>sr", "<cmd>Telescope lsp_references<cr>", desc = "References (gr)" },

      { "gD", vim.lsp.buf.declaration, desc = "Goto Declaration" },
      { "<leader>sD", "gD", desc = "Goto Declaration (gD)" },

      { "gI", function() require("telescope.builtin").lsp_implementations({ reuse_win = true }) end, desc = "Goto Implementation" },
      { "<leader>si", "gI", desc = "Goto Implementation (gI)" },

      { "gy", function() require("telescope.builtin").lsp_type_definitions({ reuse_win = true }) end, desc = "Goto Type Definition" },
      { "<leader>st", "gy", desc = "Goto Type Definition (gy)" },

      { "K", vim.lsp.buf.hover, desc = "Hover" },
      { "<leader>sk", "K", desc = "Hover (K)" },

      { "gK", vim.lsp.buf.signature_help, desc = "Signature Help", has = "signatureHelp" },
      { "<leader>sh", "gK", desc = "Signature Help (gK)", has = "signatureHelp" },

      { "]m", diagnostic_goto(true), desc = "Next Diagnostic" },
      { "[m", diagnostic_goto(false), desc = "Prev Diagnostic" },
      { "]e", diagnostic_goto(true, "ERROR"), desc = "Next Error" },
      { "[e", diagnostic_goto(false, "ERROR"), desc = "Prev Error" },
      { "]w", diagnostic_goto(true, "WARN"), desc = "Next Warning" },
      { "[w", diagnostic_goto(false, "WARN"), desc = "Prev Warning" },
      { "<leader>ss", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeAction" },
      {
        "<leader>sS",
        function()
          vim.lsp.buf.code_action({
            context = {
              only = {
                "source",
              },
              diagnostics = {},
            },
          })
        end,
        desc = "Source Action",
        has = "codeAction",
    },
    {
        "<leader>sR",
        function()
            local inc_rename = require("inc_rename")
            return ":" .. inc_rename.config.cmd_name .. " " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "Rename",
        has = "rename",
    }
}
