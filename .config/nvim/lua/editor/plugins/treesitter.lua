return {
    {
        'nvim-treesitter/nvim-treesitter',
        dependencies = {
            {
                'nvim-treesitter/nvim-treesitter-textobjects',
            },
        },
        build = ':TSUpdate',
        event = { 'BufReadPost', 'BufNewFile' },
        -- TODO: tree-sitter not highlighting the TODOs
        cmd = {
            'TSBufDisable',
            'TSBufEnable',
            'TSBufToggle',
            'TSDisable',
            'TSEnable',
            'TSToggle',
            'TSInstall',
            'TSInstallInfo',
            'TSInstallSync',
            'TSModuleInfo',
            'TSUninstall',
            'TSUpdate',
            'TSUpdateSync',
        },
        keys = {
            { '\\', desc = 'Increment selection' },
            { '|', desc = 'Decrement selection', mode = 'x' },
        },
        opts = {
            highlight = {
                enable = true,
                -- disable on large files to prevent lag
                disable = function(_, buf)
                    return vim.api.nvim_buf_line_count(buf) > vim.g.huge_file_lines
                end,
            },
            indent = {
                enable = true,
                disable = {
                    'gitrebase',
                    'yaml',
                },
            },
            matchup = {
                enable = true,
                enable_quotes = true,
            },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        ['ak'] = { query = '@block.outer', desc = 'Around block' },
                        ['ik'] = { query = '@block.inner', desc = 'Inside block' },
                        ['ac'] = { query = '@class.outer', desc = 'Around class' },
                        ['ic'] = { query = '@class.inner', desc = 'Inside class' },
                        ['a?'] = { query = '@conditional.outer', desc = 'Around conditional' },
                        ['i?'] = { query = '@conditional.inner', desc = 'Inside conditional' },
                        ['af'] = { query = '@function.outer', desc = 'Around function ' },
                        ['if'] = { query = '@function.inner', desc = 'Inside function ' },
                        ['al'] = { query = '@loop.outer', desc = 'Around loop' },
                        ['il'] = { query = '@loop.inner', desc = 'Inside loop' },
                        ['aa'] = { query = '@parameter.outer', desc = 'Around argument' },
                        ['ia'] = { query = '@parameter.inner', desc = 'Inside argument' },
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,
                    goto_next_start = {
                        [']k'] = { query = '@block.outer', desc = 'Next block start' },
                        [']f'] = { query = '@function.outer', desc = 'Next function start' },
                        [']a'] = { query = '@parameter.inner', desc = 'Next argument start' },
                    },
                    goto_next_end = {
                        [']K'] = { query = '@block.outer', desc = 'Next block end' },
                        [']F'] = { query = '@function.outer', desc = 'Next function end' },
                        [']A'] = { query = '@parameter.inner', desc = 'Next argument end' },
                    },
                    goto_previous_start = {
                        ['[k'] = { query = '@block.outer', desc = 'Previous block start' },
                        ['[f'] = { query = '@function.outer', desc = 'Previous function start' },
                        ['[a'] = { query = '@parameter.inner', desc = 'Previous argument start' },
                    },
                    goto_previous_end = {
                        ['[K'] = { query = '@block.outer', desc = 'Previous block end' },
                        ['[F'] = { query = '@function.outer', desc = 'Previous function end' },
                        ['[A'] = { query = '@parameter.inner', desc = 'Previous argument end' },
                    },
                },
                swap = {
                    enable = true,
                    swap_next = {
                        ['>K'] = { query = '@block.outer', desc = 'Swap next block' },
                        ['>F'] = { query = '@function.outer', desc = 'Swap next function' },
                        ['>A'] = { query = '@parameter.inner', desc = 'Swap next argument' },
                    },
                    swap_previous = {
                        ['<K'] = { query = '@block.outer', desc = 'Swap previous block' },
                        ['<F'] = { query = '@function.outer', desc = 'Swap previous function' },
                        ['<A'] = { query = '@parameter.inner', desc = 'Swap previous argument' },
                    },
                },
                lsp_interop = {
                    enable = true,
                    border = vim.g.border_style,
                    floating_preview_opts = {},
                },
            },
            ensure_installed = {
                'comment',
                'query',
                'regex',
                'vim',
                'vimdoc',
                'bash',
                'c_sharp',
                'dockerfile',
                'sql',
                'prisma',
                'proto',
                'html',
                'css',
                'markdown',
                'markdown_inline',
                'json',
                'jsdoc',
                'jsonc',
                'toml',
                'yaml',
                'lua',
                'luadoc',
                'luap',
                'python',
                'javascript',
                'typescript',
                'tsx',
                'go',
                'gomod',
                'gowork',
                'gosum',
            },
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = '\\',
                    node_incremental = '\\',
                    scope_incremental = false,
                    node_decremental = '|',
                },
            },
        },
        config = function(_, opts)
            require('nvim-treesitter.configs').setup(opts)
        end,
    },
    {
        'windwp/nvim-ts-autotag',
        opts = {
            enable_close = true,
            enable_rename = true,
            enable_close_on_slash = false,
        },
        per_filetype = {
            ['html'] = {
                enable_close = false,
            },
        },
        config = function(_, opts)
            require('nvim-ts-autotag').setup(opts)
        end,
    },
}
