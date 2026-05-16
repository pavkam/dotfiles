-- WinBar: per-window breadcrumb bar abstraction.
-- Shows file path and treesitter context (current function/class).

local EventEmitter = require 'ide.EventEmitter'

local WinBar = Class('WinBar')
Class.include(WinBar, EventEmitter)

function WinBar:init()
    self._left = {}
    self._right = {}
end

---@param name string
---@param provider fun(): string, string|nil
---@param opts { cond?: fun(): boolean }|nil
---@return WinBar
function WinBar:left(name, provider, opts)
    opts = opts or {}
    self._left[#self._left + 1] = { name = name, provider = provider, cond = opts.cond }
    return self
end

---@param name string
---@param provider fun(): string, string|nil
---@param opts { cond?: fun(): boolean }|nil
---@return WinBar
function WinBar:right(name, provider, opts)
    opts = opts or {}
    self._right[#self._right + 1] = { name = name, provider = provider, cond = opts.cond }
    return self
end

--- Render to native winbar string.
---@return string
function WinBar:render()
    local parts = {}

    for _, s in ipairs(self._left) do
        if not s.cond or s.cond() then
            local text, hl = s.provider()
            if text and text ~= '' then
                parts[#parts + 1] = hl and string.format('%%#%s#%s%%*', hl, text) or text
            end
        end
    end

    parts[#parts + 1] = '%='

    for _, s in ipairs(self._right) do
        if not s.cond or s.cond() then
            local text, hl = s.provider()
            if text and text ~= '' then
                parts[#parts + 1] = hl and string.format('%%#%s#%s%%*', hl, text) or text
            end
        end
    end

    return table.concat(parts, ' ')
end

--- Apply as native winbar.
function WinBar:apply_native()
    local Dispatch = require 'ide.Dispatch'
    Dispatch.renderer('winbar', function() return self:render() end)
    vim.o.winbar = '%!v:lua.IDE_render_winbar()'
end

--- Convert to lualine winbar format.
---@return table
function WinBar:to_lualine()
    local function convert(sections)
        local result = {}
        for _, s in ipairs(sections) do
            result[#result + 1] = {
                function()
                    local text = s.provider()
                    return text or ''
                end,
                cond = s.cond,
            }
        end
        return result
    end

    return {
        lualine_a = {},
        lualine_b = {},
        lualine_c = convert(self._left),
        lualine_x = {},
        lualine_y = convert(self._right),
        lualine_z = {},
    }
end

--- Create a default winbar with file path + treesitter breadcrumbs.
---@return WinBar
function WinBar.default()
    local bar = WinBar()

    -- File path (relative)
    bar:left('filepath', function()
        local path = vim.fn.expand('%:~:.')
        if path == '' then return '' end
        return ' ' .. path, 'Comment'
    end)

    -- Treesitter breadcrumbs
    bar:right('breadcrumbs', function()
        local ok, node = pcall(vim.treesitter.get_node)
        if not ok or not node then return '' end

        local scope_types = {
            function_declaration = true, method_declaration = true,
            method_definition = true, function_definition = true,
            class_definition = true, class_declaration = true,
            type_declaration = true, type_spec = true,
        }

        local parts = {}
        local current = node
        while current do
            if scope_types[current:type()] then
                local name_node = current:field('name')[1]
                if name_node then
                    parts[#parts + 1] = vim.treesitter.get_node_text(name_node, 0)
                end
            end
            current = current:parent()
        end

        if #parts == 0 then return '' end

        local result = {}
        for i = #parts, 1, -1 do
            result[#result + 1] = parts[i]
        end
        return table.concat(result, ' › '), 'Function'
    end)

    return bar
end

---@return string
function WinBar:__tostring()
    return string.format('WinBar(%d sections)', #self._left + #self._right)
end

return WinBar
