---@class (exact) ts_error_translator_config
---@field auto_override_publish_diagnostics boolean: Enable the plugin

-- TODO: trialling
return {
    'dmmulroy/ts-error-translator.nvim',
    lazy = false,
    ---@type ts_error_translator_config
    opts = {
        auto_override_publish_diagnostics = true,
    },
}
