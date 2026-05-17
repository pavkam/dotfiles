-- SelectPicker: general-purpose item selection dialog.
-- Extends SearchableList with fuzzy filtering over a static item list.

local SearchableList = require 'ide.toolkit.SearchableList'

local SelectPicker = Class('SelectPicker', SearchableList)

---@param opts { title?: string, items: table[], on_select?: fun(item: table), width?: number, height?: number }
function SelectPicker:init(opts)
    opts = opts or {}
    local item_count = #opts.items
    SearchableList.init(self, {
        title = opts.title or '  Select',
        width = opts.width or 0.4,
        height = opts.height or math.min(item_count + 4, 20),
        on_select = opts.on_select,
    })
    self._all_items = opts.items
    self._filtered = opts.items
end

function SelectPicker:items()
    return self._filtered
end

function SelectPicker:total_count()
    return #self._all_items
end

function SelectPicker:on_query_change(query)
    if query == '' then
        self._filtered = self._all_items
    else
        local q = query:lower()
        -- Try fuzzy scoring (FuzzyScorer uses fzf-native FFI when available)
        local fuzzy = self._fuzzy
        if not fuzzy then
            local ok, FuzzyScorer = pcall(require, 'ide.FuzzyScorer')
            if ok then
                fuzzy = FuzzyScorer()
                self._fuzzy = fuzzy
            end
        end
        local use_fuzzy = fuzzy and fuzzy:is_available()
        local scored = {}
        for _, item in ipairs(self._all_items) do
            local text = (item.text or item.name or tostring(item)):lower()
            local score = 0
            if use_fuzzy then
                score = fuzzy:score(text, query)
            end
            if score > 0 then
                scored[#scored + 1] = { item = item, score = score }
            elseif text:find(q, 1, true) then
                scored[#scored + 1] = { item = item, score = 1 }
            end
        end
        table.sort(scored, function(a, b) return a.score > b.score end)
        self._filtered = {}
        for _, s in ipairs(scored) do
            self._filtered[#self._filtered + 1] = s.item
        end
    end
    self._selected = 1
    self._scroll = 0
end

function SelectPicker:render_item(item, width)
    local icon_part = item.icon and (item.icon .. ' ') or '  '
    local text = item.text or item.name or tostring(item)
    local children = {
        { type = 'text', text = icon_part },
        { type = 'text', text = text },
    }
    if item.hint and item.hint ~= '' then
        local sw = vim.api.nvim_strwidth
        local pad = math.max(1, width - sw(icon_part) - sw(text) - sw(item.hint) - 5)
        children[#children + 1] = { type = 'text', text = string.rep(' ', pad) }
        children[#children + 1] = { type = 'text', text = item.hint, hl = 'Comment' }
    end
    return children
end

function SelectPicker:__tostring()
    return string.format('SelectPicker(%s, %d items)', self._title, #self._all_items)
end

return SelectPicker
