local icons = require 'ui.icons'
local utils = require 'core.utils'

return {
    'nvim-neo-tree/neo-tree.nvim',
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-tree/nvim-web-devicons',
        'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
    keys = {
        {
            '<leader>e',
            function()
                require('neo-tree.command').execute { toggle = true, reveal = true }
            end,
            -- URGENT: Fix this when updating to the which key
            desc = 'File explorer',
        },
    },
    deactivate = function()
        vim.cmd [[Neotree close]]
    end,
    opts = {
        sources = { 'filesystem' },
        open_files_do_not_replace_types = utils.special_file_types,
        enable_diagnostics = true,
        enable_git_status = true,
        enable_modified_markers = true,
        enable_opened_markers = true,
        enable_refresh_on_write = true,
        filesystem = {
            window = {
                position = 'float',
            },
            bind_to_cwd = true,
            cwd_target = {
                current = 'window',
            },
            follow_current_file = { enabled = true },
            filtered_items = {
                never_show = {
                    '.DS_Store',
                    'thumbs.db',
                    '.git',
                    '.idea',
                },
            },
            use_libuv_file_watcher = true,
            hijack_netrw_behavior = 'open_current',
        },
        default_component_configs = {
            with_markers = true,
            diagnostics = {
                symbols = {
                    hint = icons.Diagnostics.LSP.Hint,
                    info = icons.Diagnostics.LSP.Info,
                    warn = icons.Diagnostics.LSP.Warn,
                    error = icons.Diagnostics.LSP.Error,
                },
                highlights = {
                    hint = 'DiagnosticSignHint',
                    info = 'DiagnosticSignInfo',
                    warn = 'DiagnosticSignWarn',
                    error = 'DiagnosticSignError',
                },
            },
            indent = {
                with_expanders = true,
                expander_collapsed = icons.TUI.CollapsedGroup,
                expander_expanded = icons.TUI.ExpandedGroup,
                expander_highlight = 'NeoTreeExpander',
            },
            icon = {
                folder_closed = icons.Files.ClosedFolder,
                folder_open = icons.Files.OpenFolder,
                folder_empty = icons.Files.EmptyFolder,
                folder_empty_open = icons.Files.EmptyFolder,
                default = icons.Files.Normal,
            },
            modified = {
                symbol = icons.Files.Modified,
            },
            git_status = {
                symbols = {
                    added = icons.Git.Added,
                    deleted = icons.Git.Removed,
                    modified = icons.Git.Modified,
                    renamed = icons.Git.Renamed,
                    untracked = icons.Git.Untracked,
                    ignored = icons.Git.Ignored,
                    unstaged = icons.Git.Unstaged,
                    staged = icons.Git.Staged,
                    conflict = icons.Git.Conflict,
                },
            },
        },
        commands = {
            parent_or_close = function(state)
                local node = state.tree:get_node()
                if (node.type == 'directory' or node:has_children()) and node:is_expanded() then
                    state.commands.toggle_node(state)
                else
                    require('neo-tree.ui.renderer').focus_node(state, node:get_parent_id())
                end
            end,
            child_or_open = function(state)
                local node = state.tree:get_node()
                if node.type == 'directory' or node:has_children() then
                    if not node:is_expanded() then -- if unexpanded, expand
                        state.commands.toggle_node(state)
                    else -- if expanded and has children, select the next child
                        require('neo-tree.ui.renderer').focus_node(state, node:get_child_ids()[1])
                    end
                else -- if not a directory just open it
                    state.commands.open(state)
                end
            end,
            find_in_dir = function(state)
                local node = state.tree:get_node()
                local path = node:get_id()
                require('telescope.builtin').find_files {
                    cwd = node.type == 'directory' and path or vim.fn.fnamemodify(path, ':h'),
                }
            end,
        },
        window = {
            width = 30,
            mappings = {
                ['<space>'] = false, -- disable space until we figure out which-key disabling
                ['F'] = 'find_in_dir',
                ['h'] = 'parent_or_close',
                ['l'] = 'child_or_open',
                ['o'] = 'open',
                ['<del>'] = 'delete',
                ['S'] = false,
                ['s'] = false,
                ['<M-h>'] = 'open_split',
                ['<M-v>'] = 'open_vsplit',
                ['<C-h>'] = 'toggle_hidden',
                ['H'] = false,
            },
            fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
                ['<C-j>'] = 'move_cursor_down',
                ['<C-k>'] = 'move_cursor_up',
            },
        },
        event_handlers = {
            {
                event = 'neo_tree_buffer_enter',
                handler = function(_)
                    vim.opt_local.signcolumn = 'auto'
                end,
            },
            {
                event = 'neo_tree_buffer_leave',
                handler = function()
                    local state = require('neo-tree.sources.manager').get_state 'filesystem'

                    require('ui').ignore_hidden_files.toggle(not state.filtered_items.visible)
                end,
            },
        },
    },
    config = function(_, opts)
        local lsp = require 'project.lsp'

        local function on_move(data)
            lsp.notify_file_renamed(data.source, data.destination)
        end

        local events = require 'neo-tree.events'
        opts.event_handlers = opts.event_handlers or {}

        vim.list_extend(opts.event_handlers, {
            { event = events.FILE_MOVED, handler = on_move },
            { event = events.FILE_RENAMED, handler = on_move },
        })

        require('neo-tree').setup(opts)

        utils.on_focus_gained(function()
            local ok, manager = pcall(require, 'neo-tree.sources.manager')
            if ok then
                for _, source in ipairs { 'filesystem', 'git_status', 'document_symbols' } do
                    local module = 'neo-tree.sources.' .. source
                    if package.loaded[module] then
                        manager.refresh(require(module).name)
                    end
                end
            end
        end)
    end,
}
