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
        pi.setup(opts)

        local utils = require 'utils'
        utils.on_event('BufReadPre', function(args)
            vim.keymap.set('n', '<leader>Pu', pi.update, { buffer = args.buf, desc = 'Update package version' })

            vim.keymap.set('n', '<leader>Pr', pi.delete, { buffer = args.buf, desc = 'Remove package' })

            vim.keymap.set('n', '<leader>Pa', pi.install, { buffer = args.buf, desc = 'Add package' })

            vim.keymap.set('n', '<leader>Pv', pi.change_version, { buffer = args.buf, desc = 'Change package version' })
        end, 'package\\.json')
    end,
}
