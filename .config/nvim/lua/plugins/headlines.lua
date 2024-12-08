return {
    'lukas-reineke/headlines.nvim',
    cond = not ide.process.is_headless,
    opts = {},
    ft = { 'markdown' },
    config = function(_, opts)
        vim.schedule(function()
            require('headlines').setup(opts)
            require('headlines').refresh()
        end)
    end,
}
