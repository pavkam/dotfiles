return {
    'vuki656/package-info.nvim',
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
                require('ui.select').command({
                    {
                        name = 'Change',
                        command = 'PackageInfoChangeVersion',
                        desc = 'Change the package version',
                    },
                    {
                        name = 'Update',
                        command = 'PackageInfoUpdate',
                        desc = 'Update the package',
                    },
                    {
                        name = 'Delete',
                        command = 'PackageInfoDelete',
                        desc = 'Delete the package',
                    },
                    {
                        name = 'Install',
                        command = 'PackageInfoInstall',
                        desc = 'Install the package',
                    },
                }, { at_cursor = true })
            end, { buffer = args.buf, desc = icons.UI.Action .. ' package.json' })
        end, 'package\\.json')

        -- HACK: plug into the package-info plugin to make it work with my progress indicator
        local ls = require 'package-info.ui.generic.loading-status'
        local progress = require 'ui.progress'

        local old_start = ls.start

        ---@diagnostic disable-next-line: duplicate-set-field
        ls['start'] = function(id)
            local idx = #ls.queue
            local msg = idx > 0 and ls.queue[idx].message or nil --[[@as string]]
            msg = msg and msg:sub(3) or 'Processing'

            progress.register_task('package-info', {
                fn = function()
                    return ls.get() ~= ''
                end,
                ctx = msg,
            })
            old_start(id)
        end
    end,
}
