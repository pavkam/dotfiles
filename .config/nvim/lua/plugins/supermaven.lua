-- AI inline completion via Supermaven (free, fast, 1M token context).
-- Replaced copilot.lua which was disabled. Supermaven provides ghost text suggestions
-- that can be accepted with Tab, cycled with C-n/C-p.
return {
    {
        'supermaven-inc/supermaven-nvim',
        cond = #vim.api.nvim_list_uis() > 0,
        event = 'InsertEnter',
        opts = {
            log_level = 'off',
            disable_inline_completion = false,
            disable_keymaps = true,
        },
        config = function(_, opts)
            require('supermaven-nvim').setup(opts)
        end,
    },
}
