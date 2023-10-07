return {
    {
        "hrsh7th/nvim-cmp",
        version = false,
        event = "InsertEnter",
        dependencies = {
            "rcarriga/cmp-dap",
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            {
                "saadparwaiz1/cmp_luasnip",
                dependencies = {
                    "L3MON4D3/LuaSnip"
                }
            },
        },
        opts = function()
            vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })

            local icons = require "utils.icons"
            local cmp = require "cmp"
            local defaults = require("cmp.config.default")()
            local luasnip = require "luasnip"
            local copilot = require "copilot.suggestion"

            local function has_words_before()
                local line, col = (unpack or table.unpack)(vim.api.nvim_win_get_cursor(0))
                return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match "%s" == nil
            end

            local border_opts = {
                border = "rounded",
                winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
            }

            return {
                enabled = function()
                    local dap_prompt = vim.tbl_contains(
                        { "dap-repl", "dapui_watches", "dapui_hover" },
                        vim.api.nvim_get_option_value("filetype", { buf = 0 })
                    )

                    if vim.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt" and not dap_prompt then
                        return false
                    end

                    return true
                end,
                completion = {
                    completeopt = "menu,menuone,noinsert",
                },
                window = {
                    completion = cmp.config.window.bordered(border_opts),
                    documentation = cmp.config.window.bordered(border_opts),
                },
                duplicates = {
                    nvim_lsp = 1,
                    luasnip = 1,
                    cmp_tabnine = 1,
                    buffer = 1,
                    path = 1,
                },
                confirm_opts = {
                    behavior = cmp.ConfirmBehavior.Replace,
                    select = false,
                },
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<Up>"] = cmp.mapping.select_prev_item { behavior = cmp.SelectBehavior.Select },
                    ["<Down>"] = cmp.mapping.select_next_item { behavior = cmp.SelectBehavior.Select },
                    ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
                    ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
                    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"] = cmp.mapping.scroll_docs(4),
                    ["<C-a>"] = cmp.mapping.complete(),
                    ["<C-e>"] = cmp.mapping.abort(),
                    ["<CR>"] = cmp.mapping.confirm({ select = true }),
                    ["<S-CR>"] = cmp.mapping.confirm({
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    }),
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if copilot.is_visible() then
                            copilot.accept()
                        elseif cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        elseif has_words_before() then
                            cmp.complete()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                        fallback()
                        end
                    end, { "i", "s" }),
                    ["<C-.>"] = cmp.mapping(function()
                        if copilot.is_visible() then copilot.next() end
                    end),
                    ["<C-,>"] = cmp.mapping(function()
                        if copilot.is_visible() then copilot.prev() end
                    end)
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = "buffer" },
                    { name = "path" },
                }),
                formatting = {
                    format = function(_, item)
                        if icons.cmp_categories[item.kind] then
                            item.kind = icons.cmp_categories[item.kind] .. item.kind
                        end
                        return item
                    end,
                },
                experimental = {
                    ghost_text = {
                        hl_group = "CmpGhostText",
                    },
                },
                sorting = defaults.sorting,
            }
        end,
        config = function(_, opts)
            local cmp = require "cmp"

            cmp.setup(opts)
            cmp.setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
                sources = {
                    { name = "dap" },
                },
            })
        end,
    },
    {
        "L3MON4D3/LuaSnip",
        build = vim.fn.has "win32" == 0
            and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build\n'; make install_jsregexp"
        or nil,
        dependencies = {
            "rafamadriz/friendly-snippets"
        },
        opts = {
            history = true,
            delete_check_events = "TextChanged",
            region_check_events = "CursorMoved",
        },
        config = function(_, opts)
            require("luasnip").config.setup(opts)
            vim.tbl_map(function(type) require("luasnip.loaders.from_" .. type).lazy_load() end, { "vscode", "snipmate", "lua" })
        end
    },
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        build = ":Copilot auth",
        opts = {
            suggestion = {
                enabled = true,
                auto_trigger = true,
                debounce = 150
            },
            panel = { enabled = false },
        },
        config = function(plugin, opts)
            -- create new hl group for copilot annotations
            local comment_hl = vim.api.nvim_get_hl_by_name('Comment', true)
            local new_hl = vim.tbl_extend('force', {}, comment_hl, { fg = '#7287fd' })
            vim.api.nvim_set_hl(0, 'CopilotAnnotation', new_hl)
            vim.api.nvim_set_hl(0, 'CopilotSuggestion', new_hl)

            require("copilot").setup(opts)
        end
    }
}
