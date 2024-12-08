return {
    'folke/noice.nvim',
    cond = not ide.process.is_headless,
    lazy = false,
    dependencies = {
        'MunifTanjim/nui.nvim',
        'rcarriga/nvim-notify',
    },
    opts = {
        lsp = {
            override = {
                ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
                ['vim.lsp.util.stylize_markdown'] = true,
                ['cmp.entry.get_documentation'] = true,
            },
        },
        routes = {
            {
                filter = {
                    event = 'msg_show',
                    any = {
                        { find = '%d+L, %d+B' },
                        { find = '; after #%d+' },
                        { find = '; before #%d+' },
                        { find = '%d+ fewer lines' },
                        { find = '%d+ lines changed' },
                        { find = '%d+ more lines' },
                        { find = '%d+ lines yanked' },
                        { find = 'search hit %a+, continuing at %a+' },
                        { find = '%d+ lines <ed %d+ time' },
                        { find = '%d+ lines >ed %d+ time' },
                        { find = '%d+ substitutions on %d+ lines' },
                        { find = 'Hunk %d+ of %d+' },
                        { find = '%-%-No lines in buffer%-%-' },
                        { find = '^E486: Pattern not found' },
                        { find = '^Word .*%.add$' },
                        { find = '^E486' },
                        { find = '^E42' },
                        { find = '^E776' },
                        { find = '^E348' },
                        { find = '^W325' },
                        { find = '^E1513' },
                        { find = '^E553' },
                        { find = 'E490: No fold found' },
                        { find = 'E211: File .* no longer available' },
                        { find = 'No more valid diagnostics to move to' },
                        { find = 'No code actions available' },
                    },
                },
                view = 'mini',
            },
            {
                filter = {
                    event = 'notify',
                    ---@param msg NoiceMessage
                    cond = function(msg)
                        local title = msg.title or msg.opts and msg.opts.title or ''
                        return vim.tbl_contains({ 'package-info.nvim' }, title)
                    end,
                },
                opts = { skip = true },
            },
            {
                filter = {
                    event = 'notify',
                    ---@param msg NoiceMessage
                    cond = function(msg)
                        local title = msg.title or msg.opts and msg.opts.title or ''
                        return vim.tbl_contains({ 'mason' }, title)
                    end,
                },
                view = 'mini',
            },
            {
                filter = {
                    event = 'notify',
                    kind = { 'debug', 'trace' },
                },
                opts = {
                    timeout = 5000,
                },
                view = 'mini',
            },
            {
                filter = {
                    event = 'msg_show',
                    any = {
                        { find = '^[/?].' }, -- search patterns
                        { find = '^%s*at process.processTicksAndRejections%s*' }, -- broken LSP some times
                    },
                },
                opts = { skip = true },
            },
            {
                filter = {
                    kind = 'error',
                    find = '%s*at process.processTicksAndRejections', -- broken LSP some times
                },
                opts = { skip = true },
            },
            {
                filter = {
                    min_height = 10,
                    ['not'] = {
                        event = 'lsp',
                    },
                    kind = { 'error' },
                },
                view = 'split',
            },
        },
        views = {
            cmdline_popup = {
                border = { style = vim.g.border_style },
            },
            mini = {
                timeout = 3000,
                zindex = 10,
                position = { col = -3 },
                format = { '{title} ', '{message}' },
            },
            hover = {
                border = { style = vim.g.borde_style },
                size = { max_width = 80 },
                win_options = { scrolloff = 4, wrap = true },
            },
            popup = {
                border = { style = vim.g.borde_style },
                size = { width = 90, height = 25 },
                win_options = { scrolloff = 8, wrap = true, concealcursor = 'nv' },
                close = { keys = { 'q' } },
            },
            split = {
                enter = true,
                size = '50%',
                win_options = { scrolloff = 6 },
                close = { keys = { 'q' } },
            },
        },
        presets = {
            bottom_search = true,
            command_palette = true,
            long_message_to_split = true,
            lsp_doc_border = true,
        },
    },
    keys = {
        {
            '<S-Enter>',
            function()
                require('noice').redirect(vim.fn.getcmdline())
            end,
            mode = 'c',
            desc = 'Redirect cmdline',
        },
        {
            '<c-f>',
            function()
                if not require('noice.lsp').scroll(4) then
                    return '<c-f>'
                end
            end,
            silent = true,
            expr = true,
            desc = 'Scroll forward',
            mode = { 'i', 'n', 's' },
        },
        {
            '<c-b>',
            function()
                if not require('noice.lsp').scroll(-4) then
                    return '<c-b>'
                end
            end,
            silent = true,
            expr = true,
            desc = 'Scroll backward',
            mode = { 'i', 'n', 's' },
        },
    },
    init = function()
        require('events').on_event('FileType', function(evt)
            require('health').register_stack_trace_highlights(evt.buf)
        end, 'noice')
    end,
}
