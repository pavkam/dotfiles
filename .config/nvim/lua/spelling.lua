local events = require 'events'
local keys = require 'keys'
local icons = require 'icons'
local settings = require 'settings'
local project = require 'project'

---@class editor.spelling
local M = {}

--- Load a custom dictionary for a given target
---@param target vim.fn.Target # the target to load the dictionary for
function M.swap_custom_dictionary(target)
    local path = project.nvim_settings_path(target)

    ---@diagnostic disable-next-line: undefined-field
    local current_file = vim.opt_local.spellfile:get()[1] or nil

    if not path then
        if current_file then
            vim.hint 'Disabling custom spelling dictionary'
        end

        vim.opt_local.spellfile = nil
        return
    end

    ---@type string
    local base_lang = vim.opt_local.spelllang:get()[1] or 'en'

    ---@type string|nil
    local spl_file = vim.fs.joinpath(path, base_lang .. '.add')

    if current_file == spl_file then
        return
    end

    vim.hint(string.format('Selecting spelling dictionary to `%s` for buffer', project.format_relative(spl_file)))
    vim.opt_local.spellfile = spl_file
end

-- if vim.has_plugin 'nvim-lspconfig' then
--     local lspconfig = require 'lspconfig'
--     if lspconfig.typos_lsp then
--         lspconfig.typos_lsp.setup {
--             ---@param client vim.lsp.Client
--             ---@param buffer integer
--             on_attach = function(client, buffer)
--                 if not settings.get_toggle 'spelling' then
--                     vim.lsp.buf_detach_client(buffer, client.id)
--                 end
--             end,
--         }
--     end
-- end

--- Toggle the typos lsp client
---@param enabled boolean # whether the client should be enabled or disabled
local function toggle_typos_lsp(enabled)
    local all = vim.lsp.get_clients { name = 'typos_lsp' }
    if #all == 1 then
        local client = all[1]

        for _, buffer in ipairs(vim.buf.get_listed_buffers { loaded = true, listed = true }) do
            if enabled then
                vim.lsp.buf_attach_client(buffer, client.id)
            else
                vim.lsp.buf_detach_client(buffer, client.id)
            end
        end
    end
end

settings.register_toggle('spelling', function(enabled)
    ---@diagnostic disable-next-line: undefined-field
    vim.opt.spell = enabled

    toggle_typos_lsp(enabled)
    ---@diagnostic disable-next-line: undefined-field
end, { icon = icons.UI.SpellCheck, name = 'Spell checking', default = vim.opt.spell:get(), scope = 'global' })

events.on_event({ 'BufWinEnter' }, function(evt)
    local ignored_fts = { '', 'neo-tree' }
    local win = vim.api.nvim_get_current_win()

    if
        vim.buf.is_special(evt.buf)
        and not vim.tbl_contains(ignored_fts, vim.api.nvim_get_option_value('filetype', { buf = evt.buf }))
    then
        vim.wo[win].spell = false
    end
end)

events.on_event('FileType', function(evt)
    if vim.buf.is_special(evt.buf) then
        vim.opt_local.spell = false
    elseif
        vim.buf.is_transient(evt.buf)
        or vim.api.nvim_get_option_value('filetype', { buf = evt.buf }) == 'markdown'
    then
        vim.opt_local.spell = true
    end
end)

events.on_event({ 'UIEnter', 'LspAttach', 'LspDetach' }, function()
    vim.schedule(M.swap_custom_dictionary)
end)

events.on_focus_gained(function()
    vim.schedule(M.swap_custom_dictionary)
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

keys.map('n', 'zg', function()
    mark_local(true)
end, { desc = 'Add word to the global dictionary' })

keys.map('n', 'zG', function()
    mark_global(true)
end, { desc = 'Add word to the global dictionary' })

keys.map('n', 'zw', function()
    mark_local(true)
end, { desc = 'Add word to the global dictionary' })

keys.map('n', 'zW', function()
    mark_global(false)
end, { desc = 'Mark word as bad in the global dictionary' })

return M
