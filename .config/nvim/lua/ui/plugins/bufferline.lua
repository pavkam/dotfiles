local icons = require 'ui.icons'

return {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    event = 'BufEnter',
    keys = function()
        local keys = {
            { '<leader>C', '<Cmd>BufferLineCloseOthers<CR>', desc = icons.UI.CloseAll .. ' Close other buffers' },
            { '<M-,>', '<Cmd>BufferLineCyclePrev<CR>', desc = 'Previous buffer' },
            { '<M-.>', '<Cmd>BufferLineCycleNext<CR>', desc = 'Next buffer' },
        }

        for i = 1, 9 do
            table.insert(keys, { '<M-' .. i .. '>', '<Cmd>BufferLineGoToBuffer ' .. i .. '<CR>', desc = 'Go to buffer ' .. i })
        end

        return keys
    end,
    opts = {
        options = {
            -- TODO: add loginc to swtch to open split when switching buffers
            close_command = function(n)
                require('mini.bufremove').delete(n, false)
            end,
            right_mouse_command = function(n)
                require('mini.bufremove').delete(n, false)
            end,
            numbers = function(opts)
                return string.format('%s', opts.ordinal)
            end,
            diagnostics = 'nvim_lsp',
            always_show_bufferline = false,
            diagnostics_indicator = function(_, _, diag)
                local ret = (diag.error and icons.Diagnostics.LSP.Error .. ' ' .. diag.error or '')
                    .. (diag.warning and icons.Diagnostics.LSP.Warn .. ' ' .. diag.warning or '')
                return vim.trim(ret)
            end,
            offsets = {
                {
                    filetype = 'dapui_scopes',
                    text = icons.UI.Debugger .. ' Debugger',
                    highlight = 'Debug',
                    text_align = 'left',
                },
            },
        },
    },
    config = function(_, opts)
        local utils = require 'core.utils'
        local buffer_line = require 'bufferline'

        buffer_line.setup(opts)

        -- Fix bufferline when restoring a session
        utils.on_event('BufAdd', function()
            vim.schedule(function()
                ---@diagnostic disable-next-line: undefined-global
                pcall(nvim_bufferline)
            end)
        end)
    end,
}
