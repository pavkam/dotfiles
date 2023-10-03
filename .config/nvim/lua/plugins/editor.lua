local utils = require "utils"
local icons = require "utils.icons"

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
        "JoosepAlviste/nvim-ts-context-commentstring",
        lazy = true,
        opts = {
            enable_autocmd = false,
        },
    },
    {
        "nvim-treesitter/nvim-treesitter",
        dependencies = {
            "JoosepAlviste/nvim-ts-context-commentstring",
            "nvim-treesitter/nvim-treesitter-textobjects",
            -- HACK: remove when https://github.com/windwp/nvim-ts-autotag/issues/125 closed.
            { "windwp/nvim-ts-autotag", opts = { autotag = { enable_close_on_slash = false } } },
        },
        version = false,
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter-textobjects",
        },
        cmd = {
            "TSBufDisable",
            "TSBufEnable",
            "TSBufToggle",
            "TSDisable",
            "TSEnable",
            "TSToggle",
            "TSInstall",
            "TSInstallInfo",
            "TSInstallSync",
            "TSModuleInfo",
            "TSUninstall",
            "TSUpdate",
            "TSUpdateSync",
        },
        keys = {
            { "<C-s>", desc = "Increment Selection" },
            { "<bs>", desc = "Decrement Selection", mode = "x" },
        },
        opts = {
            autotag = { enable = true },
            context_commentstring = { enable = true, enable_autocmd = false },
            highlight = {
                enable = true,
                disable = function(_, bufnr) return vim.b[bufnr].large_buf end,
            },
            indent = { enable = true },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        ["ak"] = { query = "@block.outer", desc = "around block" },
                        ["ik"] = { query = "@block.inner", desc = "inside block" },
                        ["ac"] = { query = "@class.outer", desc = "around class" },
                        ["ic"] = { query = "@class.inner", desc = "inside class" },
                        ["a?"] = { query = "@conditional.outer", desc = "around conditional" },
                        ["i?"] = { query = "@conditional.inner", desc = "inside conditional" },
                        ["af"] = { query = "@function.outer", desc = "around function " },
                        ["if"] = { query = "@function.inner", desc = "inside function " },
                        ["al"] = { query = "@loop.outer", desc = "around loop" },
                        ["il"] = { query = "@loop.inner", desc = "inside loop" },
                        ["aa"] = { query = "@parameter.outer", desc = "around argument" },
                        ["ia"] = { query = "@parameter.inner", desc = "inside argument" },
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,
                    goto_next_start = {
                        ["]k"] = { query = "@block.outer", desc = "Next block start" },
                        ["]f"] = { query = "@function.outer", desc = "Next function start" },
                        ["]a"] = { query = "@parameter.inner", desc = "Next argument start" },
                    },
                    goto_next_end = {
                        ["]K"] = { query = "@block.outer", desc = "Next block end" },
                        ["]F"] = { query = "@function.outer", desc = "Next function end" },
                        ["]A"] = { query = "@parameter.inner", desc = "Next argument end" },
                    },
                    goto_previous_start = {
                        ["[k"] = { query = "@block.outer", desc = "Previous block start" },
                        ["[f"] = { query = "@function.outer", desc = "Previous function start" },
                        ["[a"] = { query = "@parameter.inner", desc = "Previous argument start" },
                    },
                    goto_previous_end = {
                        ["[K"] = { query = "@block.outer", desc = "Previous block end" },
                        ["[F"] = { query = "@function.outer", desc = "Previous function end" },
                        ["[A"] = { query = "@parameter.inner", desc = "Previous argument end" },
                    },
                },
                swap = {
                    enable = true,
                    swap_next = {
                        [">K"] = { query = "@block.outer", desc = "Swap next block" },
                        [">F"] = { query = "@function.outer", desc = "Swap next function" },
                        [">A"] = { query = "@parameter.inner", desc = "Swap next argument" },
                    },
                    swap_previous = {
                        ["<K"] = { query = "@block.outer", desc = "Swap previous block" },
                        ["<F"] = { query = "@function.outer", desc = "Swap previous function" },
                        ["<A"] = { query = "@parameter.inner", desc = "Swap previous argument" },
                    },
                },
            },
            ensure_installed = {
                "query",
                "regex",
                "vim",
                "vimdoc",
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
        config = function(_, opts)
            require("nvim-treesitter.configs").setup(opts)
        end
    },
    {
        "L3MON4D3/LuaSnip",
        build = vim.fn.has "win32" == 0
            and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build\n'; make install_jsregexp"
        or nil,
        dependencies = { "rafamadriz/friendly-snippets" },
        opts = {
            history = true,
            delete_check_events = "TextChanged",
            region_check_events = "CursorMoved",
        },
        config = function(_, opts)
            require("luasnip").config.setup(opts)
            vim.tbl_map(function(type) require("luasnip.loaders.from_" .. type).lazy_load() end, { "vscode", "snipmate", "lua" })
        end
    },
    {
        "hrsh7th/nvim-cmp",
        version = false, -- TODO: version?
        event = "InsertEnter",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "saadparwaiz1/cmp_luasnip",
        },
        opts = function()
            vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
            local cmp = require("cmp")
            local defaults = require("cmp.config.default")()
            return {
                completion = {
                    completeopt = "menu,menuone,noinsert",
                },
                snippet = {
                    expand = function(args)
                        require("luasnip").lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
                    ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
                    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"] = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<C-e>"] = cmp.mapping.abort(),
                    ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
                    ["<S-CR>"] = cmp.mapping.confirm({
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = "buffer" },
                    { name = "path" },
                }),
                formatting = {
                    format = function(_, item)
                        if icons.cmp_categories[item.kind] then
                            item.kind = icons.cmp_categories[item.kind] .. item.kind
                        end
                        return item
                    end,
                },
                experimental = {
                    ghost_text = {
                        hl_group = "CmpGhostText",
                    },
                },
                sorting = defaults.sorting,
            }
        end,
    },
    {
        "smjonas/inc-rename.nvim",
        event = "LspAttach"
    }
}
