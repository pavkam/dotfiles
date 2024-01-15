return {
    'alexghergh/nvim-tmux-navigation',
    cond = require('ui.tmux').active(),
    keys = {
        {
            '<M-Tab>',
            function()
                require('nvim-tmux-navigation').NvimTmuxNavigateLastActive()
            end,
            mode = 'n',
            desc = 'Switch window',
        },
        {
            '<M-Left>',
            function()
                require('nvim-tmux-navigation').NvimTmuxNavigateLeft()
            end,
            mode = 'n',
            desc = 'Go to left window',
        },
        {
            '<M-Right>',
            function()
                require('nvim-tmux-navigation').NvimTmuxNavigateRight()
            end,
            mode = 'n',
            desc = 'Go to right window',
        },
        {
            '<M-Down>',
            function()
                require('nvim-tmux-navigation').NvimTmuxNavigateDown()
            end,
            mode = 'n',
            desc = 'Go to window below',
        },
        {
            '<M-Up>',
            function()
                require('nvim-tmux-navigation').NvimTmuxNavigateUp()
            end,
            mode = 'n',
            desc = 'Go to window above',
        },
    },
}
