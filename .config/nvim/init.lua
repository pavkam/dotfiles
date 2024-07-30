-- TODO: figure out why TODOs don't get highlighted
-- URGENT: not sure why session fails to restore when closing file with error
-- TODO: the typos lsp is not dying correctly when disabled
-- URGENT: Note function do not work,
-- URGENT: sesh command does not properly handle names in panes and also not switching folders
-- URGENT: remove the code that tracks invalid LSP situation
-- TODO: fixwin fails in many cases, probably need to be very specific,
-- TODO: Alpha appears when it should not
-- TODO: the file palette is crap
-- MAYBE: Cross-tmux-session marks
-- MAYBE: show the number of failed/total tests in the status-line

--- Global function to quit the current process
_G.quit = function()
    vim.api.nvim_command 'cq1'
end

--- Global debug function to help me debug (duh)
---@vararg any anything to debug
_G.dbg = function(...)
    local objects = {}
    for _, v in pairs { ... } do
        ---@type string
        local val = 'nil'

        if type(v) == 'string' then
            val = v
        elseif type(v) == 'number' or type(v) == 'boolean' then
            val = tostring(v)
        elseif type(v) == 'table' then
            val = vim.inspect(v)
        end

        table.insert(objects, val)
    end

    local message = table.concat(objects, '\n')

    vim.notify(message)

    return ...
end

--- Prints the call stack if a condition is met
--- @param cond boolean|nil # the condition to print the call stack
_G.who = function(cond)
    if cond == nil or cond then
        dbg(debug.traceback(2))
    end
end

--- Global function to log a message as an error and quit
---@param message string the message to log
_G.fatal = function(message)
    assert(type(message) == 'string')

    error(string.format('fatal error has occurred: %s', message))
    error 'press any key to quit the process'

    vim.fn.getchar()

    vim.api.nvim_command 'cq1'
end

if not vim.fn.executable 'git' then
    fatal 'git required'
    return
end

if not vim.fn.has 'nvim-0.10' then
    fatal 'minimum required Neovim version is 0.10'
    return
end

local modules = {
    'core',
    'ui',
    'editor',
    'testing',
    'git',
    'project',
    'debugging',
    'formatting',
    'linting',
    'extras',
}

require 'core.options'

-- Setup the Lazy plugin manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system {
        'git',
        'clone',
        '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git',
        '--branch=stable', -- latest stable release
        lazypath,
    }
end

---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

local config_path = vim.fn.stdpath 'config'

---@type string[]
local plugin_dirs = vim.iter(modules)
    :map(
        ---@param module string
        function(module)
            return module .. '/plugins'
        end
    )
    :filter(
        ---@param dir string
        function(dir)
            return vim.fn.isdirectory(config_path .. '/lua/' .. dir) == 1
        end
    )
    :totable()

require('lazy').setup {
    spec = vim.iter(plugin_dirs)
        :map(
            ---@param dir string
            function(dir)
                return { import = dir }
            end
        )
        :totable(),
    defaults = {
        lazy = true,
        version = false,
    },
    ui = {
        border = vim.g.border_style,
    },
    checker = {
        enabled = true,
        notify = false,
    },
    install = {
        colorscheme = { 'tokyonight' },
    },
    performance = {
        rtp = {
            disabled_plugins = {
                'rplugin',
                'matchit',
                'netrwPlugin',
                'man',
                'tutor',
                'health',
                'tohtml',
                'gzip',
                'zipPlugin',
                'tarPlugin',
            },
        },
    },
}

--- Load all modules
---@type table<string, any>
local load_errors = {}
for _, module in ipairs(modules) do
    local ok, err = pcall(require, module)

    if not ok then
        load_errors[module] = err
    end
end

-- For any errors, print them out after the editor has started
if next(load_errors) then
    vim.api.nvim_create_autocmd('User', {
        pattern = 'LazyVimStarted',
        callback = function()
            for module, err in pairs(load_errors) do
                vim.api.nvim_err_writeln('Error loading "' .. module .. '": ' .. vim.inspect(err))
            end
        end,
    })
end

-- open neo-tree if opening a directory
local opening_a_dir = vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0) --[[@as string]]) == 1
if opening_a_dir then
    vim.api.nvim_create_autocmd('User', {
        pattern = 'LazyVimStarted',
        callback = function()
            require 'neo-tree'
        end,
    })
end
