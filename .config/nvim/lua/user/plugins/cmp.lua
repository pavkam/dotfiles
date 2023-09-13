return {
    'hrsh7th/nvim-cmp',
    opts = function(_, opts)
        opts.mapping['<C-a>'] = opts.mapping['<C-Space>']
        opts.mapping['<C-Space>'] = nil

        return opts
    end
}
