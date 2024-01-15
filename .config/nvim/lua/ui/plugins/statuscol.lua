return {
    'luukvbaal/statuscol.nvim',
    lazy = false,
    config = function()
        local builtin = require 'statuscol.builtin'
        require('statuscol').setup {
            relculright = true,
            segments = {
                {
                    sign = {
                        name = { 'Diagnostic', 'mark_', 'Dap', 'neotest' },
                    },
                    colwidth = 1,
                    click = 'v:lua.ScSa',
                },
                {
                    text = { builtin.lnumfunc },
                    click = 'v:lua.ScLa',
                    colwidth = 3,
                },
                {
                    sign = {
                        namespace = { 'gitsigns_extmark_signs_' },
                    },
                    colwidth = 1,
                    click = 'v:lua.ScSa',
                },
                {
                    text = { builtin.foldfunc, ' ' },
                    click = 'v:lua.ScFa',
                },
            },
        }
    end,
}
