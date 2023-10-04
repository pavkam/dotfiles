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
        open_files_do_not_replace_types = { "terminal", "Trouble", "qf", "Outline", "neotest-output" },
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
            with_markers = true,
            indent = {
                with_expanders = true,
                expander_collapsed = icons.collapsed_group,
                expander_expanded = icons.expanded_group,
                expander_highlight = "NeoTreeExpander",
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
