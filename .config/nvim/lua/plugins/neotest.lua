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
                return project.root(path)
            end
        })

        vitest = vitest({
            cwd = function(path)
                return project.root(path)
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

        -- register neotest mappings
        utils.on_event(
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
                    { buffer = args.buf, desc = "Toggle summary view"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>to",
                    function ()
                        neotest.output.open()
                    end,
                    { buffer = args.buf, desc = "Show test output"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>tw",
                    function ()
                        neotest.watch.toggle()
                    end,
                    { buffer = args.buf, desc = "Togglee test watching"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>tf",
                    function ()
                        neotest.run.run(vim.fn.expand('%'))
                    end,
                    { buffer = args.buf, desc = "Run all tests"}
                )

                vim.keymap.set(
                    "n",
                    "<leader>tr",
                    function ()
                        neotest.run.run()
                    end,
                    { buffer = args.buf, desc = "Run nearest test"}
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
                    { buffer = args.buf, desc = "Debug nearest test"}
                )

                -- add which key group
                require("which-key").register({
                    ["<leader>t"] = { name = icons.UI.Test .." Testing" }
                }, { buffer = args.buf })
            end,
            spec.ft
        )

        require("neotest").setup(opts)
    end,
}
