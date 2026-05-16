-- Markdown Preview Extension: side-by-side markdown preview.
-- Pure implementation using treesitter highlighting.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local MarkdownPreview = Class('MarkdownPreview', Extension)

function MarkdownPreview:init()
    Extension.init(self, 'MarkdownPreview')
    self._preview_buf = nil
    self._preview_win = nil
    self._source_buf = nil
end

local function format_lines(lines)
    local result = {}
    for _, line in ipairs(lines) do
        if line:match('^#') then
            result[#result + 1] = ''
            result[#result + 1] = line
            result[#result + 1] = string.rep('─', math.min(#line * 2, 80))
        else
            result[#result + 1] = line
        end
    end
    return result
end

function MarkdownPreview:open()
    local source = Buffer.current()
    if source:filetype() ~= 'markdown' then
        IDE.ui:warn('Not a markdown file')
        return
    end
    self._source_buf = source:id()

    local lines = source:lines(0, -1)

    if not self._preview_buf or not Buffer.is_valid(self._preview_buf) then
        local preview = Buffer.create({ listed = false, scratch = true })
        self._preview_buf = preview:id()
    end

    local preview = Buffer.get(self._preview_buf)
    preview:set_lines(0, -1, format_lines(lines))
    preview:set_option('filetype', 'markdown')
    preview:set_option('modifiable', false)
    preview:set_option('buftype', 'nofile')

    local source_win = Window.current()
    if not self._preview_win or not Window.is_valid(self._preview_win) then
        local new_win = source_win:split('vertical')
        self._preview_win = new_win:id()
    end

    local preview_win = Window.get(self._preview_win)
    if not preview_win then return end
    preview_win:set_buffer(preview)
    preview_win:set_option('wrap', true)
    preview_win:set_option('number', false)
    preview_win:set_option('relativenumber', false)
    preview_win:set_option('signcolumn', 'no')

    IDE.treesitter:start(self._preview_buf, 'markdown')
    source_win:focus()
end

function MarkdownPreview:close()
    local win = self._preview_win and Window.get(self._preview_win)
    if win and win:is_valid() then
        win:close(true)
    end
    self._preview_win = nil
    local buf = self._preview_buf and Buffer.get(self._preview_buf)
    if buf and buf:is_valid() then
        buf:close(true)
    end
    self._preview_buf = nil
end

function MarkdownPreview:toggle()
    if self._preview_win and Window.is_valid(self._preview_win) then
        self:close()
    else
        self:open()
    end
end

---@param ctx ExtensionContext
function MarkdownPreview:on_register(ctx)
    local self_ref = self

    ctx:command('IDEPreview', function()
        self_ref:toggle()
    end, { desc = 'Toggle markdown preview' })

    ctx:keymap('n', '<leader>p', function()
        self_ref:toggle()
    end, { desc = 'Toggle markdown preview' })

    ctx:hook('BufWritePost', function(args)
        if self_ref._source_buf == args.buf and self_ref._preview_buf
            and Buffer.is_valid(self_ref._preview_buf) then
            local source = Buffer.get(args.buf)
            local preview = Buffer.get(self_ref._preview_buf)
            local lines = source:lines(0, -1)
            preview:set_option('modifiable', true)
            preview:set_lines(0, -1, format_lines(lines))
            preview:set_option('modifiable', false)
        end
    end, { desc = 'MarkdownPreview: auto-update on save' })
end

function MarkdownPreview:on_unregister()
    self:close()
end

return MarkdownPreview
