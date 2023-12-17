local utils = require 'core.utils'

-- search
vim.keymap.set({ 'i', 'n' }, '<esc>', '<cmd>nohlsearch<cr><esc>', { desc = 'Escape and clear highlight' })
vim.keymap.set('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next search result' })
vim.keymap.set({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next search result' })
vim.keymap.set('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Previous search result' })
vim.keymap.set({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Previous search result' })
vim.keymap.set('x', '<C-r>', function()
    local selected_text = utils.get_selected_text()
    local command = ':<C-u>%s/\\<' .. selected_text .. '\\>//gI<Left><Left><Left>'
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(command, true, false, true), 'n', false)
end, { desc = 'Replace selection' })
vim.keymap.set('n', '<C-r>', [[:%s/\<<C-r><C-w>\>//gI<Left><Left><Left>]])

-- better search
vim.on_key(function(char)
    if vim.fn.mode() == 'n' then
        local new_hlsearch = vim.tbl_contains({ '<CR>', 'n', 'N', '*', '#', '?', '/' }, vim.fn.keytrans(char))
        if vim.opt.hlsearch:get() ~= new_hlsearch then
            vim.opt.hlsearch = new_hlsearch
        end
    end
end, vim.api.nvim_create_namespace 'auto_hlsearch')
