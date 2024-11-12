return {
    {
        'hrsh7th/nvim-cmp',
        cond = not vim.headless,
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
                opts = {
                    symbol_map = require('icons').Symbols,
                },
            },
        },
        opts = function()
            local cmp = require 'cmp'
            local compare = require 'cmp.config.compare'
            local copilot = vim.has_plugin 'copilot.lua' and require 'copilot.suggestion' or nil
            local settings = require 'settings'
            local luasnip = require 'luasnip'
            local lspkind = require 'lspkind'
            local syntax = require 'syntax'

            local border_opts = {
                border = vim.g.border_style,
                winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None',
            }

            local get_menu_height = settings.transient(function()
                local height = vim.api.nvim_get_option_value('pumheight', {})
                local total_item_count = #cmp.get_entries()

                height = height ~= 0 and height or total_item_count
                height = math.min(height, total_item_count)

                return height
            end)

            ---@param opts {select: boolean, behavior: cmp.ConfirmBehavior}|nil
            local function confirm(opts)
                opts = vim.tbl_extend('force', {
                    select = true,
                    behavior = cmp.ConfirmBehavior.Insert,
                }, opts or {})

                return function(fallback)
                    if cmp.core.view:visible() or vim.fn.pumvisible() == 1 then
                        vim.fn.create_undo_point()
                        if cmp.confirm(opts) then
                            return
                        end
                    end
                    return fallback()
                end
            end

            ---@type cmp.ConfigSchema
            return {
                enabled = function()
                    local dap_prompt = vim.tbl_contains(
                        { 'dap-repl', 'dapui_watches', 'dapui_hover' },
                        vim.api.nvim_get_option_value('filetype', { buf = 0 })
                    )

                    if vim.api.nvim_get_option_value('buftype', { buf = 0 }) == 'prompt' and not dap_prompt then
                        return false
                    end

                    return syntax.node_category() ~= 'comment'
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
                    ['<C-n>'] = cmp.mapping(function(fallback)
                        if copilot and copilot.is_visible() then
                            copilot.next()
                        elseif cmp.visible() then
                            cmp.select_next_item { behavior = cmp.SelectBehavior.Insert }
                        else
                            fallback()
                        end
                    end),
                    ['<C-p>'] = cmp.mapping(function(fallback)
                        if copilot and copilot.is_visible() then
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
                    ['<CR>'] = confirm { select = true },
                    ['<S-CR>'] = confirm {
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    },
                    ['<Tab>'] = cmp.mapping(function(fallback)
                        if copilot and copilot.is_visible() then
                            copilot.accept()
                        elseif cmp.visible() then
                            local entry = cmp.get_selected_entry()
                            if not entry then
                                cmp.select_next_item { behavior = cmp.SelectBehavior.Select }
                            else
                                confirm()
                            end
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                    ['<S-Tab>'] = cmp.mapping(function(fallback)
                        if copilot and copilot.is_visible() then
                            copilot.next()
                        elseif cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                },
                sources = cmp.config.sources {
                    vim.has_plugin 'lazydev.nvim' and { name = 'lazydev', priority = 10 } or nil,
                    {
                        name = 'nvim_lsp',
                        ---@param entry cmp.Entry
                        entry_filter = function(entry, _)
                            if entry.source.source.client.name == 'emmet_ls' then
                                return syntax.node_category() == 'jsx'
                            end

                            return true
                        end,
                        priority = 9,
                    },
                    {
                        name = 'buffer',
                        option = {
                            get_bufnrs = vim.buf.get_listed_buffers,
                            max_indexed_line_length = 100,
                        },
                        keyword_length = 3,
                        max_item_count = 4,
                        priority = 4,
                    },
                    { name = 'luasnip', priority = 3 },
                    { name = 'path', priority = 1 },
                },
                sorting = {
                    priority_weight = 5,
                    comparators = {
                        compare.offset,
                        compare.exact,
                        compare.score,
                        compare.recently_used,
                        compare.locality,
                        compare.kind,
                        compare.order,
                    },
                },
                formatting = {
                    expandable_indicator = true,
                    fields = { 'kind', 'menu', 'abbr' },
                    format = function(entry, vim_item)
                        vim_item.kind = lspkind.symbolic(vim_item.kind)
                        vim_item.abbr = vim.abbreviate(vim_item.abbr)

                        if entry.source.source and entry.source.source.client and entry.source.source.client.name then
                            -- TODO: replace the full names with their type icons (vstls, emmet, etc.)
                            vim_item.menu = vim.abbreviate(entry.source.source.client.name)
                            vim_item.menu_hl_group = 'CmpItemKindKey'
                        else
                            vim_item.menu = vim.abbreviate(entry.source.name)
                            if entry.source.name ~= 'luasnip' then
                                vim_item.menu_hl_group = 'CmpItemKindPackage'
                            else
                                vim_item.menu_hl_group = 'CmpItemKindSnippet'
                            end
                        end

                        return vim_item
                    end,
                },
            }
        end,
        config = function(_, opts)
            local cmp = require 'cmp'

            cmp.setup(opts)

            if not vim.has_plugin 'cmp-dap' then
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
        build = vim.fn.has 'win32' == 0
                and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build\n'; make install_jsregexp"
            or nil,
        dependencies = {
            'rafamadriz/friendly-snippets',
        },
        opts = {
            history = false,
            update_events = 'TextChanged,TextChangedI',
            delete_check_events = 'InsertLeave',
            region_check_events = 'CursorMoved',
        },
        config = function(_, opts)
            require('luasnip').config.setup(opts)
            vim.iter({ 'vscode', 'snipmate', 'lua' }):each(function(type)
                require('luasnip.loaders.from_' .. type).lazy_load()
            end)
        end,
    },
}
