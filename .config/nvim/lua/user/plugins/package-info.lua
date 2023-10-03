local utils = require 'user.utils'

return {
    'vuki656/package-info.nvim',
    init = function()
        vim.api.nvim_create_autocmd('BufRead', {
            pattern = 'package\\.json',
            desc = 'Configure package.json key mappings',
            group = vim.api.nvim_create_augroup('pavkam/package.json', { clear = true }),
            callback = function(args)
                local pi = require('package-info')
                utils.map({
                    n = {
                        ['<leader>P'] = {
                            buffer = args.buf,
                            desc = utils.get_icon('GitChange', 1, true) .. 'Package.json',
                        },
                        ['<leader>Pu'] = {
                            pi.update,
                            desc = 'Update package version',
                        },
                        ['<leader>Pr'] = {
                            pi.delete,
                            desc = 'Remove package',
                        },
                        ['<leader>Pa'] = {
                            pi.install,
                            desc = 'Add package',
                        },
                        ['<leader>Pv'] = {
                            pi.change_version,
                            desc = 'Change package version',
                        }
                    }
                }, {
                    buffer = args.buf,
                    silent = true,
                    noremap = true,
                })
            end,
        })
    end
}
