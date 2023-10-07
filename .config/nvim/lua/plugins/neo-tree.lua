local icons = require("utils.icons")

return {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },
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
        source_selector = {
            winbar = true,
            content_layout = "center",
            sources = {
                { source = "filesystem", display_name = icons.ui.FolderClosed .. " " .. "File" },
                { source = "buffers", display_name = icons.ui.Buffers .. " " .. "Bufs" },
                { source = "git_status", display_name = icons.git.Logo .. " " .. "Git" },
                { source = "document_symbols", display_name = icons.SourceSymbols.Package .. " " .. "Symbols" },
            }
        },
        open_files_do_not_replace_types = { "terminal", "Trouble", "qf", "Outline", "neotest-output" },
        filesystem = {
            bind_to_cwd = false,
            follow_current_file = { enabled = true },
            use_libuv_file_watcher = true,
            hijack_netrw_behavior = "open_current",
        },
        default_component_configs = {
            with_markers = true,
            indent = {
                with_expanders = true,
                expander_collapsed = icons.TUI.CollapsedGroup,
                expander_expanded = icons.TUI.ExpandedGroup,
                expander_highlight = "NeoTreeExpander",
            },
            icon = {
                folder_closed = icons.ui.FolderClosed,
                folder_open = icons.ui.FolderOpen,
                folder_empty = icons.ui.FolderEmpty,
                folder_empty_open = icons.ui.FolderEmpty,
                default = icons.ui.File,
            },
            modified = {
                symbol = icons.ui.FileModified
            },
            git_status = {
                symbols = {
                    added = icons.git.Added,
                    deleted = icons.git.Removed,
                    modified = icons.git.Modified,
                    renamed = icons.git.Renamed,
                    untracked = icons.git.Untracked,
                    ignored = icons.git.Ignored,
                    unstaged = icons.git.Unstaged,
                    staged = icons.git.Staged,
                    conflict = icons.git.Conflict,
                },
            },
            commands = {
                parent_or_close = function(state)
                    local node = state.tree:get_node()
                    if (node.type == "directory" or node:has_children()) and node:is_expanded() then
                        state.commands.toggle_node(state)
                    else
                        require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
                    end
                end,
                child_or_open = function(state)
                    local node = state.tree:get_node()
                    if node.type == "directory" or node:has_children() then
                        if not node:is_expanded() then -- if unexpanded, expand
                            state.commands.toggle_node(state)
                        else -- if expanded and has children, seleect the next child
                            require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
                        end
                    else -- if not a directory just open it
                        state.commands.open(state)
                    end
                end,
                find_in_dir = function(state)
                    local node = state.tree:get_node()
                    local path = node:get_id()
                    require("telescope.builtin").find_files {
                        cwd = node.type == "directory" and path or vim.fn.fnamemodify(path, ":h"),
                    }
                end,
            },
            window = {
                width = 30,
                mappings = {
                    ["<space>"] = false, -- disable space until we figure out which-key disabling
                    F = "find_in_dir",
                    h = "parent_or_close",
                    l = "child_or_open",
                    o = "open",
                },
                fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
                    ["<C-j>"] = "move_cursor_down",
                    ["<C-k>"] = "move_cursor_up",
                },
            },
            event_handlers = {
                {
                    event = "neo_tree_buffer_enter",
                    handler = function(_) vim.opt_local.signcolumn = "auto" end,
                },
            },
        },
    },
    config = function(_, opts)
        local utils = require("utils")

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
    end
}
