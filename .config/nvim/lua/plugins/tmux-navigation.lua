return {
    "alexghergh/nvim-tmux-navigation",
    keys = {
        {
            "<A-Tab>",
            function()
                require("nvim-tmux-navigation").NvimTmuxNavigateLastActive()
            end,
            mode = "n",
            desc = "Switch window"
        },
        {
            "<A-Left>",
            function()
                require("nvim-tmux-navigation").NvimTmuxNavigateLeft()
            end,
            mode = "n",
            desc = "Go to Left Window"
        },
        {
            "<A-Right>",
            function()
                require("nvim-tmux-navigation").NvimTmuxNavigateRight()
            end,
            mode = "n",
            desc = "Go to Right Window"
        },
        {
            "<A-Down>",
            function()
                require("nvim-tmux-navigation").NvimTmuxNavigateDown()
            end,
            mode = "n",
            desc = "Go to Down Window"
        },
        {
            "<A-Up>",
            function()
                require("nvim-tmux-navigation").NvimTmuxNavigateUp()
            end,
            mode = "n",
            desc = "Go to Up Window"
        },
    }
}
