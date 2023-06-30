local M = {}

M.disabled = {
    n = {
        ['<leader>th'] = '',
        ['<leader>wk'] = '',
        ['<leader>wK'] = '',
        ['<leader>n'] = '',
        ['<leader>rn'] = '',
        ['<leader>v'] = '',
        ['<leader>b'] = '',
        ['<leader>x'] = '',
        ['<leader>ch'] = '',
        ['<leader>fm'] = '',
        ['<C-h>'] = '',
        ['<C-l>'] = '',
        ['<C-j>'] = '',
        ['<C-k>'] = '',
        ['<leader>ff'] = '',
        ['<leader>fa'] = '',
        ['<leader>fw'] = '',
        ['<leader>fb'] = '',
        ['<leader>fh'] = '',
        ['<leader>fo'] = '',
        ['<leader>fz'] = '',
        ['<leader>cm'] = '',
        ['<leader>gt'] = '',
        ['<leader>pt'] = '',
        ['<leader>th'] = '',
        ['<leader>ma'] = '',
        ['gD'] = '',
        ['gd'] = '',
        ['K'] = '',
        ['gi'] = '',
        ['<leader>ls'] = '',
        ['<leader>D'] = '',
        ['<leader>ra'] = '',
        ['<leader>ca'] = '',
        ['gr'] = '',
        ['<leader>f'] = '',
        ['[d'] = '',
        [']d'] = '',
        ['<leader>q'] = '',
        ['<leader>wa'] = '',
        ['<leader>wr'] = '',
        ['<leader>wl'] = '',
        ['<leader>/'] = '',
        ['<C-n>'] = '',
        ['<leader>e'] = '',
        ['<leader>cc'] = '',
        ['<A-i>'] = '',
        ['<A-h>'] = '',
        ['<A-v>'] = '',
        ['<leader>h'] = '',
        ['<leader>v'] = '',
    },
    v = {
        ['<leader>/'] = '',
        ['<leader>s/'] = ''
    },
    i = {
        ['<A-Tab>'] = '',
        ['<C-h>'] = '',
        ['<C-l>'] = '',
        ['<C-j>'] = '',
        ['<C-k>'] = '',
    },
    t = {
        ['<A-i>'] = '',
        ['<A-h>'] = '',
        ['<A-v>'] = '',
    },
}

M.dap = {
    plugin = true,
    n = {
        ['<leader>db'] = {
            function ()
                require('dap').toggle_breakpoint();
            end,
            'Toggle breakpoint at line',
        },
        ['<leader>dc'] = {
            function ()
                if vim.fn.filereadable('.vscode/launch.json') then
                    local jsl = { "typescript", "javascript", "typescriptreact" }
                    require('dap.ext.vscode').load_launchjs(nil, {
                        ['pwa-node'] = jsl,
                        ['node'] = jsl,
                        ['chrome'] = jsl,
                        ['pwa-chrome'] = jsl
                    })
                end

                require('dap').continue();
            end,
            'Continue/start debugging',
        },
        ['<leader>dR'] = {
            function ()
                require('dap').restart();
            end,
            'Restart debugging',
        },
        ['<leader>dt'] = {
            function ()
                require('dap').terminate();
            end,
            'Terminate debugging',
        },
        ['<leader>do'] = {
            function ()
                require('dap').step_over();
            end,
            'Step over',
        },
        ['<leader>di'] = {
            function ()
                require('dap').step_into();
            end,
            'Step into',
        },
        ['<leader>dO'] = {
            function ()
                require('dap').step_out();
            end,
            'Step out',
        },
        ['<leader>dr'] = {
            function ()
                require('dap').run_to_cursor();
            end,
            'Go to line',
        },
    },
}

M.dap_go = {
    plugin = true,
    n = {
        ['<leader>td'] = {
            function ()
                require('dap-go').debug_test();
            end,
            'Debug nearest go test in file',
        },
    },
}

M.neotest = {
    plugin = true,
    n = {
        ['<leader>ts'] = {
            function ()
                require('neotest').summary.toggle()
            end,
            'Toggle summary view',
        },
        ['<leader>to'] = {
            function ()
                require('neotest').output.open()
            end,
            'Show test output',
        },
        ['<leader>tw'] = {
            function ()
                require('neotest').watch.toggle()
            end,
            'Toggle test watching',
        },
        ['<leader>tf'] = {
            function ()
                require('neotest').run.run(vim.fn.expand('%'))
            end,
            'Run all tests in file',
        },
        ['<leader>tn'] = {
            function ()
                require('neotest').run.run()
            end,
            'Run nearest test in file',
        },
    },
}

M.whichkey = {
    n = {
        ['<leader>?w'] = { '<cmd>WhichKey<CR>', 'Which key mappings' },
    }
}

M.tabufline = {
    n = {
        ['<leader>bx'] = {
            function()
                require('nvchad_ui.tabufline').close_buffer()
            end,
            'Close buffer',
        },
    }
}

M.telescope = {
    n = {
        ['<leader>ff'] = { '<cmd> Telescope find_files <CR>', 'Find files' },
        ['<leader>fw'] = { '<cmd> Telescope live_grep <CR>', 'Live grep' },
        ['<leader>bl'] = { '<cmd> Telescope buffers <CR>', 'Find buffers' },
        ['<leader>?h'] = { '<cmd> Telescope help_tags <CR>', 'Help page' },
        ['<leader>?t'] = { '<cmd> Telescope keymaps <CR>', 'Telescope mappings' },
        ['<leader>bs'] = { '<cmd> Telescope current_buffer_fuzzy_find <CR>', 'Find in current buffer' },
        ['<leader>gm'] = { '<cmd> Telescope git_commits <CR>', 'Git commits' },
        ['<leader>gs'] = { '<cmd> Telescope git_status <CR>', 'Git status' },
        ['<leader>gb'] = { '<cmd> Telescope git_branches <CR>', 'Git branches' },
        ['<leader>?+'] = { '<cmd> Telescope themes <CR>', 'Nvchad themes' },
    }
}

M.lspconfig = {
    n = {
        ['<leader>sD'] = {
            function()
                vim.lsp.buf.declaration()
            end,
            'Go to declaration',
        },

        ['<leader>sd'] = {
            function()
                vim.lsp.buf.definition()
            end,
            'Go to definition',
        },

        ['<leader>si'] = {
            function()
                vim.lsp.buf.implementation()
            end,
            'Go to implementation',
        },

        ['<leader>st'] = {
            function()
                vim.lsp.buf.type_definition()
            end,
            'Go to type definition',
        },

        ['<leader>sr'] = {
            function()
                vim.lsp.buf.references()
            end,
            'Show all references',
        },

        ['<leader>s!'] = {
            function()
                vim.lsp.buf.hover()
            end,
            'Show source information',
        },

        ['<leader>s?'] = {
            function()
                vim.lsp.buf.signature_help()
            end,
            'Show signature help',
        },

        ['<leader>sR'] = {
            function()
                require('nvchad_ui.renamer').open()
            end,
            'Refactor: rename',
        },

        ['<leader>sF'] = {
            function()
                vim.lsp.buf.format { async = true }
            end,
            'Refactor: format file',
        },

        ['<leader>s['] = {
            function()
                vim.diagnostic.goto_prev { float = { border = 'rounded' } }
            end,
            'Goto prev code issue',
        },

        ['<leader>s]'] = {
            function()
                vim.diagnostic.goto_next { float = { border = 'rounded' } }
            end,
            'Goto next code issue',
        },

        ['<leader>s\\'] = {
            function()
                vim.lsp.buf.code_action()
            end,
            'Show current code action',
        },

        ['<leader>s+'] = {
            function()
                vim.diagnostic.setloclist()
            end,
            'Add code issues to locations list',
        },

        ['<leader>wa'] = {
            function()
                vim.lsp.buf.add_workspace_folder()
            end,
            'Add workspace folder',
        },

        ['<leader>wr'] = {
            function()
                vim.lsp.buf.remove_workspace_folder()
            end,
            'Remove workspace folder',
        },

        ['<leader>wl'] = {
            function()
                print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end,
            'List workspace folders',
        },
    }
}


M.comment = {
    n = {
        ['<leader>s/'] = {
            function()
                require('Comment.api').toggle.linewise.current()
            end,
            'Toggle comment',
        },
    },
    v = {
        ['<leader>s/'] = {
            "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>",
            'Toggle comment',
        },
    },
}

M.nvimtree = {
    n = {
        ['<leader>fe'] = { '<cmd> NvimTreeToggle <CR>', 'Toggle nvimtree' },
        ['<leader>f!'] = { '<cmd> NvimTreeFocus <CR>', 'Focus nvimtree' },
    },
}


M.blankline = {
    n = {
        ['<leader>sc'] = {
            function()
                local ok, start = require('indent_blankline.utils').get_current_context(
                    vim.g.indent_blankline_context_patterns,
                    vim.g.indent_blankline_use_treesitter_scope
                )

                if ok then
                    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { start, 0 })
                    vim.cmd [[normal! _]]
                end
            end,

            'Jump to current context',
        },
    },
}


M.gitsigns = {
  n = {
    ['<leader>g]'] = {
      function()
        if vim.wo.diff then
          return ']c'
        end
        vim.schedule(function()
          require('gitsigns').next_hunk()
        end)
        return '<Ignore>'
      end,
      'Jump to next hunk',
      opts = { expr = true },
    },

    ['<leader>g['] = {
      function()
        if vim.wo.diff then
          return '[c'
        end
        vim.schedule(function()
          require('gitsigns').prev_hunk()
        end)
        return '<Ignore>'
      end,
      'Jump to prev hunk',
      opts = { expr = true },
    },

    ['<leader>gr'] = {
      function()
        require('gitsigns').reset_hunk()
      end,
      'Reset hunk',
    },

    ['<leader>gR'] = {
      function()
        require('gitsigns').reset_buffer()
      end,
      'Reset file',
    },

    ['<leader>gp'] = {
      function()
        require('gitsigns').preview_hunk()
      end,
      'Preview hunk',
    },

    ['<leader>g!'] = {
      function()
        package.loaded.gitsigns.blame_line()
      end,
      'Blame line',
    },

    ['<leader>g-'] = {
      function()
        require('gitsigns').toggle_deleted()
      end,
      'Toggle deleted',
    },
  },
}


M.nvterm = {
  t = {
    ['<A-i>'] = {
      function()
        require('nvterm.terminal').toggle 'float'
      end,
      'Toggle floating term',
    },

    ['<A-h>'] = {
      function()
        require('nvterm.terminal').toggle 'horizontal'
      end,
      'Toggle horizontal term',
    },

    ['<A-v>'] = {
      function()
        require('nvterm.terminal').toggle 'vertical'
      end,
      'Toggle vertical term',
    },
  },

  n = {
    -- toggle in normal mode
    ['<leader>zti'] = {
      function()
        require('nvterm.terminal').toggle 'float'
      end,
      'Toggle floating term',
    },

    ['<leader>zth'] = {
      function()
        require('nvterm.terminal').toggle 'horizontal'
      end,
      'Toggle horizontal term',
    },

    ['<leader>ztv'] = {
      function()
        require('nvterm.terminal').toggle 'vertical'
      end,
      'Toggle vertical term',
    },

    -- new
    ['<leader>zh'] = {
      function()
        require('nvterm.terminal').new 'horizontal'
      end,
      'New horizontal term',
    },

    ['<leader>zi'] = {
      function()
        require('nvterm.terminal').new 'float'
      end,
      'New floating term',
    },

    ['<leader>zv'] = {
      function()
        require('nvterm.terminal').new 'vertical'
      end,
      'New vertical term',
    },
  },
}


M.general = {
    i = {
        ['<S-Tab>'] = { '<C-d>', 'Left tab' },
        ['<C-X>'] = { '<C-O>dd', 'Delete current line' },
        ['<C-A>'] = { '<C-O>gg<C-O>gH<C-O>G', 'Select all' },
        ['<A-Tab>'] = { '<C-O><C-W>w', 'Switch window' },

        ['<A-Tab>'] = { '<C-O><C-W>w', 'Switch window' },
        ['<A-Left>'] = { '<C-O><C-w>h', 'Window left' },
        ['<A-Right>'] = { '<C-O><C-w>l', 'Window right' },
        ['<A-Down>'] = { '<C-O><C-w>j', 'Window down' },
        ['<A-Up>'] = { '<C-O><C-w>k', 'Window up' },
        ['<A-X>'] = { '<C-O><C-w>c', 'Close window' },
    },
    n = {
        ['<C-A>'] = { 'gggH<C-O>G', 'Select all' },

        ['<A-Tab>'] = { '<C-W>w', 'Switch window' },
        ['<A-Left>'] = { '<C-w>h', 'Window left' },
        ['<A-Right>'] = { '<C-w>l', 'Window right' },
        ['<A-Down>'] = { '<C-w>j', 'Window down' },
        ['<A-Up>'] = { '<C-w>k', 'Window up' },
        ['<A-X>'] = { '<C-w>c', 'Close window' },

        ['<leader>?c'] = { '<cmd> NvCheatsheet <CR>', 'Mapping cheatsheet' },

        ['<leader>bn'] = { '<cmd>enew<CR>', 'New buffer in the same window' },
        ['<leader>bv'] = { '<cmd>vnew<CR>', 'New buffer in the new vertical split' },
        ['<leader>bh'] = { '<cmd>new<CR>', 'New buffer in the new horizontal split' },
    },
    v = {
        ['<C-A>'] = { '<C-C>gggH<C-O>G', 'Select all' },
        ['<A-Tab>'] = { '<C-O><C-W>w', 'Switch window' },
        ['<A-Left>'] = { '<C-O><C-w>h', 'Window left' },
        ['<A-Right>'] = { '<C-O><C-w>l', 'Window right' },
        ['<A-Down>'] = { '<C-O><C-w>j', 'Window down' },
        ['<A-Up>'] = { '<C-O><C-w>k', 'Window up' },
        ['<A-X>'] = { '<C-O><C-w>c', 'Close window' },
    },
}

return M
