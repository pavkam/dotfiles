local icons = require("utils.icons")

return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            {
                "nvim-telescope/telescope-fzf-native.nvim",
                enabled = vim.fn.executable "make" == 1,
                build = "make"
            },
            "rcarriga/nvim-notify",
        },
        cmd = "Telescope",
        version = false, -- telescope did only one release, so use HEAD for now
        keys = {
            { "<leader>bb", function() require("telescope.builtin").buffers({ sort_mru = true }) end, desc = "Show buffers" },
            { "<leader>gb", function() require("telescope.builtin").git_branches { use_file_path = true } end, desc = "Git branches" },
            { "<leader>gc", function() require("telescope.builtin").git_commits { use_file_path = true } end, desc = "Git commits" },
            { "<leader>gC", function() require("telescope.builtin").git_bcommits { use_file_path = true } end, desc = "Git commits (file)" },
            { "<leader>gt", function() require("telescope.builtin").git_status { use_file_path = true } end, desc = "Git status" },
            { "<leader>f<cr>", function() require("telescope.builtin").resume { use_file_path = true } end, desc = "Resume search" },

            { "<leader>f/", function() require("telescope.builtin").current_buffer_fuzzy_find() end, desc = "Fuzzy-find in file" },
            { "<leader>fc", function()
                require("telescope.builtin").grep_string { cwd = require("utils.project").root() }
            end, desc = "Find selected word" },

            { "<leader>fw", function()
                require("telescope.builtin").live_grep { cwd = require("utils.project").root() }
            end, desc = "Find words" },

            { "<leader>fW", function()
                require("telescope.builtin").live_grep {
                    additional_args = function(args)
                        return vim.list_extend(args, { "--hidden", "--no-ignore" })
                    end,
                    cwd = require("utils.project").root()
                }
                end,
                desc = "Find Words (all files)"
            },

            { "<leader>ff", function()
                require("telescope.builtin").find_files { cwd = require("utils.project").root() }
            end, desc = "Find files" },

            { "<leader>fo", function()
                require("telescope.builtin").oldfiles { cwd = require("utils.project").root(), only_cwd = true }
            end, desc = "Find used files" },

            { "<leader>fF", function()
                require("telescope.builtin").find_files { hidden = true, no_ignore = true, cwd = require("utils.project").root() }
            end, desc = "Find all files" },

            { "<leader>?c", function() require("telescope.builtin").commands() end, desc = "Show commands" },
            { "<leader>?k", function() require("telescope.builtin").keymaps() end, desc = "Show keymaps" },
            { "<leader>?h", function() require("telescope.builtin").help_tags() end, desc = "Browse help" },
            { "<leader>?m", function() require("telescope.builtin").man_pages() end, desc = "Browse manual" },

            { "<leader>uT", function() require("telescope.builtin").colorscheme { enable_preview = true } end, desc = "Browse themes" },

            { "<leader>sm", function() require("telescope.builtin").diagnostics { bufnr = 0 } end, desc = "Buffer diagnostics" },
            { "<leader>sM", function() require("telescope.builtin").diagnostics() end, desc = "All diagnostics" },

            { "<leader>un", function() require("telescope").extensions.notify.notify() end, desc = "Browse notifications" },
        },
        opts = function()
            local actions = require("telescope.actions")

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

            return {
                defaults = {
                    git_worktrees = vim.g.git_worktrees,
                    prompt_prefix = icons.TUI.PromptPrefix .. " ",
                    selection_caret = icons.TUI.SelectionPrefix .. " ",
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
                            ["<c-s>"] = flash,
                        },
                        n = {
                            ["q"] = actions.close,
                            ["s"] = flash,
                        },
                    },
                    extensions = {
                        ['ui-select'] = { require('telescope.themes').get_dropdown {} }
                    }
                },
            }
        end,
        config = function(_, opts)
            local telescope = require "telescope"
            telescope.setup(opts)

            telescope.load_extension('ui-select')
            telescope.load_extension("fzf")
        end
    },
    {
        'nvim-telescope/telescope-ui-select.nvim',
    }
}
