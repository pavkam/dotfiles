-- AutoTag Extension: auto close and rename HTML/JSX tags.
-- Pure treesitter implementation — no plugin dependency.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Timer = require 'ide.Timer'

local AutoTag = Class('AutoTag', Extension)

function AutoTag:init()
    Extension.init(self, 'AutoTag')
    self._filetypes = {
        html = true, xml = true,
        typescriptreact = true, javascriptreact = true,
        vue = true, svelte = true, astro = true,
    }
end

local void_elements = {
    area = true, base = true, br = true, col = true, embed = true,
    hr = true, img = true, input = true, link = true, meta = true,
    param = true, source = true, track = true, wbr = true,
}

function AutoTag:_close()
    local buf = Buffer.current()
    local cursor = Window.current():cursor()
    local line = buf:line(cursor.row)
    if not line then return end

    local before = line:sub(1, cursor.col - 1)
    local tag = before:match('<(%w[%w%-]*)%s*>$')
    if not tag or void_elements[tag:lower()] then return end

    local after = line:sub(cursor.col)
    if after:match('^%s*</') then return end

    buf:set_text(cursor.row - 1, cursor.col - 1, cursor.row - 1, cursor.col - 1, { '</' .. tag .. '>' })
    Window.current():set_cursor(cursor)
end

function AutoTag:_rename(bufnr)
    local node = IDE.treesitter:node_at_cursor({ bufnr = bufnr })
    if not node then return end

    local tag_node = node
    while tag_node and tag_node:type() ~= 'tag_name' do
        tag_node = tag_node:parent()
        if not tag_node or tag_node:type() == 'element' or tag_node:type():match('_element$') then
            return
        end
    end
    if not tag_node or tag_node:type() ~= 'tag_name' then return end

    local buf = Buffer.get(bufnr)
    local current_name = IDE.treesitter:text_of(tag_node, bufnr)
    local container = tag_node:parent()
    if not container then return end
    local element = container:parent()
    if not element then return end

    for child in element:iter_children() do
        if child ~= container then
            local ctype = child:type()
            if ctype:match('start_tag') or ctype:match('end_tag') or
               ctype:match('opening') or ctype:match('closing') then
                for grandchild in child:iter_children() do
                    if grandchild:type() == 'tag_name' then
                        local other = IDE.treesitter:text_of(grandchild, bufnr)
                        if other ~= current_name then
                            local sr, sc, er, ec = grandchild:range()
                            buf:set_text(sr, sc, er, ec, { current_name })
                        end
                        return
                    end
                end
            end
        end
    end
end

---@param ctx ExtensionContext
function AutoTag:on_register(ctx)
    local self_ref = self

    ctx:hook('FileType', function(args)
        local buf = Buffer.get(args.buf)
        if self_ref._filetypes[buf:filetype()] then
            IDE.keys:map('i', '>', '><cmd>lua IDE:extension("AutoTag"):_close()<cr>', {
                buffer = args.buf,
                noremap = true,
                silent = true,
                desc = 'AutoTag: close tag',
            })
        end
    end, { desc = 'AutoTag: setup buffer keymaps' })

    ctx:hook('InsertLeave', function(args)
        if self_ref._filetypes[Buffer.get(args.buf):filetype()] then
            Timer.defer(function()
                pcall(self_ref._rename, self_ref, args.buf)
            end)
        end
    end, { desc = 'AutoTag: rename matching tag' })

    ctx:notify('AutoTag enabled for HTML/JSX', 'info')
end

return AutoTag
