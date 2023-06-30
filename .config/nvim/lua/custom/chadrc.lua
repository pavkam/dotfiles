---@type ChadrcConfig
 local M = {
    ui = {
        theme = 'chadracula',
        statusline = {
            theme = 'vscode_colored'
        }
    },
    plugins = 'custom.plugins',
    mappings = require 'custom.mappings',
}

require 'custom.globals'

return M
