local utils = require "utils"

return {
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "BufReadPost", "BufNewFile" },
        opts = {
            indent = {
                char = "│",
                tab_char = "│",
            },
            scope = { enabled = false },
            exclude = {
                filetypes = {
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
                },
            },
        },
        main = "ibl",
    },
    {
        "echasnovski/mini.indentscope",
        version = false, -- TODO: wait till new 0.7.0 release to put it back on semver
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            -- symbol = "▏",
            symbol = "│",
            options = { try_as_border = true },
        },
        init = function()
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
                }
            )
        end,
    },
    {
        "folke/flash.nvim",
        event = "VeryLazy",
        dependencies = {
            {
                "nvim-telescope/telescope.nvim",
                opts = function(_, opts)
                    local function flash(prompt_bufnr)
                        require("flash").jump({
                        pattern = "^",
                        label = { after = { 0, 0 } },
                        search = {
                            mode = "search",
                            exclude = {
                                function(win)
                                    return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "TelescopeResults"
                                end,
                            },
                        },
                        action = function(match)
                            local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
                            picker:set_selection(match.pos[1] - 1)
                        end,
                        })
                    end

                    opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
                        mappings = { n = { s = flash }, i = { ["<c-s>"] = flash } },
                    })

                    return opts
                end,
            },
        },
        vscode = true,
        opts = {},
        keys = {
            { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
            { "S", mode = { "n", "o", "x" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
            { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
            { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
            { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
        },
    },
    {
        "nvim-treesitter/nvim-treesitter",
        version = false,
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter-textobjects",
        },
        cmd = { "TSUpdateSync" },
        keys = {
            { "<C-s>", desc = "Increment Selection" },
            { "<bs>", desc = "Decrement Selection", mode = "x" },
        },
        opts = {
            highlight = { enable = true },
            indent = { enable = true },
            ensure_installed = {
                "bash",
                "cpp",
                "c",
                "objc",
                "cuda",
                "proto",
                "c_sharp",
                "javascript",
                "typescript",
                "tsx",
                "go",
                "gomod",
                "gosum",
                "gowork",
                "jsdoc",
                "json",
                "jsonc",
                "lua",
                "luadoc",
                "luap",
                "html",
                "markdown",
                "markdown_inline",
                "python",
                "query",
                "regex",
                "vim",
                "vimdoc",
                "yaml",
                "toml",
                "dockerfile"
            },
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<C-s>",
                    node_incremental = "<C-s>",
                    scope_incremental = false,
                    node_decremental = "<bs>",
                },
            },
        },
    },
}
