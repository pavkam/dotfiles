return {
    {
        'hrsh7th/nvim-cmp',
        event = 'InsertEnter',
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            {
                'onsails/lspkind.nvim',
            },
        },
        opts = function()
            vim.api.nvim_set_hl(0, 'CmpGhostText', { link = 'Comment', default = true })

            local cmp = require 'cmp'
            local icons = require 'ui.icons'
            local defaults = require 'cmp.config.default'()
            local copilot = require 'copilot.suggestion'
            local settings = require 'core.settings'

            local border_opts = {
                border = 'rounded',
                winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None',
            }

            local get_menu_height = settings.transient(function()
                local height = vim.api.nvim_get_option_value('pumheight', {})
                local total_item_count = #cmp.get_entries()

                height = height ~= 0 and height or total_item_count
                height = math.min(height, total_item_count)

                return height
            end)

            return {
                enabled = function()
                    local dap_prompt = vim.tbl_contains({ 'dap-repl', 'dapui_watches', 'dapui_hover' }, vim.api.nvim_get_option_value('filetype', { buf = 0 }))

                    if vim.api.nvim_get_option_value('buftype', { buf = 0 }) == 'prompt' and not dap_prompt then
                        return false
                    end

                    local context = require 'cmp.config.context'

                    return not context.in_treesitter_capture 'comment' and not context.in_syntax_group 'Comment'
                end,
                completion = {
                    completeopt = 'menu,menuone,noinsert',
                },
                window = {
                    completion = cmp.config.window.bordered(border_opts),
                    documentation = cmp.config.window.bordered(border_opts),
                },
                duplicates = {
                    nvim_lsp = 1,
                    buffer = 1,
                    path = 1,
                },
                confirm_opts = {
                    behavior = cmp.ConfirmBehavior.Replace,
                    select = false,
                },
                snippet = {
                    expand = function(args)
                        vim.snippet.expand(args.body)
                    end,
                },
                view = {
                    entries = 'custom',
                },
                mapping = cmp.mapping.preset.insert {
                    ['<Up>'] = cmp.mapping.select_prev_item { behavior = cmp.SelectBehavior.Select },
                    ['<Down>'] = cmp.mapping.select_next_item { behavior = cmp.SelectBehavior.Select },
                    ['<PageUp>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item { count = get_menu_height(), behavior = cmp.SelectBehavior.Select }
                        else
                            fallback()
                        end
                    end),
                    ['<PageDown>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item { count = get_menu_height(), behavior = cmp.SelectBehavior.Select }
                        else
                            fallback()
                        end
                    end),
                    ['<C-n>'] = cmp.mapping(function(fallback)
                        if copilot.is_visible() then
                            copilot.next()
                        elseif cmp.visible() then
                            cmp.select_next_item { behavior = cmp.SelectBehavior.Insert }
                        else
                            fallback()
                        end
                    end),
                    ['<C-p>'] = cmp.mapping(function(fallback)
                        if copilot.is_visible() then
                            copilot.prev()
                        elseif cmp.visible() then
                            cmp.select_prev_item { behavior = cmp.SelectBehavior.Insert }
                        else
                            fallback()
                        end
                    end),
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<M-CR>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping.abort(),
                    ['<CR>'] = cmp.mapping.confirm { select = true },
                    ['<S-CR>'] = cmp.mapping.confirm {
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    },
                    ['<Tab>'] = cmp.mapping(function(fallback)
                        if copilot.is_visible() then
                            copilot.accept()
                        elseif cmp.visible() then
                            local entry = cmp.get_selected_entry()
                            if not entry then
                                cmp.select_next_item { behavior = cmp.SelectBehavior.Select }
                            else
                                cmp.confirm()
                            end
                        elseif vim.snippet.active { direction = 1 } then
                            vim.schedule(function()
                                vim.snippet.jump(1)
                            end)
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                    ['<S-Tab>'] = cmp.mapping(function(fallback)
                        if copilot.is_visible() then
                            copilot.next()
                        elseif cmp.visible() then
                            cmp.select_prev_item()
                        elseif vim.snippet.active { direction = -1 } then
                            vim.schedule(function()
                                vim.snippet.jump(-1)
                            end)
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                },
                sources = cmp.config.sources {
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                    { name = 'buffer' },
                    { name = 'path' },
                },
                formatting = {
                    fields = { 'kind', 'abbr', 'menu' },
                    format = require('lspkind').cmp_format {
                        mode = 'symbol',
                        symbol_map = icons.Symbols,
                        menu = {},
                        maxwidth = 50,
                        ellipsis_char = icons.TUI.Ellipsis,
                    },
                },
                experimental = {
                    ghost_text = {
                        hl_group = 'CmpGhostText',
                    },
                },
                sorting = defaults.sorting,
            }
        end,
        config = function(_, opts)
            local cmp = require 'cmp'
            local utils = require 'core.utils'

            cmp.setup(opts)

            if not utils.has_plugin 'cmp-dap' then
                ---@diagnostic disable-next-line: missing-fields
                cmp.setup.filetype({ 'dap-repl', 'dapui_watches', 'dapui_hover' }, {
                    sources = {
                        { name = 'dap' },
                    },
                })
            end
        end,
    },
}
