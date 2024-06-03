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

                if opts and opts.restart_picker then
                    add.attach_mappings = function(_, map)
                        map('i', '<C-h>', function(prompt_bufnr)
                            -- get current text in
                            local action_state = require 'telescope.actions.state'
                            local line = action_state.get_current_line()

                            -- toggle the hidden files
                            require('telescope.actions').close(prompt_bufnr)
                            ui.ignore_hidden_files.toggle()

                            require('telescope.builtin')[opts.restart_picker](wrap(vim.tbl_extend('force', opts, { default_text = line })))
                        end)

                        return true
                    end
                end

                return utils.tbl_merge(add, opts)
            end

            --- Creates a wrapper around a picker and returns a function that can be called to invoke the picker
            --- @param picker string # the picker to invoke
            local function blanket(picker)
                return function(opts)
                    require('telescope.builtin')[picker](wrap(vim.tbl_extend('force', opts or {}, { restart_picker = picker })))
                end
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
                    '<M-f>',
                    function()
                        local sel = require('editor.syntax').current_selection(nil, false)
                        blanket 'live_grep' { default_text = sel }
                    end,
                    desc = 'Grep in all files',
                    mode = { 'n', 'v' },
                },
                {
                    '<M-S-f>',
                    function()
                        local sel = require('editor.syntax').current_selection(nil, true)
                        blanket 'live_grep' { default_text = sel }
                    end,
                    desc = 'Grep in all files (selection)',
                    mode = { 'n', 'v' },
                },
                {
                    '<leader>f',
                    blanket 'find_files',
                    desc = icons.UI.Search .. ' Search files',
                },
                {
                    '<leader>o',
                    blanket 'oldfiles',
                    desc = icons.UI.Search .. ' Search old files',
                },
                {
                    '<leader>uk',
                    '<cmd>Telescope keymaps<cr>',
                    desc = 'Show keymaps',
                },
                {
                    '<leader>uc',
                    '<cmd>Telescope commands<cr>',
                    desc = 'Show commands',
                },
                {
                    '<leader>m',
                    function()
                        require('ui.select').command({
                            {
                                name = 'All',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0 }
                                end,
                            },
                            {
                                name = 'Errors',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'ERROR' }
                                end,
                                hl = 'DiagnosticError',
                            },
                            {
                                name = 'Warnings',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'WARN' }
                                end,
                                hl = 'DiagnosticWarn',
                            },
                            {
                                name = 'Info',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'INFO' }
                                end,
                                hl = 'DiagnosticInfo',
                            },
                            {
                                name = 'Hints',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'HINT' }
                                end,
                                hl = 'DiagnosticHint',
                            },
                        }, { prompt = 'Level', at_cursor = true })
                    end,
                    desc = icons.Diagnostics.Prefix .. ' Diagnostics (buffer)',
                },
                {
                    '<leader>M',
                    function()
                        require('ui.select').command({
                            {
                                name = 'All',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0 }
                                end,
                            },
                            {
                                name = 'Errors',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'ERROR' }
                                end,
                                hl = 'DiagnosticError',
                            },
                            {
                                name = 'Warnings',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'WARN' }
                                end,
                                hl = 'DiagnosticWarn',
                            },
                            {
                                name = 'Info',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'INFO' }
                                end,
                                hl = 'DiagnosticInfo',
                            },
                            {
                                name = 'Hints',
                                command = function()
                                    require('telescope.builtin').diagnostics { bufnr = 0, severity = 'HINT' }
                                end,
                                hl = 'DiagnosticHint',
                            },
                        }, { prompt = 'Level', at_cursor = true })
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
                            ['<M-h>'] = actions.file_split,
                            ['<M-v>'] = actions.file_vsplit,
                            ['<C-f>'] = actions.preview_scrolling_down,
                            ['<C-b>'] = actions.preview_scrolling_up,
                            ['<C-q>'] = actions.smart_send_to_qflist,
                            ['<C-l>'] = actions.smart_send_to_loclist,
                        },
                        n = {
                            ['q'] = actions.close,
                            ['s'] = actions.file_split,
                            ['v'] = actions.file_vsplit,
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

            telescope.load_extension 'fzf'
        end,
    },
}
