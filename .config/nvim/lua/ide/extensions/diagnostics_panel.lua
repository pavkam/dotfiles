-- Diagnostics Panel Extension: floating diagnostics and quickfix viewers.
-- Provides :IDEDiagnostics and :IDEQuickFix commands.

local Extension = require 'ide.Extension'

local DiagnosticsPanel = Class('DiagnosticsPanel', Extension)

function DiagnosticsPanel:init()
    Extension.init(self, 'DiagnosticsPanel')
end

function DiagnosticsPanel:on_register(ctx)
    ctx:command('IDEDiagnostics', function(args)
        local Buffer = require 'ide.Buffer'
        local bufnr = args.bang and nil or nil
        if not args.bang then
            local cur = Buffer.current()
            if cur:is_normal() then
                bufnr = cur:id()
            else
                -- Find the most recent normal buffer
                for _, b in ipairs(IDE.buffers:listed()) do
                    if b:is_normal() then bufnr = b:id(); break end
                end
            end
        end
        IDE.toolkit.QuickFix({ title = ' Diagnostics' })
            :from_diagnostics(bufnr)
            :show()
    end, { desc = 'Show diagnostics in floating panel', bang = true })

    ctx:command('IDEQuickFix', function()
        IDE.toolkit.QuickFix({ title = ' Quick Fix' })
            :from_qflist()
            :show()
    end, { desc = 'Show quickfix in floating panel' })
end

return DiagnosticsPanel
