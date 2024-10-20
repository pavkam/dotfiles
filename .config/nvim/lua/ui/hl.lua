local M = {}

-- TODO, move function to vim module to open space for color definitions only.

--- Extracts the color and attributes from a highlight group.
---@param name string # the name of the highlight group
---@return { fg: string, gui: string }|nil # the color and attributes of the highlight group
function M.hl_fg_color_and_attrs(name)
    assert(type(name) == 'string' and name ~= '')

    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })

    if not hl then
        return nil
    end

    local fg = hl.fg or 0
    local attrs = {}

    for _, attr in ipairs { 'italic', 'bold', 'undercurl', 'underdotted', 'underlined', 'strikethrough' } do
        if hl[attr] then
            table.insert(attrs, attr)
        end
    end

    return { fg = string.format('#%06x', fg), gui = table.concat(attrs, ',') }
end

--- Sets the highlight group for a name
---@param name string # the name of the highlight group
---@vararg table<string, any>|string # the attributes to set
function M.make_hl(name, ...)
    assert(type(name) == 'string' and name ~= '')

    local args = { ... }

    assert(#args > 0)

    if #args == 1 and type(args[1]) == 'string' then
        vim.api.nvim_set_hl(0, name, { link = args[1] })
        return
    end

    ---@type table<string, any>
    local hls = {}
    for _, m in ipairs(args) do
        if type(m) == 'table' then
            table.insert(hls, m)
        elseif type(m) == 'string' then
            table.insert(hls, vim.api.nvim_get_hl(0, { name = m, link = false }))
        elseif type(m) == 'integer' then
            table.insert(hls, vim.api.nvim_get_hl(0, { id = m, link = false }))
        else
            error 'Invalid highlight group type'
        end
    end

    -- merge and cleanup the final table
    local merged = vim.tbl_merge(unpack(hls))
    vim.api.nvim_set_hl(0, name, merged)
end

--- Sets multiple highlight groups at once
---@param highlights table<string, table<string, any>|string> # the highlight groups to set
function M.make_hls(highlights)
    for hl, def in pairs(highlights) do
        if type(def) == 'string' then
            M.make_hl(hl, def)
        elseif vim.islist(def) then
            M.make_hl(hl, unpack(def))
        else
            M.make_hl(hl, def)
        end
    end
end

--- Creates a new highlight group by reversing the colors of a given highlight group.
---@param name string # the name of the new blended highlight group
---@return string # the name of the new blended highlight group
function M.reverse_hl(name)
    assert(type(name) == 'string' and name ~= '')

    local new_hl_name = string.format('%s-reversed', name)
    local existing_hl = vim.api.nvim_get_hl(0, { name = new_hl_name, link = false })
    if existing_hl then
        return new_hl_name
    end

    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    if not hl then
        error('Highlight group not found: ' .. name)
    end

    local new_hl = vim.tbl_extend('force', hl, {
        reverse = true,
    })

    vim.api.nvim_set_hl(0, new_hl_name, new_hl)

    return new_hl_name
end

local highlights = {
    -- Other
    CopilotAnnotation = '@string.regexp',
    CopilotSuggestion = '@string.regexp',
    NormalMenuItem = 'Special',
    SpecialMenuItem = 'Boolean',
    AuxiliaryProgressStatus = 'Comment',
    ActiveLintersStatus = { 'Statement', { italic = true } },
    DisabledLintersStatus = { 'ActiveLintersStatus', { strikethrough = true } },
    ActiveFormattersStatus = { 'Function', { italic = true } },
    DisabledFormattersStatus = { 'ActiveFormattersStatus', { strikethrough = true } },
    ActiveLSPsStatus = 'PreProc',
    CopilotIdle = 'Special',
    CopilotFetching = 'DiagnosticWarn',
    CopilotWarning = 'DiagnosticError',
    RecordingMacroStatus = { 'Error', { bold = true } },
    MarkSign = 'DiagnosticWarn',

    CommandPaletteNearFile = 'TelescopeResultsNormal',
    CommandPaletteMarkedFile = 'DiagnosticWarn',
    CommandPaletteOldFile = 'DiagnosticHint',
    CommandPaletteCommand = 'Function',
    CommandPaletteKeymap = 'Keyword',

    FilePaletteOpenFile = '@lsp.type.variable',
    FilePaletteJumpedFile = '@lsp.type.decorator',
    FilePaletteOldFile = '@lsp.type.number',
    FilePaletteMarkedFile = '@keyword',

    StatusLineTestFailed = 'NeotestFailed',
    StatusLineTestPassed = 'NeotestPassed',
    StatusLineTestSkipped = 'NeotestSkipped',
}

M.make_hls(highlights)

return M
