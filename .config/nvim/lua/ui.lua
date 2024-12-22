local icons = require 'icons'

---@class ui
local M = {}

local ignore_hidden_files_option = ide.config.register_toggle('ignore_hidden_files', function(enabled)
    if package.loaded['neo-tree'] then
        -- Update neo-tree state
        local mgr = require 'neo-tree.sources.manager'
        mgr.get_state('filesystem').filtered_items.visible = not enabled
    end
end, { icon = icons.UI.ShowHidden, desc = 'Ignore hidden files', scope = 'global' })

M.ignore_hidden_files = {
    --- Returns whether hidden files are ignored or not
    ---@return boolean # true if hidden files are ignored, false otherwise
    active = ignore_hidden_files_option.get,
    --- Toggles ignoring of hidden files on or off
    ---@param value boolean|nil # if nil, it will toggle the current value, otherwise it will set the value
    toggle = function(value)
        ignore_hidden_files_option.set(value)
    end,
}

ide.config.register_toggle('treesitter_enabled', function(enabled, buffer)
    assert(buffer)

    if not enabled then
        vim.treesitter.stop(buffer.id)
    else
        vim.treesitter.start(buffer.id)
    end
end, { icon = icons.UI.SyntaxTree, desc = 'Treesitter', scope = { 'buffer' } })

return M
