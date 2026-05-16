-- Feature Toggles Extension: registers IDE-wide toggleable features.
-- Uses ctx:toggle() for automatic cleanup on extension disable.

local Extension = require 'ide.Extension'

local FeatureToggles = Class('FeatureToggles', Extension)

function FeatureToggles:init()
    Extension.init(self, 'FeatureToggles')
end

function FeatureToggles:on_register(ctx)
    ctx:toggle('diagnostics_enabled', {
        desc = 'Diagnostics',
        on_toggle = function(enabled) IDE.lsp:enable_diagnostics(enabled) end,
    })

    ctx:toggle('inlay_hint_enabled', {
        desc = 'Inlay hints',
        default = false,
        on_toggle = function(enabled) IDE.lsp:enable_inlay_hints(enabled) end,
    })

    ctx:toggle('code_lens_enabled', {
        desc = 'Code lens',
        default = false,
        on_toggle = function(enabled) IDE.lsp:enable_codelens(enabled) end,
    })

    ctx:toggle('semantic_tokens_enabled', {
        desc = 'Semantic tokens',
        on_toggle = function(enabled) IDE.lsp:enable_semantic_tokens(enabled) end,
    })

    ctx:toggle('treesitter_enabled', {
        desc = 'Treesitter highlighting',
        on_toggle = function(enabled)
            local buf = IDE.buffers:current()
            if enabled then buf:ast():start() else buf:ast():stop() end
        end,
    })
end

return FeatureToggles
