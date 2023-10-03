return {
    {
        "nvim-tree/nvim-web-devicons",
        lazy = true,
        opts = {
            override = {
                default_icon = { icon = "󰈙" },
                deb = { icon = "", name = "Deb" },
                lock = { icon = "󰌾", name = "Lock" },
                mp3 = { icon = "󰎆", name = "Mp3" },
                mp4 = { icon = "", name = "Mp4" },
                out = { icon = "", name = "Out" },
                ["robots.txt"] = { icon = "󰚩", name = "Robots" },
                ttf = { icon = "", name = "TrueTypeFont" },
                rpm = { icon = "", name = "Rpm" },
                woff = { icon = "", name = "WebOpenFontFormat" },
                woff2 = { icon = "", name = "WebOpenFontFormat2" },
                xz = { icon = "", name = "Xz" },
                zip = { icon = "", name = "Zip" },
            },
        },
    },
    {
        "onsails/lspkind.nvim",
        opts = {
            mode = "symbol",
            symbol_map = {
                Array = "󰅪",
                Boolean = "⊨",
                Class = "󰌗",
                Constructor = "",
                Key = "󰌆",
                Namespace = "󰅪",
                Null = "NULL",
                Number = "#",
                Object = "󰀚",
                Package = "󰏗",
                Property = "",
                Reference = "",
                Snippet = "",
                String = "󰀬",
                TypeParameter = "󰊄",
                Unit = "",
            },
            menu = {},
        },
        enabled = vim.g.icons_enabled,
        config = function(_, opts)
            require("lspkind").init(opts)
        end
    },
    {
        "MunifTanjim/nui.nvim",
        lazy = true
    },
    {
        "nvim-lua/plenary.nvim",
        lazy = true
    },
    {
        "stevearc/dressing.nvim",
        lazy = true,
        opts = {
            input = { default_prompt = "➤ " },
            select = { backend = { "telescope", "builtin" } },
        },
        init = function()
            vim.ui.select = function(...)
                require("lazy").load({ plugins = { "dressing.nvim" } })
                return vim.ui.select(...)
            end
            vim.ui.input = function(...)
                require("lazy").load({ plugins = { "dressing.nvim" } })
                return vim.ui.input(...)
            end
        end,
    },
}
