return {
    'rcarriga/nvim-notify',
    lazy = false,
    opts = {
        timeout = 3000,
        max_height = function()
            return math.floor(vim.o.lines * 0.75)
        end,
        max_width = function()
            return math.floor(vim.o.columns * 0.75)
        end,
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { zindex = 175, border = vim.g.borderStyle })

            if not package.loaded['nvim-treesitter'] then
                pcall(require, 'nvim-treesitter')
            end

            vim.wo[win].conceallevel = 3
            vim.wo[win].winfixbuf = true
            vim.wo[win].spell = false

            local buffer = vim.api.nvim_win_get_buf(win)

            if vim.api.nvim_buf_is_valid(buffer) and not pcall(vim.treesitter.start, buffer, 'markdown') then
                vim.bo[buffer].syntax = 'markdown'
            end

            require('extras.health').register_stack_trace_highlights(buffer)
        end,
    },
    config = function(_, opts)
        local notify = require 'notify'
        notify.setup(opts)

        vim.notify = notify
    end,
}
