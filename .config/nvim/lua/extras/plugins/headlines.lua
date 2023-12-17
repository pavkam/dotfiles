return {
    'lukas-reineke/headlines.nvim',
    opts = {},
    ft = { 'markdown' },
    config = function(_, opts)
        vim.schedule(function()
            require('headlines').setup(opts)
            require('headlines').refresh()
        end)
    end,
}
