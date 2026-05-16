-- Snippets extension: native vim.snippet navigation with AI fallback.
-- Replaces LuaSnip with Neovim 0.12's built-in snippet system.
-- LSP servers provide snippets natively — no extra snippet packages needed.

local Extension = require 'ide.Extension'

local Snippets = Class('Snippets', Extension)

function Snippets:init()
    Extension.init(self, 'Snippets')
end

function Snippets:on_register(ctx)
    -- C-l: jump forward in snippet, or accept AI suggestion
    ctx:keymap({ 'i', 's' }, '<C-l>', function()
        if vim.snippet.active({ direction = 1 }) then
            vim.snippet.jump(1)
        else
            local ok, api = pcall(require, 'supermaven-nvim.completion_preview')
            if ok and api then pcall(api.on_accept_suggestion) end
        end
    end, { desc = 'Snippet jump / accept suggestion' })

    -- C-h: jump backward in snippet
    ctx:keymap({ 'i', 's' }, '<C-h>', function()
        if vim.snippet.active({ direction = -1 }) then
            vim.snippet.jump(-1)
        end
    end, { desc = 'Jump backward in snippet' })

    -- C-j: accept AI word suggestion (no snippet choice in native system)
    ctx:keymap({ 'i', 's' }, '<C-j>', function()
        local ok, api = pcall(require, 'supermaven-nvim.completion_preview')
        if ok and api then pcall(api.on_accept_word) end
    end, { desc = 'Accept word suggestion' })
end

return Snippets
