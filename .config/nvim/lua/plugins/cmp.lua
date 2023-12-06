return {
    {
        'hrsh7th/nvim-cmp',
        enabled = feature_level(2),
        version = false,
        event = 'InsertEnter',
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            {
                'saadparwaiz1/cmp_luasnip',
                dependencies = {
                    'L3MON4D3/LuaSnip',
                },
            },
            {
                'onsails/lspkind.nvim',
            },
        },
        opts = function()
            vim.api.nvim_set_hl(0, 'CmpGhostText', { link = 'Comment', default = true })

            local cmp = require 'cmp'
            local icons = require 'utils.icons'
            local defaults = require 'cmp.config.default'()
            local luasnip = require 'luasnip'
            local copilot = require 'copilot.suggestion'
            local settings = require 'utils.settings'

            local border_opts = {
                border = 'rounded',
                winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None',
            }

            local get_menu_height = settings.transient(function()
                local height = vim.api.nvim_get_option 'pumheight'
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
                    luasnip = 1,
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

                    ['<C-n>'] = cmp.mapping.select_next_item { behavior = cmp.SelectBehavior.Insert },
                    ['<C-p>'] = cmp.mapping.select_prev_item { behavior = cmp.SelectBehavior.Insert },
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<C-a>'] = cmp.mapping.complete(),
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
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                    ['<S-Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                    ['<C-.>'] = cmp.mapping(function(fallback)
                        if copilot.is_visible() then
                            copilot.next()
                        else
                            fallback()
                        end
                    end),
                    ['<C-,>'] = cmp.mapping(function(fallback)
                        if copilot.is_visible() then
                            copilot.prev()
                        else
                            fallback()
                        end
                    end),
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
            local utils = require 'utils'

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
    {
        'L3MON4D3/LuaSnip',
        enabled = feature_level(2),
        build = vim.fn.has 'win32' == 0 and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build\n'; make install_jsregexp" or nil,
        dependencies = {
            'rafamadriz/friendly-snippets',
        },
        opts = {
            history = true,
            delete_check_events = 'TextChanged',
            region_check_events = 'CursorMoved',
        },
        config = function(_, opts)
            require('luasnip').config.setup(opts)
            vim.tbl_map(function(type)
                require('luasnip.loaders.from_' .. type).lazy_load()
            end, { 'vscode', 'snipmate', 'lua' })
        end,
    },
}
