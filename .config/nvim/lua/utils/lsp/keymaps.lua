local lsp = require "utils.lsp"
local diagnostics = require "utils.diagnostics"

local M = {}

local keymaps = {
    { "M", vim.diagnostic.open_float, desc = "Line Diagnostics" },
    { "<leader>sm", "M", desc = "Line Diagnostics (M)" },

    { "gd", function() require("telescope.builtin").lsp_definitions({ reuse_win = true }) end, desc = "Goto Definition", capability = "definition" },
    { "<leader>sd", "gd", desc = "Goto Definition (gd)", capability = "definition" },

    { "gr", "<cmd>Telescope lsp_references<cr>", desc = "References" },
    { "<leader>sr", "<cmd>Telescope lsp_references<cr>", desc = "References (gr)" },

    { "gD", vim.lsp.buf.declaration, desc = "Goto Declaration", capability = "declaration" },
    { "<leader>sD", "gD", desc = "Goto Declaration (gD)", capability = "declaration" },

    { "gI", function() require("telescope.builtin").lsp_implementations({ reuse_win = true }) end, desc = "Goto Implementation" },
    { "<leader>si", "gI", desc = "Goto Implementation (gI)" },

    { "gy", function() require("telescope.builtin").lsp_type_definitions({ reuse_win = true }) end, desc = "Goto Type Definition" },
    { "<leader>st", "gy", desc = "Goto Type Definition (gy)" },

    { "K", vim.lsp.buf.hover, desc = "Hover" },
    { "<leader>sk", "K", desc = "Hover (K)" },

    { "gK", vim.lsp.buf.signature_help, desc = "Signature Help", capability = "signatureHelp" },
    { "<leader>sh", "gK", desc = "Signature Help (gK)", capability = "signatureHelp" },

    { "<leader>sF", function() vim.lsp.buf.format() end, desc = "Format Buffer", capability = "formatting" },

    { "<leader>sL", function() vim.lsp.codelens.refresh() end, desc = "Refresh CodeLens", capability = "codeLens" },
    { "<leader>sl", function() vim.lsp.codelens.run() end, desc = "Run CodeLens", capability = "codeLens" },

    { "]m", diagnostics.jump_to_diagnostic(true), desc = "Next Diagnostic" },
    { "[m", diagnostics.jump_to_diagnostic(false), desc = "Prev Diagnostic" },
    { "]e", diagnostics.jump_to_diagnostic(true, "ERROR"), desc = "Next Error" },
    { "[e", diagnostics.jump_to_diagnostic(false, "ERROR"), desc = "Prev Error" },
    { "]w", diagnostics.jump_to_diagnostic(true, "WARN"), desc = "Next Warning" },
    { "[w", diagnostics.jump_to_diagnostic(false, "WARN"), desc = "Prev Warning" },

    { "<leader>ss", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, capability = "codeAction" },
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
        capability = "codeAction",
    },
    {
        "<leader>sR",
        function()
            local inc_rename = require("inc_rename")
            return ":" .. inc_rename.config.cmd_name .. " " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "Rename",
        capability = "rename",
    }
}

function attach_keymaps(client, buffer)
    local Keys = require("lazy.core.handler.keys")
    local resolved_keymaps = {}

    for _, keymap in ipairs(keymaps) do
        local parsed = Keys.parse(keymap)
        resolved_keymaps[parsed.id] = parsed
    end

    for _, keys in pairs(resolved_keymaps) do
        if not keys.capability or lsp.client_has_capability(client, keys.capability) then
            local opts = Keys.opts(keys)

            opts.capability = nil
            opts.silent = opts.silent ~= false
            opts.buffer = buffer

            vim.keymap.set(keys.mode or "n", keys[1], keys[2], opts)
        end
    end
end

function attach_commands(client, buffer)
    if lsp.client_has_capability(client, "formatting") then
        vim.api.nvim_buf_create_user_command(
            buffer,
            "Format",
            function()
                vim.lsp.buf.format()
            end,
            { desc = "Format Buffer" }
        )
    end
end

function attach(client, buffer)
    attach_keymaps(client, buffer)
    attach_commands(client, buffer)

    if lsp.client_has_capability(client, "codeLens") then
        vim.lsp.codelens.refresh()
    end

    lsp.auto_command_on_capability(
        { "InsertLeave", "BufEnter" },
        "codeLens",
        buffer,
        function()
            vim.lsp.codelens.refresh()
        end
    )

    lsp.auto_command_on_capability(
        "BufWritePre",
        "formatting",
        buffer,
        function()
            vim.lsp.buf.format()
        end
    )

    lsp.auto_command_on_capability(
         { "CursorHold", "CursorHoldI" },
        "documentHighlight",
        buffer,
        function()
            vim.lsp.buf.document_highlight()
        end
    )

    lsp.auto_command_on_capability(
        { "CursorMoved", "CursorMovedI", "BufLeave" },
        "documentHighlight",
        buffer,
        function()
            vim.lsp.buf.clear_references()
        end
    )
end

function M.on_attach(client, buffer)
    lsp.on_attach(function(client, buffer)
        attach(client, buffer)
    end)

    local register_capability = vim.lsp.handlers["client/registerCapability"]

    vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
        local ret = register_capability(err, res, ctx)
        local client = vim.lsp.get_client_by_id(ctx.client_id)

        if client.supports_method ~= nil then
            attach(client, vim.api.nvim_get_current_buf())
        end

        return ret
    end
end

return M
