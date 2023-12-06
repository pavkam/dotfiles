local icons = require 'utils.icons'

return {
    'folke/noice.nvim',
    enabled = feature_level(2),
    event = 'VeryLazy',
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
                        { find = 'E486' },
                    },
                },
                view = 'mini',
            },
        },
        cmdline = {
            format = {
                replace_selection = { kind = 'search', pattern = [[^:s/]], icon = icons.UI.Replace, lang = 'regex' },
                replace_global = { kind = 'search', pattern = [[^:g/]], icon = icons.UI.Replace, lang = 'regex' },
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
}
