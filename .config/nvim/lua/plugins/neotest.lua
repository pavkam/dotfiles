return {
    "nvim-neotest/neotest",
    ft = {
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
        "go"
    },
    dependencies = {
        "nvim-neotest/neotest-jest",
        "marilari88/neotest-vitest",
        "nvim-neotest/neotest-go",
    },
    opts = function(_, opts)
        local utils = require "utils"
        local project = require "utils.project"
        local jest = require('neotest-jest')
        local vitest = require('neotest-vitest')

        jest = jest({
            cwd = function(path)
                return project.get_project_root_dir(path)
            end
        })

        vitest = vitest({
            cwd = function(path)
                return project.get_project_root_dir(path)
            end
        })

        opts.adapters = utils.list_insert_unique(opts.adapters, {
            require 'neotest-go',
            vitest,
            jest,
        })

        return opts
    end,
    config = function(spec, opts)
        local utils = require "utils"

        -- register neotest virtual text
        local neotest_ns = vim.api.nvim_create_namespace "neotest"
        vim.diagnostic.config({
            virtual_text = {
                format = function(diagnostic)
                    local message = diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
                    return message
                end,
            },
        }, neotest_ns)

        -- HACK: prevent neotest summary from being replaced
        utils.auto_command(
            "BufEnter",
            function(args)
                local new_file_name = vim.fn.resolve(vim.fn.expand "%")
                local current_file_name = vim.fn.resolve(vim.fn.expand "#")

                if current_file_name == "Neotest Summary" and new_file_name ~= "" and new_file_name ~= current_file_name then
                    vim.cmd('b#')
                end
            end
        )

        -- register neotest mappings
        utils.auto_command(
            "FileType",
            function(args)
                local icons = require "utils.icons"
                local neotest = require "neotest"

                vim.keymap.set(
                    "n",
                    "<leader>tU",
                    function ()
                        neotest.summary.toggle()
                    end,
                    { buffer = args.buf, desc = "Toggle Summary View"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>to",
                    function ()
                        neotest.output.open()
                    end,
                    { buffer = args.buf, desc = "Show Test Output"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>tw",
                    function ()
                        neotest.watch.toggle()
                    end,
                    { buffer = args.buf, desc = "Togglee Test Watching"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>tf",
                    function ()
                        neotest.run.run(vim.fn.expand('%'))
                    end,
                    { buffer = args.buf, desc = "Run All Tests"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>tr",
                    function ()
                        neotest.run.run()
                    end,
                    { buffer = args.buf, desc = "Run Nearest Test"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>td",
                    function ()
                        if args.match == 'go' then
                            require('dap-go').debug_test()
                        else
                            require('neotest').run.run({strategy = 'dap'})
                        end
                    end,
                    { buffer = args.buf, desc = "Debug Nearest Test"}
                )

                -- add which key group
                require("which-key").register({
                    ["<leader>t"] = { name = icons.ui.Test .." Testing" }
                }, { buffer = args.buf })

            end,
            spec.ft
        )

        require("neotest").setup(opts)
    end,
}
