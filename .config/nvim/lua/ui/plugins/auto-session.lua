return {
    'rmagatti/auto-session',
    event = 'User LazyDone',
    opts = {
        log_level = 'error',
        auto_session_suppress_dirs = { '~/', '/' },
        auto_session_enable_last_session = false,
        auto_session_root_dir = vim.fn.stdpath 'data' .. '/sessions/',
        auto_session_enabled = true,
        auto_session_create_enabled = true,
        auto_save_enabled = true,
        auto_restore_enabled = true,
        auto_session_use_git_branch = true,
        -- TODO: can I restore a session on dir/branch change?
        bypass_session_save_file_types = { 'gitcommit', 'gitrebase', 'svn', 'hgcommit' },
        save_extra_cmds = {
            function()
                local settings = require 'core.settings'
                local opts = settings.serialize_to_json()
                local shada_content = settings.serialize_shada_to_base64()

                local code = string.format(
                    ":lua require('core.settings').deserialize_shada_from_base64([[%s]]); require('core.settings').deserialize_from_json([[ %s ]])",
                    shada_content,
                    opts
                )

                return code
            end,
        },
    },
}
