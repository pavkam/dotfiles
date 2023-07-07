local plugins = {
    {
        'williamboman/mason.nvim',
        opts = {
            ensure_installed = {
                'gopls', 'bash-language-server', 'typescript-language-server', 'prisma-language-server'
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
                'markdown',
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
            require('nvim-dap-virtual-text')
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
            local dap, dapui = require('dap'), require('dapui')
            dapui.setup(opts)

            dap.listeners.after.event_initialized['dapui_config'] = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated['dapui_config'] = function()
                dapui.close()
            end
            dap.listeners.before.event_exited['dapui_config'] = function()
                dapui.close()
            end
        end,
    },
    {
        'theHamsta/nvim-dap-virtual-text',
        dependancies = 'mfussenegger/nvim-dap',
        config = function(_, opts)
            require('nvim-dap-virtual-text').setup(opts)
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
        'mxsdev/nvim-dap-vscode-js',
        ft = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
        dependancies = {
            'mfussenegger/nvim-dap',
             'microsoft/vscode-js-debug'
        },
        config = function()
            require 'custom.configs.dap-vscode-js'
	    end
    },
    {
        'microsoft/vscode-js-debug',
        lazy = false,
        build = 'npm install --legacy-peer-deps && npx gulp vsDebugServerBundle && mv dist out'
    },
    {
        'glepnir/lspsaga.nvim',
        event = 'LspAttach',
        config = function()
            require 'custom.configs.lspsaga'
            require('core.utils').load_mappings('lspsaga')
        end,
        dependencies = {
            'nvim-tree/nvim-web-devicons',
            'nvim-treesitter/nvim-treesitter',
        }
    },
    {
        'neovim/nvim-lspconfig',
        dependencies = 'glepnir/lspsaga.nvim',
        config = function()
            require 'plugins.configs.lspconfig'
            require 'custom.configs.lspconfig'
        end,
    },
    {
        'jose-elias-alvarez/null-ls.nvim',
        ft = { 'go', 'sh', 'markdown', 'javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'json', 'yaml' },
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
        'nvim-tree/nvim-tree.lua',
        opts = require 'custom.configs.nvim-tree'
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
            'nvim-neotest/neotest-go',
            'nvim-neotest/neotest-jest',
        },
        init = function()
            require('core.utils').load_mappings('neotest')
        end,
        config = function()
            require 'custom.configs.neotest'
        end,
    },
    {
        'nvim-telescope/telescope-ui-select.nvim',
        lazy = false,
        dependencies = {
            'nvim-telescope/telescope.nvim',
        },
        config = function()
            local telescope = require 'telescope'
             telescope.setup {
                extensions = {
                    ["ui-select"] = { require("telescope.themes").get_dropdown {} }
                }
            }
            telescope.load_extension('ui-select')

        end,
    },
}

return plugins
