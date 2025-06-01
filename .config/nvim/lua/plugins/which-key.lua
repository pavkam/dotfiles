return {
    'folke/which-key.nvim',
    cond = not ide.process.is_headless,
    event = 'VeryLazy',
    opts = {
        preset = 'helix',
        plugins = { spelling = false },
        triggers = {
            { '<auto>', mode = 'nisoc' },
            { 'a', mode = 'v' },
            { 'i', mode = 'v' },
            { 'g', mode = 'v' },
            { 'z', mode = 'v' },
            { '<leader>', mode = 'v' },
        },
        icons = {
            group = '',
        },
    },
    init = function()
        ---@module 'which-key'
        local which_key = xrequire 'which-key'

        ide.plugin.keymap.register {
            set = function(keymap, action, opts)
                ---@type keymap_plugin_set_options
                opts = table.merge(opts, {
                    mode = 'n',
                    silent = false,
                    returns_expr = false,
                    no_remap = false,
                    no_wait = false,
                })

                xassert {
                    keymap = {
                        keymap,
                        { 'string', ['>'] = 0 },
                    },
                    action = {
                        action,
                        {
                            { 'string', ['>'] = 0 },
                            'callable',
                        },
                    },
                    opts = {
                        opts,
                        {
                            mode = {
                                { 'string', ['='] = 1 },
                                {
                                    'list',
                                    ['>'] = 0,
                                    ['*'] = {
                                        'string',
                                        ['='] = 1,
                                    },
                                },
                            },
                            buffer = { 'nil', 'table' }, -- TODO: better type check
                            silent = 'boolean',
                            returns_expr = 'boolean',
                            no_remap = 'boolean',
                            no_wait = 'boolean',
                            desc = { 'nil', 'string' },
                            icon = { 'nil', 'table' }, -- TODO: better type check
                        },
                    },
                }

                which_key.add {
                    keymap,
                    action,
                    desc = opts.desc,
                    icon = opts.icon and opts.icon.symbol or nil,
                    silent = opts.silent,
                    expr = opts.returns_expr,
                    noremap = opts.no_remap,
                    nowait = opts.no_wait,
                    buffer = opts.buffer and opts.buffer.id or nil,
                    mode = opts.mode,
                }
            end,
            prefix = function(prefix, opts)
                ---@type keymap_plugin_prefix_options
                opts = table.merge(opts, {
                    mode = 'n',
                })

                xassert {
                    prefix = {
                        prefix,
                        { 'string', ['>'] = 0 },
                    },
                    opts = {
                        opts,
                        {
                            mode = {
                                { 'string', ['='] = 1 },
                                {
                                    'list',
                                    ['>'] = 0,
                                    ['*'] = {
                                        'string',
                                        ['='] = 1,
                                    },
                                },
                            },
                            buffer = { 'nil', 'table' }, -- TODO: better type check
                            desc = { 'nil', 'string' },
                            icon = { 'nil', 'table' }, -- TODO: better type check
                        },
                    },
                }

                which_key.add {
                    prefix,
                    mode = opts.mode,
                    group = opts.desc,
                    icon = opts.icon and opts.icon.symbol or nil,
                    buffer = opts.buffer and opts.buffer.id or nil,
                }
            end,
        }
    end,
}
