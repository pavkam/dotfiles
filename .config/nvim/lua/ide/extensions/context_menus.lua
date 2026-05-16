-- Context Menus Extension: registers right-click context menu providers.
-- Provides LSP actions, diagnostics, file operations, and navigation
-- as context-aware menu items via Buffer.add_context_provider().

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'

local ContextMenus = Class('ContextMenus', Extension)

function ContextMenus:init()
    Extension.init(self, 'ContextMenus')
end

function ContextMenus:on_register(ctx)
    Buffer.add_context_provider(function(buf, row)
        if not buf:is_normal() or not buf:lsp():is_attached() then return nil end
        return {
            { group = 'LSP', items = {
                { text = 'Go to Definition', icon = '', action = function() buf:lsp():definition() end },
                { text = 'Go to References', icon = '', action = function() IDE.ui.finder:references() end },
                { text = 'Go to Implementation', icon = '', action = function() IDE.ui.finder:implementations() end },
            }},
            { group = 'Edit', items = {
                { text = 'Rename Symbol', icon = '󰛔', action = function() buf:lsp():rename() end },
                { text = 'Code Action', icon = '󰜎', action = function() buf:lsp():code_action() end },
            }},
            { group = 'Docs', items = {
                { text = 'Hover Documentation', icon = '󰋖', action = function() buf:lsp():hover() end },
                { text = 'Signature Help', icon = '', action = function() buf:lsp():signature_help() end },
            }},
        }
    end)

    Buffer.add_context_provider(function(buf, row)
        local diags = buf:diagnostics():list()
        local line_diags = {}
        for _, d in ipairs(diags) do
            if d.lnum == row - 1 then line_diags[#line_diags + 1] = d end
        end
        if #line_diags == 0 then return nil end
        return {{ group = 'Diagnostics', items = {
            { text = 'Show Diagnostic', icon = '', action = function() buf:lsp():show_diagnostic() end, hl = 'DiagnosticWarn' },
            { text = 'Next Diagnostic', icon = '󰼧', action = function() buf:diagnostics():next() end },
            { text = 'Diagnostics Panel', icon = '', action = function()
                IDE.toolkit.QuickFix({ title = ' Diagnostics' }):from_diagnostics(0):show()
            end },
        }}}
    end)

    Buffer.add_context_provider(function(buf)
        if not buf:is_normal() then return nil end
        return {
            { group = 'Edit', items = {
                { text = 'Cut', icon = '󰆐', action = function() IDE.keys:normal('"+d') end },
                { text = 'Copy', icon = '', action = function() IDE.keys:normal('"+y') end },
                { text = 'Paste', icon = '󰆒', action = function() IDE.keys:normal('"+p') end },
                { text = 'Select All', icon = '󰒆', action = function() IDE.actions:execute('editor.selectAll') end },
            }},
            { group = 'File', items = {
                { text = 'Format File', icon = '󰉿', action = function() buf:format() end },
                { text = 'Save', icon = '󰆓', action = function() buf:save() end },
            }},
        }
    end)

    Buffer.add_context_provider(function()
        return {{ group = 'Navigate', items = {
            { text = 'Find Files', icon = '', action = function() IDE.ui.finder:files() end },
            { text = 'Find in Files', icon = '', action = function() IDE.ui.finder:grep() end },
        }}}
    end)
end

return ContextMenus
