local icons = require 'ui.icons'

return {
    {
        'nvim-telescope/telescope.nvim',
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
            --- Wraps the options for telescope to add some defaults
            --- @param opts table|nil
            --- @return table
            local function wrap(opts)
                local utils = require 'core.utils'
                local ui = require 'ui'

                local show_hidden = not ui.ignore_hidden_files.active()
                local add = {
                    additional_args = show_hidden and function(args)
                        return vim.list_extend(args, { '--hidden', '--no-ignore' })
                    end or nil,
                    file_ignore_patterns = { [[.git/]], [[node_modules/]], [[.idea/]], [[.DS_Store]] },
                    cwd = require('project').root(nil, false),
                    hidden = show_hidden,
                    no_ignore = show_hidden,
                }

                return utils.tbl_merge(add, opts)
            end

            return {
                {
                    '<leader>b',
                    function()
                        require('telescope.builtin').buffers()
                    end,
                    desc = icons.UI.Buffers .. ' Show buffers',
                },
                {
                    '<C-_>',
                    function()
                        require('telescope.builtin').current_buffer_fuzzy_find {}
                    end,
                    desc = 'Fuzzy-find in file',
                    mode = { 'n', 'v' },
                },
                {
                    '<M-/>',
                    function()
                        print('->>', vim.inspect(vim.fn.getpos "'<"))

                        local sel = require('editor.syntax').current_selection(nil, false)
                        if sel then
                            require('telescope.builtin').grep_string(wrap { search = sel })
                        else
                            require('telescope.builtin').live_grep(wrap())
                        end
                    end,
                    desc = 'Live grep',
                    mode = { 'n', 'v' },
                },
                {
                    '<leader>f',
                    function()
                        require('telescope.builtin').find_files(wrap())
                    end,
                    desc = icons.UI.Search .. ' Search files',
                },
                {
                    '<leader>o',
                    function()
                        require('telescope.builtin').oldfiles(wrap())
                    end,
                    desc = icons.UI.Search .. ' Search old files',
                },
                {
                    '<leader>uk',
                    'Telescope keymaps',
                    desc = 'Show keymaps',
                },
                {
                    '<leader>uc',
                    'Telescope commands',
                    desc = 'Show commands',
                },
                {
                    '<leader>m',
                    function()
                        require('ui.select').command {
                            {
                                name = 'All',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0 }
                                end,
                                desc = 'Buffer',
                            },
                            {
                                name = 'Errors',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'ERROR' }
                                end,
                                desc = 'Buffer',
                                hl = 'DiagnosticError',
                            },
                            {
                                name = 'Warnings',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'WARN' }
                                end,
                                desc = 'Buffer',
                                hl = 'DiagnosticWarn',
                            },
                            {
                                name = 'Info',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'INFO' }
                                end,
                                desc = 'Buffer',
                                hl = 'DiagnosticInfo',
                            },
                            {
                                name = 'Hints',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'HINT' }
                                end,
                                desc = 'Buffer',
                                hl = 'DiagnosticHint',
                            },
                            {
                                name = 'All',
                                command = function()
                                    require('telescope.builtin').diagnostics {}
                                end,
                                desc = 'Global',
                            },
                            {
                                name = 'Errors',
                                command = function()
                                    require('telescope.builtin').diagnostics { severity = 'ERROR' }
                                end,
                                desc = 'Global',
                                hl = 'DiagnosticError',
                            },
                            {
                                name = 'Warnings',
                                command = function()
                                    require('telescope.builtin').diagnostics { severity = 'WARN' }
                                end,
                                desc = 'Global',
                                hl = 'DiagnosticWarn',
                            },
                            {
                                name = 'Info',
                                command = function()
                                    require('telescope.builtin').diagnostics { severity = 'INFO' }
                                end,
                                desc = 'Global',
                                hl = 'DiagnosticInfo',
                            },
                            {
                                name = 'Hints',
                                command = function()
                                    require('telescope.builtin').diagnostics { severity = 'HINT' }
                                end,
                                desc = 'Global',
                                hl = 'DiagnosticHint',
                            },
                        }
                    end,
                    desc = icons.Diagnostics.Prefix .. ' Diagnostics',
                },
                {
                    '<leader>un',
                    function()
                        require('telescope').extensions.notify.notify()
                    end,
                    desc = 'Browse notifications',
                },
                {
                    'z=',
                    function()
                        require('telescope.builtin').spell_suggest()
                    end,
                    desc = 'Spell suggestions',
                },
                {
                    [['']],
                    function()
                        require('telescope.builtin').marks()
                    end,
                    desc = 'Marks',
                },
                {
                    [[""]],
                    function()
                        require('telescope.builtin').registers()
                    end,
                    desc = 'Marks',
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
                            ['<C-p>'] = actions.cycle_history_prev,
                            ['<C-j>'] = actions.move_selection_next,
                            ['<C-k>'] = actions.move_selection_previous,
                            ['<C-x>'] = false,
                            ['<C-v>'] = false,
                            ['<C-\\>'] = actions.file_split,
                            ['<C-|>'] = actions.file_vsplit,
                            ['<C-f>'] = actions.preview_scrolling_down,
                            ['<C-b>'] = actions.preview_scrolling_up,
                            ['<C-s>'] = flash,
                            ['<C-q>'] = actions.smart_send_to_qflist,
                            ['<C-l>'] = actions.smart_send_to_loclist,
                        },
                        n = {
                            ['q'] = actions.close,
                            ['s'] = flash,
                            ['\\>'] = actions.file_split,
                            ['|'] = actions.file_vsplit,
                            ['<C-q>'] = actions.smart_send_to_qflist,
                            ['<C-l>'] = actions.smart_send_to_loclist,
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
                    oldfiles = { only_cwd = true },
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
    },
}
