local icons = require 'utils.icons'

return {
    {
        'nvim-telescope/telescope.nvim',
        enabled = feature_level(1),
        dependencies = {
            {
                'nvim-telescope/telescope-fzf-native.nvim',
                enabled = vim.fn.executable 'make' == 1,
                build = 'make',
            },
            'rcarriga/nvim-notify',
        },
        cmd = 'Telescope',
        version = false, -- telescope did only one release, so use HEAD for now
        keys = function()
            local settings = require 'utils.settings'
            local utils = require 'utils'

            --- Wraps the options for telescope to add some defaults
            --- @param opts table|nil
            --- @return table
            local function wrap(opts)
                local show_hidden = not settings.global.ignore_hidden_files
                local add = {
                    additional_args = show_hidden and function(args)
                        return vim.list_extend(args, { '--hidden', '--no-ignore' })
                    end or nil,
                    file_ignore_patterns = { [[.git/]], [[node_modules/]], [[.idea/]], [[.DS_Store]] },
                    cwd = require('utils.project').root(nil, false),
                    hidden = show_hidden,
                    no_ignore = show_hidden,
                }

                return utils.tbl_merge(add, opts)
            end

            return {
                {
                    '<leader>bb',
                    function()
                        require('telescope.builtin').buffers()
                    end,
                    desc = 'Show buffers',
                },
                {
                    '<leader>gb',
                    function()
                        require('telescope.builtin').git_branches()
                    end,
                    desc = 'Git branches',
                },
                {
                    '<leader>gc',
                    function()
                        require('telescope.builtin').git_bcommits()
                    end,
                    desc = 'Git commits',
                },
                {
                    '<leader>gC',
                    function()
                        require('telescope.builtin').git_commits()
                    end,
                    desc = 'Git commits (all)',
                },
                {
                    '<leader>gt',
                    function()
                        require('telescope.builtin').git_status()
                    end,
                    desc = 'Git status',
                },
                {
                    '<leader>f<cr>',
                    function()
                        require('telescope.builtin').resume()
                    end,
                    desc = 'Resume search',
                },
                {
                    '<leader>f/',
                    function()
                        require('telescope.builtin').current_buffer_fuzzy_find()
                    end,
                    desc = 'Fuzzy-find in file',
                },
                {
                    '<leader>fc',
                    function()
                        require('telescope.builtin').grep_string(wrap())
                    end,
                    desc = 'Find selected word',
                },
                {
                    '<leader>fw',
                    function()
                        require('telescope.builtin').live_grep(wrap())
                    end,
                    desc = 'Find words',
                },
                {
                    '<leader>Df',
                    function()
                        require('telescope.builtin').grep_string(wrap {
                            search = 'DEBUGPRINT',
                        })
                    end,
                    desc = 'Find words',
                },
                {
                    '<leader>ff',
                    function()
                        require('telescope.builtin').find_files(wrap())
                    end,
                    desc = 'Find files',
                },
                {
                    '<leader>fo',
                    function()
                        require('telescope.builtin').oldfiles(wrap())
                    end,
                    desc = 'Find used files',
                },
                {
                    '<leader>fF',
                    function()
                        require('telescope.builtin').find_files(wrap())
                    end,
                    desc = 'Find all files',
                },
                {
                    '<leader>?c',
                    function()
                        require('telescope.builtin').commands()
                    end,
                    desc = 'Show commands',
                },
                {
                    '<leader>?k',
                    function()
                        require('telescope.builtin').keymaps()
                    end,
                    desc = 'Show keymaps',
                },
                {
                    '<leader>?h',
                    function()
                        require('telescope.builtin').help_tags()
                    end,
                    desc = 'Browse help',
                },
                {
                    '<leader>?m',
                    function()
                        require('telescope.builtin').man_pages()
                    end,
                    desc = 'Browse manual',
                },
                {
                    '<leader>uT',
                    function()
                        require('telescope.builtin').colorscheme()
                    end,
                    desc = 'Browse themes',
                },
                {
                    '<leader>sm',
                    function()
                        require('telescope.builtin').diagnostics { bufnr = 0 }
                    end,
                    desc = 'Buffer diagnostics',
                },
                {
                    '<leader>sM',
                    function()
                        require('telescope.builtin').diagnostics()
                    end,
                    desc = 'All diagnostics',
                },
                {
                    '<leader>se',
                    function()
                        require('telescope.builtin').diagnostics { bufnr = 0, severity = 'ERROR' }
                    end,
                    desc = 'Buffer errors',
                },
                {
                    '<leader>sE',
                    function()
                        require('telescope.builtin').diagnostics { severity = 'ERROR' }
                    end,
                    desc = 'All errors',
                },
                {
                    '<leader>sw',
                    function()
                        require('telescope.builtin').diagnostics { bufnr = 0, severity = 'WARN' }
                    end,
                    desc = 'Buffer warnings',
                },
                {
                    '<leader>sW',
                    function()
                        require('telescope.builtin').diagnostics { severity = 'WARN' }
                    end,
                    desc = 'All warnings',
                },
                {
                    '<leader>un',
                    function()
                        require('telescope').extensions.notify.notify()
                    end,
                    desc = 'Browse notifications',
                },
                {
                    '=z',
                    function()
                        require('telescope.builtin').spell_suggest()
                    end,
                    desc = 'Browse notifications',
                },
            }
        end,
        opts = function()
            local actions = require 'telescope.actions'
            local themes = require 'telescope.themes'

            local function flash(prompt_bufnr)
                require('flash').jump {
                    pattern = '^',
                    label = { after = { 0, 0 } },
                    search = {
                        mode = 'search',
                        exclude = {
                            function(win)
                                return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'TelescopeResults'
                            end,
                        },
                    },
                    action = function(match)
                        local picker = require('telescope.actions.state').get_current_picker(prompt_bufnr)
                        picker:set_selection(match.pos[1] - 1)
                    end,
                }
            end

            local ok, gwt = pcall(vim.api.nvim_get_var, 'git_worktrees')

            return {
                defaults = {
                    git_worktrees = ok and gwt or nil,
                    prompt_prefix = icons.TUI.PromptPrefix .. ' ',
                    selection_caret = icons.TUI.SelectionPrefix .. ' ',
                    path_display = { 'truncate' },
                    sorting_strategy = 'ascending',
                    layout_config = {
                        horizontal = { prompt_position = 'top', preview_width = 0.55 },
                        vertical = { mirror = false },
                        width = 0.87,
                        height = 0.80,
                        preview_cutoff = 120,
                    },
                    winblend = 10,
                    mappings = {
                        i = {
                            ['<C-n>'] = actions.cycle_history_next,
                            ['<C-Down>'] = actions.cycle_history_next,
                            ['<C-p>'] = actions.cycle_history_prev,
                            ['<C-Up>'] = actions.cycle_history_prev,
                            ['<C-j>'] = actions.move_selection_next,
                            ['<C-k>'] = actions.move_selection_previous,
                            ['<C-x>'] = false,
                            ['<C-v>'] = false,
                            ['\\'] = actions.file_split,
                            ['|'] = actions.file_vsplit,
                            ['<C-f>'] = actions.preview_scrolling_down,
                            ['<C-b>'] = actions.preview_scrolling_up,
                            ['<c-s>'] = flash,
                        },
                        n = {
                            ['q'] = actions.close,
                            ['s'] = flash,
                        },
                    },
                },
                extensions = {
                    ['ui-select'] = {
                        themes.get_dropdown {
                            layout_config = { width = 0.3, height = 0.4 },
                        },
                    },
                },
                pickers = {
                    buffers = themes.get_dropdown {
                        previewer = false,
                        sort_mru = true,
                    },
                    git_branches = themes.get_ivy { use_file_path = true },
                    git_commits = themes.get_ivy { use_file_path = true },
                    git_bcommits = themes.get_ivy { use_file_path = true },
                    git_status = themes.get_ivy { use_file_path = true },
                    resume = { use_file_path = true },
                    current_buffer_fuzzy_find = { previewer = false },
                    colorscheme = { enable_preview = true },
                    spell_suggest = themes.get_cursor {
                        previewer = false,
                    },
                },
            }
        end,
        config = function(_, opts)
            local telescope = require 'telescope'
            telescope.setup(opts)

            telescope.load_extension 'ui-select'
            telescope.load_extension 'fzf'
        end,
    },
    {
        'nvim-telescope/telescope-ui-select.nvim',
        enabled = feature_level(1),
    },
}
