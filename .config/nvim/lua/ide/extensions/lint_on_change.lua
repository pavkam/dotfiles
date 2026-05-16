-- LintOnChange Extension: auto-lint buffers on file events.
-- Hooks BufWritePost, BufReadPost, and InsertLeave with debounce.
-- Calls buffer:lint() when the auto_linting toggle is enabled.
-- Replaces the lint-on-event wiring that was previously in nvim-lint config.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Timer = require 'ide.Timer'

local LintOnChange = Class('LintOnChange', Extension)

function LintOnChange:init()
    Extension.init(self, 'LintOnChange')
    self._debounced_lint = nil
end

function LintOnChange:on_register(ctx)
    local ext = self

    ctx:toggle('auto_linting', {
        desc = 'Lint on change',
        default = true,
    })

    -- Create debounced lint function (150ms delay)
    self._debounced_lint = Timer.debounce(150, function(bufnr)
        if not IDE.config:is_enabled('auto_linting') then return end
        if not Buffer.is_valid(bufnr) then return end

        local buf = Buffer.get(bufnr)
        if not buf:is_normal() then return end
        if buf:is_special() then return end

        buf:lint()
    end)

    -- Lint after saving
    ctx:hook('BufWritePost', function(args)
        ext._debounced_lint(args.buf)
    end, { desc = 'LintOnChange: lint after write' })

    -- Lint when opening a file
    ctx:hook('BufReadPost', function(args)
        ext._debounced_lint(args.buf)
    end, { desc = 'LintOnChange: lint on read' })

    -- Lint when leaving insert mode
    ctx:hook('InsertLeave', function(args)
        ext._debounced_lint(args.buf)
    end, { desc = 'LintOnChange: lint on insert leave' })

    -- Lint on text change (normal mode edits)
    ctx:hook('TextChanged', function(args)
        ext._debounced_lint(args.buf)
    end, { desc = 'LintOnChange: lint on text change' })
end

return LintOnChange
