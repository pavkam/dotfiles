-- FormatOnSave Extension: auto-format buffers before saving.
-- Hooks BufWritePre and calls buffer:format() when the auto_formatting toggle is enabled.
-- Replaces the format-on-save wiring that was previously in conform.nvim config.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'

local FormatOnSave = Class('FormatOnSave', Extension)

function FormatOnSave:init()
    Extension.init(self, 'FormatOnSave')
end

function FormatOnSave:on_register(ctx)
    ctx:toggle('auto_formatting', {
        desc = 'Format on save',
        default = true,
    })

    ctx:hook('BufWritePre', function(args)
        if not IDE.config:is_enabled('auto_formatting') then return end
        if not Buffer.is_valid(args.buf) then return end

        local buf = Buffer.get(args.buf)
        if not buf:is_normal() then return end
        if buf:is_special() then return end

        buf:format { async = false }
    end, { desc = 'FormatOnSave: format before write' })

    -- Set formatexpr on normal buffers so `gq` uses our formatter chain
    -- (falls back to LSP range formatting for partial selections)
    ctx:hook('FileType', function(args)
        if not Buffer.is_valid(args.buf) then return end

        local buf = Buffer.get(args.buf)
        if not buf:is_normal() then return end

        vim.bo[args.buf].formatexpr = "v:lua.IDE.formatter:formatexpr()"
    end, { desc = 'FormatOnSave: set formatexpr for gq' })
end

return FormatOnSave
