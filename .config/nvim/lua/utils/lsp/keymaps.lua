local lsp = require "utils.lsp"
local utils = require "utils"

local M = {}



local function better_rename()
    local position_params = vim.lsp.util.make_position_params()
    position_params.oldName = vim.fn.expand("<cword>")

    vim.ui.input({prompt = "Rename To", default = position_params.oldName}, function(input)
        if input == nil then
            utils.warn('Rename aborted.')

            return
        end

        position_params.newName = input
        vim.lsp.buf_request(0, "textDocument/rename", position_params, function(err, result, ...)
            if not result or not result.changes then
                notify.error(string.format("Failed to rename *%s* to *%s*", position_params.oldName, position_params.newName))
                return
            end

            vim.lsp.handlers["textDocument/rename"](err, result, ...)

            local notification, entries = 'Following changes have been made:', {}
            local num_files, num_updates = 0, 0
            for uri, edits in pairs(result.changes) do
                num_files = num_files + 1
                local bufnr = vim.uri_to_bufnr(uri)

                for _, edit in ipairs(edits) do
                    local start_line = edit.range.start.line + 1
                    local line = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, false)[1]

                    num_updates = num_updates + 1
                    table.insert(entries, {
                        bufnr = bufnr,
                        lnum = start_line,
                        col = edit.range.start.character + 1,
                        text = line
                    })
                end

                local short_uri = string.sub(vim.uri_to_fname(uri), #vim.fn.getcwd() + 2)

                -- extend notification
                if #notification > 0 then
                    notification = notification .. '\n'
                end
                notification = notification .. string.format('- **%d** in *%s*', #edits, short_uri)
            end

            utils.info(notification)
            if num_files > 1 then
                vim.fn.setqflist(entries, "a")
                vim.cmd("copen")
            end
        end)
    end)
end

local keymaps = {
    { "M", vim.diagnostic.open_float, desc = "Line diagnostics" },
    { "<leader>sm", "M", remap = true, desc = "Line diagnostics (M)" },
    {
        "gd",
        function()
            if lsp.is_active_for_buffer(nil, "omnisharp") then
                require("omnisharp_extended").telescope_lsp_definitions()
            else
                require("telescope.builtin").lsp_definitions({ reuse_win = true })
            end
        end,
        desc = "Goto definition",
        capability = "definition"
    },
    { "<leader>sd", "gd", desc = "Goto definition (gd)", remap = true, capability = "definition" },

    { "gr", "<cmd>Telescope lsp_references<cr>", desc = "Show references", capability = "references" },
    { "<leader>sr", "<cmd>Telescope lsp_references<cr>", remap = true, desc = "References (gr)", capability = "references" },

    { "gD", vim.lsp.buf.declaration, desc = "Goto declaration", capability = "declaration" },
    { "<leader>sD", "gD", desc = "Goto declaration (gD)", remap = true, capability = "declaration" },

    { "gI", function() require("telescope.builtin").lsp_implementations({ reuse_win = true }) end, desc = "Goto Implementation", capability = "implementation" },
    { "<leader>si", "gI", desc = "Goto implementation (gI)", remap = true, capability = "implementation"},

    { "gy", function() require("telescope.builtin").lsp_type_definitions({ reuse_win = true }) end, desc = "Goto Type Definition", capability = "typeDefinition" },
    { "<leader>st", "gy", desc = "Goto type definition (gy)", remap = true, capability = "typeDefinition" },

    { "K", vim.lsp.buf.hover, desc = "Hover" },
    { "<leader>sk", "K", desc = "Hover (K)", remap = true },

    { "gK", vim.lsp.buf.signature_help, desc = "Signature Help", capability = "signatureHelp" },
    { "<leader>sh", "gK", desc = "Signature Help (gK)", remap = true, capability = "signatureHelp" },

    { "<leader>sL", function() vim.lsp.codelens.refresh() end, desc = "Refresh CodeLens", capability = "codeLens" },
    { "<leader>sl", function() vim.lsp.codelens.run() end, desc = "Run CodeLens", capability = "codeLens" },

    { "<leader>ss", vim.lsp.buf.code_action, desc = "Code Actions", mode = { "n", "v" }, capability = "codeAction" },
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
        better_rename,
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
            vim.keymap.set(mapping.mode or "n", mapping.lhs, mapping.rhs, {
                desc = mapping.desc,
                buffer = buffer,
                silent = mapping.silent,
                remap = mapping.remap,
                expr = mapping.expr
            })
        end
    end
end

function M.attach(client, buffer)
    attach_keymaps(client, buffer)

    if lsp.client_has_capability(client, "codeLens") then
        vim.lsp.codelens.refresh()
    end

    lsp.on_capability_event(
        { "InsertLeave", "BufEnter" },
        "codeLens",
        buffer,
        function()
-- Error executing vim.schedule lua callback: ...neovim/0.9.1/share/nvim/runtime/lua/vim/lsp/codelens.lua:228: Invalid 'line': out of range
-- stack traceback:
-- 	[C]: in function 'nvim_buf_set_extmark'
-- 	...neovim/0.9.1/share/nvim/runtime/lua/vim/lsp/codelens.lua:228: in function 'handler'
-- 	...w/Cellar/neovim/0.9.1/share/nvim/runtime/lua/vim/lsp.lua:1394: in function ''
-- 	vim/_editor.lua: in function <vim/_editor.lua:0>
           -- vim.lsp.codelens.refresh()
        end
    )

    lsp.on_capability_event(
         { "CursorHold", "CursorHoldI" },
        "documentHighlight",
        buffer,
        function()
            vim.lsp.buf.document_highlight()
        end
    )

    lsp.on_capability_event(
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
