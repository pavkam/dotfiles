local icons = require "utils.icons"
local lsp = require "utils.lsp"
local utils = require "utils"

return {
    {
        "nvim-tree/nvim-web-devicons",
        lazy = true
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
        'nvim-lualine/lualine.nvim',
        opts = {
            options = {
                icons_enabled = false,
                theme = 'onedark',
                component_separators = '|',
                section_separators = '',
            },
        },
    },
    {
        "rcarriga/nvim-notify",
        dependencies = {
            {
                "nvim-telescope/telescope.nvim",
                keys = {
                    { "<leader>uN", function() require("telescope").extensions.notify.notify() end, desc = "Browse Notifications" },
                }
            }
        },
        keys = {
            {
                "<leader>un",
                function()
                    require("notify").dismiss({ silent = true, pending = true })
                end,
                desc = "Dismiss all Notifications",
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
        },
    },
    {
        "stevearc/dressing.nvim",
        lazy = true,
        init = function()
            ---@diagnostic disable-next-line: duplicate-set-field
            vim.ui.select = function(...)
                require("lazy").load({ plugins = { "dressing.nvim" } })
                return vim.ui.select(...)
            end
            ---@diagnostic disable-next-line: duplicate-set-field
            vim.ui.input = function(...)
                require("lazy").load({ plugins = { "dressing.nvim" } })
                return vim.ui.input(...)
            end
        end,
    },
    {
        "echasnovski/mini.bufremove",
        -- stylua: ignore
        keys = {
            { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete Buffer" },
            { "<leader>bD", function() require("mini.bufremove").delete(0, true) end, desc = "Delete Buffer (Force)" },
        },
    },
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            plugins = { spelling = true },
            defaults = {
                mode = { "n", "v" },
                ["g"] = { name = "+goto" },
                ["gz"] = { name = "+surround" },
                ["]"] = { name = "+next" },
                ["["] = { name = "+prev" },
                ["<leader>b"] = { name = "+buffer" },
                ["<leader>s"] = { name = "+source" },
                ["<leader>f"] = { name = "+find" },
                ["<leader>g"] = { name = "+git" },
                ["<leader>u"] = { name = "+ui" },
                ["<leader>q"] = { name = "+diagnostics/quickfix" },
                ["<leader>?"] = { name = "+help" },
            },
        },
        config = function(_, opts)
            local wk = require("which-key")
            wk.setup(opts)
            wk.register(opts.defaults)
        end,
    },
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            {
                "nvim-telescope/telescope-fzf-native.nvim",
                enabled = vim.fn.executable "make" == 1,
                build = "make"
            },
        },
        cmd = "Telescope",
        version = false, -- telescope did only one release, so use HEAD for now
        keys = {
            { "<leader>bb", function() require("telescope.builtin").buffers() end, desc = "Show Buffers" },
            { "<leader>gb", function() require("telescope.builtin").git_branches { use_file_path = true } end, desc = "Git Branches" },
            { "<leader>gc", function() require("telescope.builtin").git_commits { use_file_path = true } end, desc = "Git Commits" },
            { "<leader>gC", function() require("telescope.builtin").git_bcommits { use_file_path = true } end, desc = "Git Commits (file)" },
            { "<leader>gt", function() require("telescope.builtin").git_status { use_file_path = true } end, desc = "Git Status" },
            { "<leader>f<cr>", function() require("telescope.builtin").resume { use_file_path = true } end, desc = "Resume Search" },

            { "<leader>f/", function() require("telescope.builtin").current_buffer_fuzzy_find() end, desc = "Fuzzy-find in File" },
            { "<leader>fc", function() require("telescope.builtin").grep_string() end, desc = "Find Selected Word" },
            { "<leader>fw", function() require("telescope.builtin").live_grep() end, desc = "Find Words" },
            { "<leader>fW", function()
                require("telescope.builtin").live_grep {
                    additional_args = function(args) return vim.list_extend(args, { "--hidden", "--no-ignore" }) end,
                }
                end,
                desc = "Find Words (all files)"
            },

            { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find Files" },
            { "<leader>fo", function() require("telescope.builtin").oldfiles() end, desc = "Find Used Files" },
            { "<leader>fF", function() require("telescope.builtin").find_files { hidden = true, no_ignore = true } end, desc = "Find All Files" },

            { "<leader>?c", function() require("telescope.builtin").commands() end, desc = "Show Commands" },
            { "<leader>?k", function() require("telescope.builtin").keymaps() end, desc = "Show Keymaps" },
            { "<leader>?h", function() require("telescope.builtin").help_tags() end, desc = "Browse Help" },
            { "<leader>?m", function() require("telescope.builtin").man_pages() end, desc = "Browse Manual" },

            { "<leader>uT", function() require("telescope.builtin").colorscheme { enable_preview = true } end, desc = "Browse Themes" },

            { "<leader>sd", function() require("telescope.builtin").diagnostics { bufnr = 0 } end, desc = "Browse Diagnostics (File)" },
            { "<leader>sD", function() require("telescope.builtin").diagnostics() end, desc = "Browse Diagnostics (Workspace)" },
        },
        opts = function()
            local actions = require("telescope.actions")
            return {
                defaults = {
                    git_worktrees = vim.g.git_worktrees,
                    prompt_prefix = icons.prompt_prefix .. " ",
                    selection_caret = icons.selection_prefix .. " ",
                    path_display = { "truncate" },
                    sorting_strategy = "ascending",
                    layout_config = {
                        horizontal = { prompt_position = "top", preview_width = 0.55 },
                        vertical = { mirror = false },
                        width = 0.87,
                        height = 0.80,
                        preview_cutoff = 120,
                    },
                    mappings = {
                        i = {
                            ["<C-n>"] = actions.cycle_history_next,
                            ["<C-Down>"] = actions.cycle_history_next,
                            ["<C-p>"] = actions.cycle_history_prev,
                            ["<C-Up>"] = actions.cycle_history_prev,
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-f>"] = actions.preview_scrolling_down,
                            ["<C-b>"] = actions.preview_scrolling_up,
                        },
                        n = {
                            ["q"] = actions.close,
                        },
                    },
                },
            }
        end,
        config = function(_, opts)
            local telescope = require "telescope"
            telescope.setup(opts)

            if utils.plugin_available("telescope-fzf-native.nvim") then
                telescope.load_extension("fzf")
            end
        end
    },
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        opts = {
            lsp = {
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                    ["cmp.entry.get_documentation"] = true,
                },
            },
            routes = {
                {
                    filter = {
                        event = "msg_show",
                        any = {
                        { find = "%d+L, %d+B" },
                        { find = "; after #%d+" },
                        { find = "; before #%d+" },
                        },
                    },
                    view = "mini",
                },
            },
            presets = {
                bottom_search = true,
                command_palette = true,
                long_message_to_split = true,
                inc_rename = true,
            },
        },
        keys = {
            { "<S-Enter>", function() require("noice").redirect(vim.fn.getcmdline()) end, mode = "c", desc = "Redirect Cmdline" },
            { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll forward", mode = {"i", "n", "s"} },
            { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll backward", mode = {"i", "n", "s"}},
        },
    },
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        cmd = "Neotree",
        keys = {
            {
                "<leader>e",
                function()
                    require("neo-tree.command").execute({ toggle = true })
                end,
                desc = "File Explorer",
            },
        },
        deactivate = function()
            vim.cmd([[Neotree close]])
        end,
        init = function()
            if vim.fn.argc() == 1 then
                local stat = vim.loop.fs_stat(vim.fn.argv(0))
                if stat and stat.type == "directory" then
                    require("neo-tree")
                end
            end
        end,
        opts = {
            sources = { "filesystem", "buffers", "git_status", "document_symbols" },
            open_files_do_not_replace_types = { "terminal", "Trouble", "qf", "Outline" },
            filesystem = {
                bind_to_cwd = false,
                follow_current_file = { enabled = true },
                use_libuv_file_watcher = true,
            },
            window = {
                mappings = {
                    ["<space>"] = "none",
                },
            },
            default_component_configs = {
                indent = {
                    with_expanders = true,
                    expander_collapsed = icons.collapsed_group,
                    expander_expanded = icons.expanded_group,
                    expander_highlight = "NeoTreeExpander",
                },
            },
        },
        config = function(_, opts)
            local function on_move(data)
                lsp.notify_file_renamed(data.source, data.destination)
            end

            local events = require("neo-tree.events")
            opts.event_handlers = opts.event_handlers or {}

            vim.list_extend(opts.event_handlers, {
                { event = events.FILE_MOVED, handler = on_move },
                { event = events.FILE_RENAMED, handler = on_move },
            })

            require("neo-tree").setup(opts)

            utils.auto_command(
                "TermClose",
                function()
                    if package.loaded["neo-tree.sources.git_status"] then
                        require("neo-tree.sources.git_status").refresh()
                    end
                end,
                "*lazygit"
            )
        end,
    },
}
