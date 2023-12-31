return {
    'rmagatti/auto-session',
    cond = feature_level(2),
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
        bypass_session_save_file_types = { 'gitcommit', 'gitrebase', 'svn', 'hgcommit' },
        save_extra_cmds = {
            function()
                local opts = require('core.toggles').serialize()
                return ":lua require('core.toggles').deserialize([[" .. opts .. ']])'
            end,
        },
    },
}
