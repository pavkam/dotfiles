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
        "folke/neodev.nvim",
        "nvim-neotest/neotest-jest",
        "marilari88/neotest-vitest",
        "nvim-neotest/neotest-go",
    },
    opts = function(_, opts)
        local utils = require "utils"
        local jest = require('neotest-jest')

        jest = jest({
            jestCommand = 'yarn test --',
            env = {
                CI = true
            },
            cwd = function(path)
                return require('neotest-jest.util').find_package_json_ancestor(path)
            end
        })

        opts.adapters = utils.list_insert_unique(opts.adapters, {
            require 'neotest-go',
            require 'neotest-vitest',
            jest,
        })

        return opts
    end,
    config = function(_, opts)
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

        require("neotest").setup(opts)
    end,
}
