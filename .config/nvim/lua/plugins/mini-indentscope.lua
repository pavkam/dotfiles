local icons = require "utils.icons"

return {
    "echasnovski/mini.indentscope",
    version = false, -- TODO: wait till new 0.7.0 release to put it back on semver
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        symbol = icons.TUI.IndentLevel,
        options = {
            try_as_border = true
        },
    },
    init = function()
        local utils = require "utils"

        utils.auto_command(
            "FileType",
            function() vim.b.miniindentscope_disable = true end,
            {
                "help",
                "alpha",
                "dashboard",
                "neo-tree",
                "Trouble",
                "lazy",
                "mason",
                "notify",
                "toggleterm",
                "lazyterm",
                "qf"
            }
        )
    end
}
