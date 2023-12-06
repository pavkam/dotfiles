return {
    'rcarriga/nvim-notify',
    enabled = feature_level(1),
    lazy = false,
    keys = {
        {
            '<leader>uN',
            function()
                require('notify').dismiss { silent = true, pending = true }
            end,
            desc = 'Dismiss notifications',
        },
    },
    opts = {
        timeout = 3000,
        max_height = function()
            return math.floor(vim.o.lines * 0.75)
        end,
        max_width = function()
            return math.floor(vim.o.columns * 0.75)
        end,
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { zindex = 175 })

            if not package.loaded['nvim-treesitter'] then
                pcall(require, 'nvim-treesitter')
            end

            vim.wo[win].conceallevel = 3

            local buf = vim.api.nvim_win_get_buf(win)
            if not pcall(vim.treesitter.start, buf, 'markdown') then
                vim.bo[buf].syntax = 'markdown'
            end

            vim.wo[win].spell = false
        end,
    },
    config = function(_, opts)
        local notify = require 'notify'
        notify.setup(opts)

        vim.notify = notify
    end,
}
