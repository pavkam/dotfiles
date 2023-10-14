local lsp = require "utils.lsp"

local M = {}

local function jump_to_diagnostic(next_or_prev, severity)
    local go = next_or_prev and vim.diagnostic.goto_next or vim.diagnostic.goto_prev

    severity = severity and vim.diagnostic.severity[severity] or nil

    return function()
        go({ severity = severity })
    end
end

local keymaps = {
    { "M", vim.diagnostic.open_float, desc = "Line Diagnostics" },
    { "<leader>sm", "M", desc = "Line Diagnostics (M)" },

    { "gd", function() require("telescope.builtin").lsp_definitions({ reuse_win = true }) end, desc = "Goto Definition", capability = "definition" },
    { "<leader>sd", "gd", desc = "Goto Definition (gd)", capability = "definition" },

    { "gr", "<cmd>Telescope lsp_references<cr>", desc = "References", capability = "references" },
    { "<leader>sr", "<cmd>Telescope lsp_references<cr>", desc = "References (gr)", capability = "references" },

    { "gD", vim.lsp.buf.declaration, desc = "Goto Declaration", capability = "declaration" },
    { "<leader>sD", "gD", desc = "Goto Declaration (gD)", capability = "declaration" },

    { "gI", function() require("telescope.builtin").lsp_implementations({ reuse_win = true }) end, desc = "Goto Implementation", capability = "implementation" },
    { "<leader>si", "gI", desc = "Goto Implementation (gI)", capability = "implementation"},

    { "gy", function() require("telescope.builtin").lsp_type_definitions({ reuse_win = true }) end, desc = "Goto Type Definition", capability = "typeDefinition" },
    { "<leader>st", "gy", desc = "Goto Type Definition (gy)", capability = "typeDefinition" },

    { "K", vim.lsp.buf.hover, desc = "Hover" },
    { "<leader>sk", "K", desc = "Hover (K)" },

    { "gK", vim.lsp.buf.signature_help, desc = "Signature Help", capability = "signatureHelp" },
    { "<leader>sh", "gK", desc = "Signature Help (gK)", capability = "signatureHelp" },

    { "<leader>sL", function() vim.lsp.codelens.refresh() end, desc = "Refresh CodeLens", capability = "codeLens" },
    { "<leader>sl", function() vim.lsp.codelens.run() end, desc = "Run CodeLens", capability = "codeLens" },

    { "]m", jump_to_diagnostic(true), desc = "Next Diagnostic" },
    { "[m", jump_to_diagnostic(false), desc = "Prev Diagnostic" },
    { "]e", jump_to_diagnostic(true, "ERROR"), desc = "Next Error" },
    { "[e", jump_to_diagnostic(false, "ERROR"), desc = "Prev Error" },
    { "]w", jump_to_diagnostic(true, "WARN"), desc = "Next Warning" },
    { "[w", jump_to_diagnostic(false, "WARN"), desc = "Prev Warning" },

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

    for _, mapping in pairs(resolved_keymaps) do
        if not mapping.capability or lsp.client_has_capability(client, mapping.capability) then
            vim.keymap.set(mapping.mode or "n", mapping.lhs, mapping.rhs, { desc = mapping.desc, buffer = buffer, silent = mapping.silent })
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

function M.attach(client, buffer)
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

    if lsp.client_has_capability(client, "inlayHint") then
        if vim.lsp.buf.inlay_hint or vim.lsp.inlay_hint then
            inlay_hint(buffer, true)
        else
            file_type = vim.api.nvim_buf_get_option(buffer, "filetype")

            -- go has support for inlay hints through `ray-x/go.nvim` plugin
            if file_type ~= "go" then
                require("lsp-inlayhints").on_attach(client, buffer)
            end
        end
    end
end

return M
