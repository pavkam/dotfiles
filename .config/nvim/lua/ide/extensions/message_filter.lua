-- MessageFilter Extension: suppress noisy vim messages.
-- Replaces noice.nvim's message routing with a vim.notify override
-- that filters common noise and routes to the notification system.

local Extension = require 'ide.Extension'

local MessageFilter = Class('MessageFilter', Extension)

function MessageFilter:init()
    Extension.init(self, 'MessageFilter')
    self._orig_notify = nil
    self._orig_stylize = nil
end

-- Patterns to suppress (show briefly in echo area)
local SUPPRESS_PATTERNS = {
    '%d+L, %d+B',
    '; after #%d+',
    '; before #%d+',
    '%d+ fewer lines',
    '%d+ lines changed',
    '%d+ more lines',
    '%d+ lines yanked',
    'search hit %a+, continuing at %a+',
    '%d+ lines <ed %d+ time',
    '%d+ lines >ed %d+ time',
    '%d+ substitutions on %d+ lines',
    'Hunk %d+ of %d+',
    '%-%-No lines in buffer%-%-',
    '^E486: Pattern not found',
    '^Word .*%.add$',
    'E490: No fold found',
    'No more valid diagnostics to move to',
    'No code actions available',
    '^Already at %a+ change',
    '^E553',
    '^E776',
    '^E348',
    '^W325',
    '^E1513',
}

-- Patterns to skip entirely
local SKIP_PATTERNS = {
    '^[/?].',
    '^%s*at process.processTicksAndRejections',
}

function MessageFilter:on_register(ctx)
    self._orig_notify = vim.notify
    self._orig_stylize = vim.lsp.util.stylize_markdown

    local orig = self._orig_notify

    vim.notify = function(msg, level, opts)
        if type(msg) ~= 'string' then
            return orig(msg, level, opts)
        end

        for _, pat in ipairs(SKIP_PATTERNS) do
            if msg:find(pat) then return end
        end

        for _, pat in ipairs(SUPPRESS_PATTERNS) do
            if msg:find(pat) then
                if IDE and IDE.ui then
                    IDE.ui:echo(msg, 'Comment')
                end
                return
            end
        end

        if opts and opts.title then
            if opts.title == 'package-info.nvim' then return end
            if opts.title == 'mason' then
                if IDE and IDE.ui then IDE.ui:echo(msg, 'Comment') end
                return
            end
        end

        orig(msg, level, opts)
    end

    vim.lsp.util.stylize_markdown = function(bufnr, contents, opts_inner)
        opts_inner = opts_inner or {}
        opts_inner.max_width = opts_inner.max_width or 80
        return self._orig_stylize(bufnr, contents, opts_inner)
    end
end

function MessageFilter:on_unregister()
    if self._orig_notify then
        vim.notify = self._orig_notify
        self._orig_notify = nil
    end
    if self._orig_stylize then
        vim.lsp.util.stylize_markdown = self._orig_stylize
        self._orig_stylize = nil
    end
end

return MessageFilter
