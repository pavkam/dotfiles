local hl = require 'ui.hl'

---@class (exact) ui.bars.Context # The windowed context of a component.
---@field window integer # the parent window of the component.
---@field window_type vim.fn.WindowType # the type of the window.
---@field buffer integer # the current buffer of the window.
---@field buffer_type string # the type of the buffer.
---@field file_type string # the file type of the buffer.
---@field name string # the name of the buffer.
---@field active boolean # whether the window is active.
---@field width integer # the width of the window.
---@field mode string # the vim mode.

---@class (exact) ui.bars.Chunk # A rendered chunk full specification.
---@field text string # the text of the item.
---@field hl_group 'rev-left'|'rev-right'|string|nil # the highlight group of the chunk.

---@alias ui.bars.Chunks ui.bars.Chunk|ui.bars.Chunk[]|any # Rendered chunks.
---@alias ui.bars.RenderFunction fun(context: ui.bars.Context, max_width: integer): ui.bars.Chunks # renders the component.

---@alias ui.bars.Alignment # The alignment of a component.
---| 'left' # aligns the component to the left.
---| 'right' # aligns the component to the right.
---| 'fit' # fits the component in the available space.

---@class (exact) ui.bars.Component # A component of a bar.
---@field align ui.bars.Alignment|nil # the alignment of the component (default: `fit`).
---@field min_width integer|nil # the minimum size of the component (default: `1`).
---@field render ui.bars.RenderFunction # renders the component.

---@alias ui.bars.WidthFunction fun(): integer # A function that returns the width of the enclosing container.

---@class ui.bars.Bar # A bar that can contain multiple components.
---@field private components ui.bars.Component[] # the components of the bar.
---@field private rendered string # the rendered bar.
---@field private needs_re_render boolean # whether the bar needs to be re-rendered.
---@field private active_hl_group string # the highlight group of the bar.
---@field private inactive_hl_group string # the highlight group of the bar when inactive.
local Bar = {}

---@class (exact) ui.bars.BarOpts # The options of a bar.
---@field window integer|nil # the parent window of the bar or `nil` if global.
---@field components ui.bars.Component[] # the components of the bar.
---@field active_hl_group string # the highlight group of the bar.
---@field inactive_hl_group string # the highlight group of the bar when inactive.

--- Creates a new bar.
---@param opts ui.bars.BarOpts # the options of the bar.
---@return ui.bars.Bar # the created bar.
function Bar.create(opts)
    assert(type(opts.components) == 'table')
    assert(type(opts.active_hl_group) == 'string')
    assert(type(opts.inactive_hl_group) == 'string')

    opts.window = opts.window == 0 and vim.api.nvim_get_current_win() or opts.window

    local bar = setmetatable({
        components = opts.components,
        needs_re_render = true,
        active_hl_group = opts.active_hl_group,
        inactive_hl_group = opts.inactive_hl_group,
    }, { __index = Bar })

    return bar
end

---@type ui.bars.Chunk[]
local empty_component = { { text = '' } }

--- Renders a component.
---@param component ui.bars.Component # the component to render.
---@param context ui.bars.Context # the context of render.
---@param max_width integer # the maximum width of the component.
---@return ui.bars.Chunk[], integer # the rendered component and its width.
local function render_component(context, component, max_width)
    local rendered = component.render(context, max_width)

    if type(rendered) == 'string' then
        rendered = { { text = rendered } }
    elseif type(rendered) == 'table' then
        if vim.tbl_isempty(rendered) then
            rendered = empty_component
        elseif type(rendered.text) == 'string' then
            rendered = { rendered }
        elseif not vim.islist(rendered) then
            error(string.format('Invalid return type of render function: `%s`', vim.inspect(rendered)))
        end
    elseif rendered == nil then
        rendered = empty_component
    else
        rendered = { { text = tostring(rendered) } }
    end

    local width = 0
    for _, item in ipairs(rendered) do
        width = width + vim.fn.strwidth(item.text)
    end

    return rendered, width
end

--- Renders all components of the bar.
---@param context ui.bars.Context # the context of the render.
---@param components ui.bars.Component[] # the components to render.
---@return ui.bars.Chunk[] # the rendered components' chunks.
local function render_components(context, components)
    ---@type { chunks: ui.bars.Chunk[], width: integer }[]
    local rendered = {}

    local padded_component_count = 0

    -- First pass to calculate the width of each component.
    local remaining_width = context.width
    for _, component in ipairs(components) do
        local component_chunks, component_width =
            render_component(context, component, math.max(component.min_width or 1, remaining_width))

        remaining_width = remaining_width - component_width
        table.insert(rendered, { chunks = component_chunks, width = component_width })

        if component.align == 'left' or component.align == 'right' then
            padded_component_count = padded_component_count + 1
        end
    end

    if remaining_width < 0 then
        -- Second pass to adjust the width of each component to make sure we can fit more.
        for i, component in ipairs(components) do
            if remaining_width >= 0 then
                break
            end

            local spare_width = math.min(-remaining_width, rendered[i].width - (component.min_width or 1))

            if spare_width > 0 then
                local new_width = rendered[i].width - spare_width
                local component_chunks = render_component(context, component, new_width)
                rendered[i] = { chunks = component_chunks, width = new_width }

                remaining_width = remaining_width + spare_width
            end
        end
    end

    if remaining_width < 0 then
        -- Third pass, still no space available, start dropping components.
        for i, _ in ipairs(components) do
            if remaining_width >= 0 then
                break
            end

            if rendered[i].width > 0 then
                remaining_width = remaining_width + rendered[i].width
                rendered[i].width = 0
            end
        end
    end

    if remaining_width > 0 then
        -- Fourth pass, we have some space left, distribute it to the components that need it
        for i, component in ipairs(components) do
            if remaining_width <= 0 then
                break
            end

            if rendered[i].width > 0 then
                local component_chunks, component_width =
                    render_component(context, component, rendered[i].width + remaining_width)

                remaining_width = remaining_width - (component_width - rendered[i].width)
                rendered[i] = { chunks = component_chunks, width = component_width }
            end
        end
    end

    -- Fifth pass, align the components that need that into the remaining space (if any).
    if remaining_width > 0 and padded_component_count > 0 then
        local padding_per_component = math.max(1, math.floor(remaining_width / padded_component_count))
        local padding = string.rep(' ', padding_per_component)

        for i, component in ipairs(components) do
            if remaining_width <= 0 then
                break
            end

            if component.align == 'left' or component.align == 'right' then
                if component.align == 'right' then
                    rendered[i].chunks[1].text = padding .. rendered[i].chunks[1].text
                else
                    local last_chunk_index = #rendered[i].chunks
                    rendered[i].chunks[last_chunk_index].text = rendered[i].chunks[last_chunk_index].text .. padding
                end

                rendered[i].width = rendered[i].width + padding_per_component
                remaining_width = remaining_width - padding_per_component
            end
        end
    end

    ---@type ui.bars.Chunk[]
    local chunks = {}
    for _, item in ipairs(rendered) do
        if item.width > 0 then
            vim.list_extend(chunks, item.chunks)
        end
    end

    return chunks
end

--- Resolves the highlights of the chunks.
---@param chunks ui.bars.Chunk[] # the chunks to resolve.
---@param default_hl_group string # the default highlight group.
local function resolve_highlights(chunks, default_hl_group)
    --- Recursively resolves the highlight of an item.
    ---@param index integer # the index of the item
    ---@return string # the highlight group of the item
    local function resolve_hl(index)
        if index < 1 or index > #chunks then
            return default_hl_group
        end

        local item = chunks[index]

        if item.hl_group == 'rev-left' then
            chunks[index].hl_group = nil
            chunks[index].hl_group = hl.reverse_hl(resolve_hl(index - 1))
        elseif item.hl_group == 'rev-right' then
            chunks[index].hl_group = nil
            chunks[index].hl_group = hl.reverse_hl(resolve_hl(index + 1))
        elseif item.hl_group == nil then
            chunks[index].hl_group = default_hl_group
        end

        return chunks[index].hl_group --[[@as string]]
    end

    for i = 1, #chunks do
        resolve_hl(i)
    end
end

--- Renders the chunks to a vim bar expression.
---@param chunks ui.bars.Chunk[] # the chunks to render.
---@return string # the rendered bar.
local function render_chunks(chunks)
    local rendered = ''

    for i, chunk in ipairs(chunks) do
        local text = chunk.text:gsub('%%', '%%%%')
        if i == 1 or chunks[i - 1].hl_group ~= chunk.hl_group then
            rendered = rendered .. string.format('%%#%s#%s', chunk.hl_group, text)
        else
            rendered = rendered .. text
        end
    end

    return rendered
end

--- Gathers the context of a window.
---@param window integer # the window to gather the context
---@return ui.bars.Context # the gathered context.
local function gather_window_context(window)
    assert(type(window) == 'number' and window > 0)

    local win_info = assert(vim.fn.getwininfo(window)[1])

    ---@type ui.bars.Context
    local context = {
        window = window,
        window_type = vim.fn.win_type(window),
        buffer = win_info.bufnr,
        buffer_type = vim.api.nvim_get_option_value('buftype', { buf = win_info.bufnr }),
        file_type = vim.api.nvim_get_option_value('filetype', { buf = win_info.bufnr }),
        name = vim.fn.bufname(win_info.bufnr),
        active = tostring(window) == vim.g.actual_curwin,
        width = win_info.width,
        mode = vim.api.nvim_get_mode().mode,
    }

    if context.window_type == 'quick-fix' then
        context.name = vim.fn.getqflist({ title = 0 }).title or '[Quickfix List]'
    elseif context.window_type == 'location-list' then
        context.name = vim.fn.getloclist(window, { title = 0 }).title or '[Location List]'
    elseif context.name ~= '' and vim.buf.is_regular(context.buffer) then
        context.name = vim.fs.expand_path(context.name) or context.name
    end

    return context
end

--- Gathers the context of a window in global context.
---@return ui.bars.Context # the gathered context.
local function gather_global_context()
    local window = vim.api.nvim_get_current_win()
    local win_context = gather_window_context(window)

    win_context.active = true
    win_context.width = vim.api.nvim_get_option_value('columns', { scope = 'global' })

    return win_context
end

--- Renders the bar.
---@param window integer|nil # the window of the bar (or `nil` if not attached to window).
---@return string # the rendered bar
function Bar:render(window)
    local context = window and gather_window_context(window) or gather_global_context()

    local default_hl_group = context.active and self.active_hl_group or self.inactive_hl_group

    local chunks = render_components(context, self.components)
    resolve_highlights(chunks, default_hl_group)

    self.rendered = render_chunks(chunks)

    return self.rendered
end

---@type table<integer, ui.bars.Bar>
local attached_win_bars = {}

--- Attaches the bar to a window.
---@param window integer|nil # the window to attach the bar to or `nil` or `0` for current window.
function Bar:attach(window)
    window = window or vim.api.nvim_get_current_win()
    assert(type(window) == 'number' and vim.api.nvim_win_is_valid(window))

    local current_bar = attached_win_bars[window]
    if current_bar then
        vim.warn(string.format('Another bar is already attached to window `%d`.', window))
    end

    attached_win_bars[window] = self

    vim.api.nvim_set_option_value(
        'winbar',
        "%{%v:lua.require'ui.bars'.render(" .. tostring(window) .. ')%}',
        { win = window }
    )
end

--- Gets the bar attached to a window (if any).
---@param window integer # the window to get the bar of.
---@return ui.bars.Bar|nil # the bar attached to the window or `nil`.
function Bar.get(window)
    window = window or vim.api.nvim_get_current_win()
    assert(type(window) == 'number')

    local bar = attached_win_bars[window]

    if bar and vim.api.nvim_get_option_value('winbar', { win = window }) == '' then
        attached_win_bars[window] = nil
        return nil
    end

    return bar
end

--- Detaches the bar from a window.
---@param window integer|nil # the window to detach the bar from or `nil` or `0` for current window.
function Bar:detach(window)
    window = window or vim.api.nvim_get_current_win()
    assert(type(window) == 'number')

    local bar = attached_win_bars[window]
    if bar == self then
        attached_win_bars[window] = nil
        vim.api.nvim_set_option_value('winbar', '', { win = window })
    end
end

return {
    Bar = Bar,

    --- Renders the bar of a window.
    ---@param window integer # the window to render the bar of.
    render = function(window)
        assert(type(window) == 'number')

        local bar = attached_win_bars[window]
        if bar then
            return bar:render(window)
        end
    end,
}
