local icons = require 'icons'

return {
    'nvim-telescope/telescope.nvim',
    cond = not ide.process.is_headless,
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
    opts = function()
        local actions = require 'telescope.actions'
        local themes = require 'telescope.themes'
        local qf = require 'qf'

        local special_actions = require('telescope.actions.mt').transform_mod {
            open_qf_list = function()
                qf.toggle('c', true)
            end,
            open_loc_list = function()
                qf.toggle('l', true)
            end,
        }

        local ok, gwt = pcall(vim.api.nvim_get_var, 'git_worktrees')

        return {
            defaults = {
                git_worktrees = ok and gwt or nil,
                prompt_prefix = icons.fit(icons.TUI.PromptPrefix, 2),
                selection_caret = icons.fit(icons.TUI.SelectionPrefix, 2),
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
                        ['<C-q>'] = actions.smart_send_to_qflist + special_actions.open_qf_list,
                        ['<C-l>'] = actions.smart_send_to_loclist + special_actions.open_loc_list,
                    },
                    n = {
                        ['q'] = actions.close,
                        ['s'] = actions.file_split,
                        ['v'] = actions.file_vsplit,
                        ['<C-q>'] = actions.smart_send_to_qflist + special_actions.open_qf_list,
                        ['<C-l>'] = actions.smart_send_to_loclist + special_actions.open_loc_list,
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

        -- Fix telescope modified buffers when closing window
        require('events').on_event({ 'BufModifiedSet' }, function(evt)
            if vim.api.nvim_get_option_value('filetype', { buf = evt.buf }) == 'TelescopePrompt' then
                vim.api.nvim_set_option_value('modified', false, { buf = evt.buf })
            end
        end)
    end,
    init = function()
        --- Wraps the options for telescope to add some defaults
        --- @param opts table|nil
        --- @return table
        local function wrap(opts)
            local show_hidden = not ide.tui.ignore_hidden_files.active()
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
                        ide.tui.ignore_hidden_files.toggle()

                        require('telescope.builtin')[opts.restart_picker](
                            wrap(vim.tbl_extend('force', opts, { default_text = line }))
                        )
                    end)

                    return true
                end
            end

            return table.merge(add, opts)
        end

        --- Creates a wrapper around a picker and returns a function that can be called to invoke the picker
        --- @param picker string # the picker to invoke
        local function blanket(picker)
            return function(opts)
                require('telescope.builtin')[picker](
                    wrap(vim.tbl_extend('force', opts or {}, { restart_picker = picker }))
                )
            end
        end

        local keys = require 'keys'

        keys.map({ 'n', 'v' }, '<M-f>', function()
            local sel = require('syntax').selected_text { smart = false }
            blanket 'live_grep' { default_text = sel }
        end, {
            desc = 'Grep in all files',
        })

        keys.map({ 'n', 'v' }, '<M-S-f>', function()
            local sel = require('syntax').selected_text()
            blanket 'live_grep' { default_text = sel }
        end, {
            desc = 'Grep in all files (selection)',
        })

        keys.map('n', '<leader>f', blanket 'find_files', { icon = icons.UI.Search, desc = 'Search files' })
        keys.map('n', 'z=', function()
            require('telescope.builtin').spell_suggest()
        end, { desc = 'Spell suggestions' })
        keys.map('n', [['']], function()
            require('telescope.builtin').marks()
        end, { desc = 'Marks' })
        keys.map('n', [[""]], function()
            require('telescope.builtin').registers()
        end, { desc = 'Registers' })

        local h_padding = 14
        local v_padding = 4

        ide.plugin.select_ui.register {
            select = function(items, opts)
                local pickers = require 'telescope.pickers'
                local finders = require 'telescope.finders'
                local actions = require 'telescope.actions'
                local themes = require 'telescope.themes'
                local action_state = require 'telescope.actions.state'
                local entry_display = require 'telescope.pickers.entry_display'
                local strings = require 'plenary.strings'
                local config = require('telescope.config').values

                ---@type select_ui_options
                opts = table.merge(opts, {
                    prompt = opts.prompt or 'Select one of',
                    at_cursor = false,
                    separator = ' ',
                    callback = function(item)
                        ide.tui.warn('No handler defined, selected: ' .. inspect(item))
                    end,
                    highlighter = function()
                        return nil
                    end,
                    index_cols = { 1 },
                })

                local prompt = opts.prompt --[[@as string]]
                if prompt:sub(-1, -1) == ':' then
                    prompt = prompt:sub(1, -2)
                end
                prompt = string.gsub(prompt, '\n', ' ')

                local item_length = #items[1]
                local max_width = strings.strdisplaywidth(prompt) + h_padding

                ---@type number[]
                local max_lengths = table.list_map(
                    items[1],
                    ---@param item string
                    function(item)
                        local l = strings.strdisplaywidth(tostring(item))
                        max_width = math.max(max_width, l)

                        return l
                    end
                )

                for _, item in ipairs(items) do
                    if #item ~= item_length then
                        error(
                            string.format(
                                'all items should be of the same length %d: %s',
                                item_length,
                                vim.inspect(item)
                            )
                        )
                    end

                    for i, field in ipairs(item) do
                        max_lengths[i] = math.max(max_lengths[i], strings.strdisplaywidth(tostring(field)))
                    end

                    local line_width = strings.strdisplaywidth(table.concat(item, opts.separator)) + h_padding
                    max_width = math.max(max_width, line_width)
                end

                local max_height = math.min(vim.o.pumheight, #items) + v_padding

                local displayer = entry_display.create {
                    separator = opts.separator,
                    items = table.list_map(
                        max_lengths,
                        ---@param w number
                        function(w)
                            return { width = w }
                        end
                    ),
                }

                local display = function(e)
                    local mapped = {}
                    for i, field in ipairs(e.value) do
                        table.insert(mapped, { field, opts.highlighter(e.value, e.index, i) })
                    end

                    return displayer(mapped)
                end

                local picker_opts = opts.at_cursor
                        and themes.get_cursor {
                            layout_config = {
                                width = opts.width or max_width,
                                height = opts.height or max_height,
                            },
                        }
                    or themes.get_dropdown {
                        layout_config = {
                            width = opts.width or max_width,
                            height = opts.height or max_height,
                        },
                    }

                local function make_ordinal(entry)
                    local ordinal = ''

                    for _, index in ipairs(opts.index_cols) do
                        local v = tostring(entry[index])
                        if v == '' then
                            v = '\u{FFFFF}'
                        end

                        ordinal = ordinal .. '\u{FFFFE}' .. v
                    end

                    return ordinal
                end

                local orig_ordinals = table.inflate(
                    items,
                    ---@param item string[]
                    ---@param index integer
                    ---@return string, integer
                    function(item, index)
                        return make_ordinal(item), index
                    end
                )

                table.sort(items, function(a, b)
                    return make_ordinal(a) < make_ordinal(b)
                end)

                pickers
                    .new(picker_opts, {
                        prompt_title = prompt,
                        finder = finders.new_table {
                            results = items,
                            entry_maker = function(e)
                                return {
                                    value = e,
                                    display = display,
                                    ordinal = make_ordinal(e),
                                }
                            end,
                        },
                        sorter = config.generic_sorter(opts),
                        attach_mappings = function(prompt_bufnr)
                            actions.select_default:replace(function()
                                local selection = action_state.get_selected_entry()
                                if not selection then
                                    return
                                end

                                local orig_index = assert(orig_ordinals[selection.ordinal])

                                actions.close(prompt_bufnr)

                                opts.callback(selection.value, orig_index)
                            end)

                            return true
                        end,
                    })
                    :find()

                return true
            end,
        }
    end,
}
