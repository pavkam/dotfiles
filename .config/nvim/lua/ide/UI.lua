-- UI: unified user interface abstraction.
-- Internalizes noice, telescope, dressing, notify into
-- a single coherent API. No plugin details leak to the consumer.
--
-- Usage:
--   ui:notify('hello')
--   ui.finder:files()
--   ui.tree:toggle()
--   ui:confirm('Delete?', function(yes) ... end)

local Notify = require 'ide.Notify'
local Finder = require 'ide.Finder'
local FileTree = require 'ide.FileTree'

local UI = Class('UI')

function UI:init()
    self._notify = Notify()
    self.finder = Finder()
    self.tree = FileTree()

    -- Override vim.ui with TurboVision dialogs
    local ui = self
    vim.ui.select = function(items, opts, on_choice)
        ui:select(items, opts, on_choice)
    end
    vim.ui.input = function(opts, on_confirm)
        ui:input(opts and opts.prompt or 'Input', on_confirm, { default = opts and opts.default })
    end
end

-- Notifications (delegates to Notify)

---@param msg string
---@param opts { title?: string }|nil
function UI:info(msg, opts) self._notify:info(msg, opts) end

---@param msg string
---@param opts { title?: string }|nil
function UI:warn(msg, opts) self._notify:warn(msg, opts) end

---@param msg string
---@param opts { title?: string }|nil
function UI:error(msg, opts) self._notify:error(msg, opts) end

---@param msg string
---@param opts { title?: string }|nil
function UI:debug(msg, opts) self._notify:debug(msg, opts) end

-- Input/selection (uses vim.ui which dressing.nvim enhances)

--- Prompt for text input.
---@param prompt string
---@param callback fun(input: string|nil)
---@param opts { default?: string }|nil
function UI:input(prompt, callback, opts)
    opts = opts or {}
    local Dialog = require 'ide.toolkit.Dialog'
    local InputField = require 'ide.toolkit.InputField'
    local Button = require 'ide.toolkit.Button'

    local width = math.max(40, #(prompt or '') + 10)
    local dlg = Dialog({
        title = prompt or 'Input',
        width = width,
        height = 5,
        shadow = true,
    })

    local input = InputField({
        prompt = '',
        initial = opts.default or '',
        on_submit = function(text)
            dlg:close()
            if callback then vim.schedule(function() callback(text) end) end
        end,
        on_cancel = function()
            dlg:close()
            if callback then vim.schedule(function() callback(nil) end) end
        end,
    })

    local input_buf = input:create_buffer()
    dlg:add_widget(input, 2, 2)

    dlg:add_widget(Button({
        label = '&OK',
        style = 'primary',
        action = function()
            local text = input:get_text()
            dlg:close()
            if callback then vim.schedule(function() callback(text) end) end
        end,
    }), 4, math.floor(width / 2) - 8)

    dlg:add_widget(Button({
        label = '&Cancel',
        action = function()
            dlg:close()
            if callback then vim.schedule(function() callback(nil) end) end
        end,
    }), 4, math.floor(width / 2) + 2)

    dlg:show()

    -- Focus the input field buffer and enter insert mode
    if input_buf and vim.api.nvim_buf_is_valid(input_buf:id()) then
        local wins = vim.fn.win_findbuf(input_buf:id())
        if #wins > 0 then
            vim.api.nvim_set_current_win(wins[1])
            vim.cmd('startinsert!')
        end
    end
end

--- Prompt for confirmation with a TurboVision dialog.
---@param question string
---@param callback fun(confirmed: boolean)
function UI:confirm(question, callback)
    local Dialog = require 'ide.toolkit.Dialog'
    local Button = require 'ide.toolkit.Button'
    local Canvas = require 'ide.toolkit.Canvas'

    local width = math.max(36, #question + 8)
    local dlg = Dialog({
        title = 'Confirm',
        width = width,
        height = 5,
        shadow = true,
    })

    -- Question text as a simple widget stub
    local label = { focusable = function() return false end }
    function label:render()
        return '  ' .. question, {{ group = 'IDEDialogNormal', col_start = 0, col_end = #question + 2 }}
    end
    dlg:add_widget(label, 2, 1)

    dlg:add_widget(Button({
        label = '&Yes',
        style = 'primary',
        action = function()
            dlg:close()
            if callback then vim.schedule(function() callback(true) end) end
        end,
    }), 4, math.floor(width / 2) - 8)

    dlg:add_widget(Button({
        label = '&No',
        action = function()
            dlg:close()
            if callback then vim.schedule(function() callback(false) end) end
        end,
    }), 4, math.floor(width / 2) + 2)

    dlg:show()
end

--- Select from a list of items with a TurboVision picker.
---@generic T
---@param items T[]
---@param opts { prompt?: string, format_item?: fun(item: T): string }
---@param callback fun(item: T|nil, idx: integer|nil)
function UI:select(items, opts, callback)
    opts = opts or {}
    if #items == 0 then
        if callback then callback(nil, nil) end
        return
    end

    local Picker = require 'ide.toolkit.Picker'
    Picker({
        title = opts.prompt or '  Select',
        items = items,
        format = opts.format_item or function(item)
            return type(item) == 'string' and item or tostring(item)
        end,
        on_select = function(item, idx)
            if callback then callback(item, idx) end
        end,
    }):show()
end

-- Highlight creation

--- Create a highlight group builder.
---@param name string
---@return Highlight
function UI:highlight(name)
    return require('ide.Highlight')(name)
end

--- Show a message in the command line area.
---@param text string
---@param hl_group string|nil
function UI:echo(text, hl_group)
    vim.api.nvim_echo({ { text, hl_group or 'Normal' } }, false, {})
end

--- Read a single character from user input.
---@return string|nil # the character, or nil on Esc/cancel
function UI:getchar()
    local ok, char = pcall(vim.fn.getcharstr)
    if not ok or char == '\27' then return nil end
    return char
end

--- Get the current editor mode.
---@return { mode: string, blocking: boolean }
function UI:mode()
    return vim.api.nvim_get_mode()
end

--- Check if the editor is currently in visual mode.
---@return boolean
function UI:is_visual_mode()
    local m = self:mode().mode
    return m == 'v' or m == 'V' or m == '\22'
end

--- Feed keys to the editor (replaces vim.api.nvim_feedkeys).
---@param keys string # key sequence (may contain special key codes like <CR>)
---@param mode string # feedkeys mode ('n' = noremap, 'm' = remap, etc.)
function UI:feedkeys(keys, mode)
    vim.api.nvim_feedkeys(keys, mode or 'n', false)
end

--- Translate a key code byte to a human-readable key name (e.g. '\r' → '<CR>').
---@param key string # raw key byte
---@return string # human-readable key name
function UI:key_name(key)
    return vim.fn.keytrans(key)
end

--- Translate terminal key codes (replaces vim.api.nvim_replace_termcodes).
---@param keys string # key sequence with <...> notation
---@return string # translated key codes
function UI:translate_keys(keys)
    return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

--- Insert an undo breakpoint while in insert mode.
---@return boolean # true if undo point was created (i.e. was in insert mode)
function UI:insert_undo_point()
    if self:mode().mode ~= 'i' then return false end
    self:feedkeys(self:translate_keys('<c-G>u'), 'n')
    return true
end

--- Lightweight screen refresh (redraws the display).
function UI:refresh()
    vim.cmd.redraw()
end

--- Get the content of a named register.
---@param name string # register name (e.g. 'a', '+', '"')
---@return string
function UI:get_register(name)
    return vim.fn.getreg(name)
end

--- Set the content of a named register.
---@param name string # register name
---@param value string # content to store
function UI:set_register(name, value)
    vim.fn.setreg(name, value)
end

--- Check if the wildmenu (command completion) is active.
---@return boolean
function UI:is_wildmenu_active()
    return vim.fn.wildmenumode() == 1
end

--- Get the word under the cursor.
---@return string
function UI:word_under_cursor()
    return vim.fn.expand('<cword>')
end

--- Paste lines of text after the cursor.
---@param lines string[]
function UI:paste_lines(lines)
    vim.api.nvim_put(lines, 'l', true, true)
end

--- Copy text to the system clipboard.
---@param text string
function UI:copy_to_clipboard(text)
    vim.fn.setreg('+', text)
end

--- Refresh the statusline/tabline/winbar.
function UI:refresh_status()
    pcall(vim.cmd, 'redrawstatus')
end

--- Redraw the tabline.
function UI:redraw_tabline()
    pcall(vim.cmd, 'redrawtabline')
end

--- Register a command-line abbreviation (e.g. typo correction).
---@param from string
---@param to string
function UI:abbreviate(from, to)
    vim.cmd.cnoreabbrev(from, to)
end

--- Get the register currently being recorded into (empty string if not recording).
---@return string
function UI:recording_register()
    return vim.fn.reg_recording()
end

--- Clear search highlighting.
function UI:clear_search_highlight()
    vim.cmd.nohlsearch()
end

--- Save the current view (folds, cursor, etc.) silently.
function UI:save_view()
    vim.cmd.mkview { mods = { emsg_silent = true } }
end

--- Restore a previously saved view silently.
function UI:restore_view()
    vim.cmd.loadview { mods = { emsg_silent = true } }
end

--- Check if open buffers were modified externally.
function UI:checktime()
    vim.cmd.checktime()
end

--- Highlight yanked text briefly.
function UI:highlight_yank()
    vim.hl.on_yank()
end

--- Exit insert mode.
function UI:stop_insert()
    vim.cmd.stopinsert()
end

--- Remove all items from the default right-click popup menu.
function UI:clear_popup_menu()
    pcall(vim.cmd, 'silent! aunmenu PopUp')
end

--- Redraw the entire UI.
function UI:redraw()
    vim.cmd 'resize'
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. vim.fn.tabpagenr())
    vim.cmd 'redraw!'
end

--- Hide the cursor (reference-counted — nested calls are safe).
--- Call restore_cursor() to undo. If hide is called 3 times,
--- restore must be called 3 times to actually show the cursor.
---@param hl_group? string # highlight group for hidden cursor (default: IDEPanelHiddenCursor)
function UI:hide_cursor(hl_group)
    hl_group = hl_group or 'IDEPanelHiddenCursor'
    self._cursor_hide_count = (self._cursor_hide_count or 0) + 1
    if self._cursor_hide_count == 1 then
        self._saved_guicursor = vim.o.guicursor
        vim.o.guicursor = 'a:' .. hl_group .. '/' .. hl_group
    end
end

--- Restore the cursor (reference-counted).
function UI:restore_cursor()
    self._cursor_hide_count = math.max(0, (self._cursor_hide_count or 0) - 1)
    if self._cursor_hide_count == 0 and self._saved_guicursor then
        vim.o.guicursor = self._saved_guicursor
        self._saved_guicursor = nil
    end
end

--- Force-restore cursor regardless of ref count (emergency cleanup).
function UI:force_restore_cursor()
    self._cursor_hide_count = 0
    if self._saved_guicursor then
        vim.o.guicursor = self._saved_guicursor
        self._saved_guicursor = nil
    end
end

---@return string
function UI:__tostring()
    return 'UI()'
end

return UI
