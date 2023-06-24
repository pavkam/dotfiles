local plugins = {
    {
        'williamboman/mason.nvim',
        opts = {
            ensure_installed = {
                'gopls',
            },
        },
    },
    {
        'nvim-treesitter/nvim-treesitter',
        opts = {
            ensure_installed = {
                -- web
                'html',
                'css',
                'javascript',
                'typescript',
                'tsx',

                -- docs
                'markdown_inline',
                'jsdoc',

                -- langauges
                'vim',
                'lua',
                'pascal',
                'python',
                'c',
                'cpp',
                'c_sharp',

                -- data
                'prisma',
                'sql',
                'proto',

                -- config
                'toml',
                'yaml',
                'ini',
                'json',

                -- go
                'go',
                'gomod',
                'gosum',
                'gowork',

                -- other
                'bash',
                'http',
                'regex',

                -- build
                'dockerfile',
                'make',

                -- git
                'gitcommit',
                'gitattributes',
                'gitignore',
                'git_config',
                'git_rebase',
            },
        },
    },
    {
        'mfussenegger/nvim-dap',
        config = function()
            require('dapui')
            require("nvim-dap-virtual-text")
        end,
        init = function()
            require('core.utils').load_mappings('dap')

            vim.fn.sign_define('DapBreakpoint',{ text ='🟥', texthl ='', linehl ='', numhl =''})
            vim.fn.sign_define('DapStopped',{ text ='▶️', texthl ='', linehl ='', numhl =''})
        end,
    },
    {
        'rcarriga/nvim-dap-ui',
        dependancies = 'mfussenegger/nvim-dap',
        config = function(_ , opts)
            local dap, dapui = require("dap"), require("dapui")
            dapui.setup(opts)

            dap.listeners.after.event_initialized["dapui_config"]=function()
                dapui.open()
            end
            dap.listeners.before.event_terminated["dapui_config"]=function()
                dapui.close()
            end
            dap.listeners.before.event_exited["dapui_config"]=function()
                dapui.close()
            end
        end,
    },
    {
        'theHamsta/nvim-dap-virtual-text',
        dependancies = 'mfussenegger/nvim-dap',
        config = function(_, opts)
            require("nvim-dap-virtual-text").setup(opts)
        end,
    },
    {
        'leoluz/nvim-dap-go',
        ft='go',
        dependancies = 'mfussenegger/nvim-dap',
        config = function(_, opts)
            require('dap-go').setup(opts)
            require('core.utils').load_mappings('dap_go')
        end,
    },
    {
        'neovim/nvim-lspconfig',
        config = function()
            require 'plugins.configs.lspconfig'
            require 'custom.configs.lspconfig'
        end,
    },
    {
        'jose-elias-alvarez/null-ls.nvim',
        ft = 'go',
        opts = function ()
          return require 'custom.configs.null-ls'
        end
    },
    {
        'olexsmir/gopher.nvim',
        ft='go',
        config = function(_, opts)
            require('gopher').setup(opts)
        end,
        build = function()
            vim.cmd [[silent! GoInstallDeps]]
        end,
    },
    {
        'zbirenbaum/copilot.lua',
        event = 'InsertEnter',
        opts = {
            suggestion = {
                enabled = false,
            },
            panel = {
                enabled = false,
            },
        },
    },
    {
        'hrsh7th/nvim-cmp',
        dependencies = {
            {
                'zbirenbaum/copilot-cmp',
                config = function()
                    require('copilot_cmp').setup()
                end,
            },
        },
        opts = {
            sources = {
                { name = 'nvim_lsp', group_index = 2 },
                { name = 'copilot',  group_index = 2 },
                { name = 'luasnip',  group_index = 2 },
                { name = 'buffer',   group_index = 2 },
                { name = 'nvim_lua', group_index = 2 },
                { name = 'path',     group_index = 2 },
            },
        },
    },
    {
        'nvim-neotest/neotest',
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-treesitter/nvim-treesitter',
            'antoinemadec/FixCursorHold.nvim',
            "nvim-neotest/neotest-go",
        },
        init = function()
            require('core.utils').load_mappings('neotest')
        end,
        config = function()
            local neotest_ns = vim.api.nvim_create_namespace("neotest")
            vim.diagnostic.config({
                virtual_text = {
                    format = function(diagnostic)
                        local message =
                            diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
                        return message
                    end,
                },
            }, neotest_ns)
            require("neotest").setup({
                adapters = {
                    require("neotest-go"),
                },
            })
        end,
    },
}

return plugins
