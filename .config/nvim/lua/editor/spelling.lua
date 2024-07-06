local utils = require 'core.utils'
local icons = require 'ui.icons'
local settings = require 'core.settings'
local project = require 'project'

-- TODO: do not try to load dicts for files outside the working repo
--[[
Error executing lua callback: vim/_options.lua:0: E474: Invalid argument
stack traceback:
	[C]: in function 'nvim_set_option_value'
	vim/_options.lua: in function '_set'
	vim/_options.lua: in function '__newindex'
	/Users/alex/.config/nvim/lua/editor/spelling.lua:37: in function 'swap_custom_dictionary'
	/Users/alex/.config/nvim/lua/editor/spelling.lua:81: in function 'callback'
	/Users/alex/.config/nvim/lua/core/utils.lua:196: in function </Users/alex/.config/nvim/lua/core/utils.lua:195>
	[C]: in function 'nvim_exec_autocmds'
	.../neovim/0.10.0/share/nvim/runtime/lua/vim/lsp/client.lua:946: in function '_on_attach'
	.../Cellar/neovim/0.10.0/share/nvim/runtime/lua/vim/lsp.lua:625: in function 'buf_attach_client'
	.../Cellar/neovim/0.10.0/share/nvim/runtime/lua/vim/lsp.lua:252: in function 'lsp_start'
	...local/share/nvim/lazy/copilot.lua/lua/copilot/client.lua:100: in function 'buf_attach'
	...local/share/nvim/lazy/copilot.lua/lua/copilot/client.lua:250: in function ''
	vim/_editor.lua: in function <vim/_editor.lua:0>
        ]]
--

---@class editor.spelling
local M = {}

--- Load a custom dictionary for a given target
---@param target core.utils.Target # the target to load the dictionary for
function M.swap_custom_dictionary(target)
    local path = project.nvim_settings_path(target)

    ---@diagnostic disable-next-line: undefined-field
    local current_file = vim.opt.spellfile:get()[1] or nil

    if not path then
        if current_file then
            utils.hint 'Disabling custom spelling dictionary'
        end

        vim.opt.spellfile = nil
        return
    end

    ---@type string
    local base_lang = vim.opt.spelllang:get()[1] or 'en'

    ---@type string|nil
    local spl_file = utils.join_paths(path, base_lang .. '.add')

    if current_file == spl_file then
        return
    end

    utils.hint(string.format('Selecting spelling dictionary to "%s" for buffer', project.format_relative(spl_file)))
    vim.opt.spellfile = spl_file
end

settings.register_toggle('spelling', function(enabled)
    ---@diagnostic disable-next-line: undefined-field
    vim.opt.spell = enabled

    local all = vim.lsp.get_clients { name = 'typos_lsp' }
    if #all == 1 then
        local client = all[1]
        if enabled then
            vim.lsp.buf_attach_client(0, client.id)
        else
            vim.lsp.stop_client(client.id, true)
        end
    end

    ---@diagnostic disable-next-line: undefined-field
end, { name = icons.UI.SpellCheck .. ' Spell checking', default = vim.opt.spell:get(), scope = 'global' })

utils.on_event({ 'BufWinEnter' }, function(evt)
    local ignored_fts = { '', 'neo-tree' }
    local win = vim.api.nvim_get_current_win()

    if
        utils.is_special_buffer(evt.buf)
        and not vim.tbl_contains(ignored_fts, vim.api.nvim_get_option_value('filetype', { buf = evt.buf }))
    then
        vim.wo[win].spell = false
    end
end)

utils.on_event('FileType', function(evt)
    if utils.is_special_buffer(evt.buf) then
        vim.opt_local.spell = false
    elseif
        utils.is_transient_buffer(evt.buf)
        or vim.api.nvim_get_option_value('filetype', { buf = evt.buf }) == 'markdown'
    then
        vim.opt_local.spell = true
    end
end)

utils.on_event({ 'UIEnter', 'LspAttach', 'LspDetach' }, function()
    M.swap_custom_dictionary()
end)

utils.on_focus_gained(function()
    M.swap_custom_dictionary()
end)

--- Mark a word as good or bad in the global dictionary
---@param good boolean # whether the word is good or bad
local function mark_global(good)
    ---@diagnostic disable-next-line: undefined-field
    local current = vim.opt.spellfile:get()
    vim.opt.spellfile = {}

    local fn = good and vim.cmd.spellgood or vim.cms.spellbad
    fn(vim.fn.expand '<cword>')

    vim.opt.spellfile = current
end

--- Mark a word as good or bad in the global dictionary
---@param good boolean # whether the word is good or bad
local function mark_local(good)
    ---@diagnostic disable-next-line: undefined-field
    local file = vim.opt.spellfile:get()[vim.v.count1]

    -- ensure the path to the file exists
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':h'), 'p')

    local fn = good and vim.cmd.spellgood or vim.cms.spellbad
    fn(vim.fn.expand '<cword>')
end

vim.keymap.set('n', 'zg', function()
    mark_local(true)
end, { desc = 'Add word to the global dictionary' })

vim.keymap.set('n', 'zG', function()
    mark_global(true)
end, { desc = 'Add word to the global dictionary' })

vim.keymap.set('n', 'zw', function()
    mark_local(true)
end, { desc = 'Add word to the global dictionary' })

vim.keymap.set('n', 'zW', function()
    mark_global(false)
end, { desc = 'Mark word as bad in the global dictionary' })

return M
