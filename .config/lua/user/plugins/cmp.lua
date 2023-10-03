return {
    'hrsh7th/nvim-cmp',
    dependencies = {
        'hrsh7th/cmp-calc',
        'hrsh7th/cmp-emoji',
        'chrisgrieser/cmp-nerdfont',
    },

    opts = function(_, opts)
        local cmp = require "cmp"

        opts.mapping['<C-a>'] = opts.mapping['<C-Space>']
        opts.mapping['<C-Space>'] = nil

        opts.sources = cmp.config.sources {
            { name = "nvim_lsp", priority = 1000 },
            { name = "luasnip", priority = 900 },
            { name = "buffer", priority = 800 },
            { name = "path", priority = 700 },
            { name = "nerdfont", priority = 560 },
            { name = "emoji", priority = 550 },
            { name = "calc", priority = 540 },
        }

        return opts
    end
}
