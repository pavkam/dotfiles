return {
    'vuki656/package-info.nvim',
    cond = feature_level(3),
    event = 'BufRead package.json',
    dependencies = {
        'MunifTanjim/nui.nvim',
    },
    opts = {},
    config = function(_, opts)
        local pi = require 'package-info'
        local icons = require 'ui.icons'

        pi.setup(opts)

        local utils = require 'core.utils'
        utils.on_event('BufReadPre', function(args)
            vim.keymap.set('n', '<leader>p', function()
                require('ui.select').command {
                    {
                        name = 'Update',
                        command = 'PackageInfoUpdate',
                    },
                    {
                        name = 'Delete',
                        command = 'PackageInfoDelete',
                    },

                    {
                        name = 'Install',
                        command = 'PackageInfoInstall',
                    },

                    {
                        name = 'Change version',
                        command = 'PackageInfoChangeVersion',
                    },
                }
            end, { buffer = args.buf, desc = icons.UI.Action .. ' package.json' })
        end, 'package\\.json')
    end,
}
