return {
    'luukvbaal/statuscol.nvim',
    cond = feature_level(2),
    enabled = false,
    lazy = false,
    config = function()
        local builtin = require 'statuscol.builtin'
        require('statuscol').setup {
            relculright = true,
            segments = {
                {
                    text = { builtin.lnumfunc },
                    click = 'v:lua.ScLa',
                    colwidth = 3,
                },
                {
                    text = { builtin.foldfunc, ' ' },
                    click = 'v:lua.ScFa',
                },
                {
                    text = { '%s' },
                    click = 'v:lua.ScSa',
                },
            },
        }
    end,
}
