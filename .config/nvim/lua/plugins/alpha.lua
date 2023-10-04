local utils = require "utils"
local icons = require "utils.icons"

return {
    "goolord/alpha-nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons"
    },
    event = "VimEnter",
    opts = function()
        local icons = require "utils.icons"

        local dashboard = require("alpha.themes.dashboard")
        local logo = [[
,-.       _,---._ __  / \
/  )    .-'       `./ /   \
(  (   ,'            `/    /|
\  `-"             \'\   / |
`.              ,  \ \ /  |
/`.          ,'-`----Y   |
(            ;        |   '
|  ,-.    ,-'         |  /
|  | (   |            | /
)  |  \  `.___________|/
`--'   `--'
        ]]

        dashboard.section.header.val = vim.split(logo, "\n")
        dashboard.section.buttons.val = {
            dashboard.button("e", icons.ui.Explorer .. " File Explorer", ":Neotree toggle <CR>"),
            dashboard.button("f", icons.ui.Search .. " Find Files", ":Telescope find_files <CR>"),
            dashboard.button("o", icons.ui.Files .. " Recent Files", ":Telescope oldfiles <CR>"),
            dashboard.button("l", icons.ui.Sleep .. " Lazy", ":Lazy<CR>"),
            dashboard.button("q", icons.ui.Quit .. " Quit", ":qa<CR>"),
        }

        for _, button in ipairs(dashboard.section.buttons.val) do
            button.opts.hl = "AlphaButtons"
            button.opts.hl_shortcut = "AlphaShortcut"
        end

        dashboard.section.header.opts.hl = "AlphaHeader"
        dashboard.section.buttons.opts.hl = "AlphaButtons"
        dashboard.section.footer.opts.hl = "AlphaFooter"
        dashboard.opts.layout[1].val = 8

        return dashboard
    end,
    config = function(_, dashboard)
        local utils = require "utils"
        local icons = require "utils.icons"

        if vim.o.filetype == "lazy" then
            vim.cmd.close()
            utils.auto_command(
                "User",
                function()
                    require("lazy").show()
                end,
                "AlphaReady"
            )
        end

        require("alpha").setup(dashboard.opts)

        utils.auto_command(
            "User",
            function()
                local stats = require("lazy").stats()
                local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)

                dashboard.section.footer.val = icons.ui.Speed .. " Neovim loaded " .. stats.count .. " plugins in " .. ms .. "ms"

                pcall(vim.cmd.AlphaRedraw)
            end,
            "LazyVimStarted"
        )
    end,
}
