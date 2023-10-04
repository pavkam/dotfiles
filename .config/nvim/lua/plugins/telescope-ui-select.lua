return {
    'nvim-telescope/telescope-ui-select.nvim',
    event = "VeryLazy",
    dependencies = {
        'nvim-telescope/telescope.nvim',
    },
    config = function()
        local telescope = require 'telescope'
            telescope.setup {
            extensions = {
                ['ui-select'] = { require('telescope.themes').get_dropdown {} }
            }
        }
        telescope.load_extension('ui-select')
    end,
}
