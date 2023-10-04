local icons = require("utils.icons")

return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-telescope/telescope-fzf-native.nvim",
        "folke/flash.nvim",
        "rcarriga/nvim-notify",
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

        { "<leader>uN", function() require("telescope").extensions.notify.notify() end, desc = "Browse Notifications" },
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
                        ["<c-s>"] = flash,
                    },
                    n = {
                        ["q"] = actions.close,
                        ["s"] = flash,
                    },
                },
            },
        }
    end,
    config = function(_, opts)
        local telescope = require "telescope"
        telescope.setup(opts)

        telescope.load_extension("fzf")
    end
}
