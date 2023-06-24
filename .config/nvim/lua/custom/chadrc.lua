---@type ChadrcConfig
 local M = {
    ui = {
        theme = 'ashes',
        statusline = {
            theme = 'vscode_colored'
        }
    },
    plugins = 'custom.plugins',
    mappings = require 'custom.mappings',
}

require 'custom.globals'

return M
