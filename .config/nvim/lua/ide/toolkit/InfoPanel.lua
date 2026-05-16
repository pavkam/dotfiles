-- InfoPanel: read-only information display panel.
-- Shows structured data like LSP status, buffer info, git info, etc.
-- Uses a reactive function component for content rendering.

local Panel = require 'ide.toolkit.Panel'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'

local InfoPanel = Class('InfoPanel', Panel)

---@param opts { title?: string, sections: { heading: string, items: { label: string, value: string, hl?: string }[] }[], width?: number, height?: number }
function InfoPanel:init(opts)
    local content_lines = 0
    for _, section in ipairs(opts.sections) do
        content_lines = content_lines + 1 + #section.items + 1
    end

    Panel.init(self, {
        title = opts.title or '  Info',
        width = opts.width or 0.5,
        height = opts.height or math.min(content_lines + 2, 30),
        enter = true,
    })
    self._sections = opts.sections
end

--- Function component that renders the info panel content.
local function InfoPanelView(props)
    local sections = props.sections or {}
    local children = {}

    for si, section in ipairs(sections) do
        children[#children + 1] = { type = 'text', text = section.heading, indent = 1, hl = 'Title' }

        for _, item in ipairs(section.items) do
            children[#children + 1] = {
                type = 'row',
                children = {
                    { type = 'text', text = '  ' .. item.label .. ': ', hl = 'Comment' },
                    { type = 'text', text = item.value, hl = item.hl or 'String' },
                },
            }
        end

        if si < #sections then
            children[#children + 1] = { type = 'text', text = '' }
        end
    end

    return children
end

function InfoPanel:_on_mount()
    self._component = C.mount(InfoPanelView, {
        sections = self._sections,
    }, self:buffer(), self._win)
end

function InfoPanel:hide()
    if self._component then
        C.unmount(self._component)
        self._component = nil
    end
    Panel.hide(self)
end

---@return string
function InfoPanel:__tostring()
    return string.format('InfoPanel(%d sections)', #self._sections)
end

--- Convenience: show IDE status info.
---@return InfoPanel
function InfoPanel.ide_status()
    local DS = require 'ide.DiagnosticSet'
    local buf = IDE.buffers:current()
    local proj = IDE:project()
    local branch = IDE.git:branch()

    local sections = {
        {
            heading = '  Buffer',
            items = {
                { label = 'Name', value = buf:name() or '<unnamed>' },
                { label = 'Type', value = buf:filetype() },
                { label = 'Lines', value = tostring(buf:line_count()) },
                { label = 'Modified', value = tostring(buf:is_modified()), hl = buf:is_modified() and 'DiagnosticWarn' or 'DiagnosticOk' },
                { label = 'Path', value = buf:path() or '-' },
            },
        },
        {
            heading = '  LSP',
            items = vim.tbl_map(function(c)
                return { label = c.name, value = 'active', hl = 'DiagnosticOk' }
            end, buf:lsp():clients()),
        },
        {
            heading = '  Diagnostics',
            items = {
                { label = 'Errors', value = tostring(buf:diagnostics():count(DS.ERROR)), hl = 'DiagnosticError' },
                { label = 'Warnings', value = tostring(buf:diagnostics():count(DS.WARN)), hl = 'DiagnosticWarn' },
                { label = 'Hints', value = tostring(buf:diagnostics():count(DS.HINT)), hl = 'DiagnosticHint' },
            },
        },
    }

    if proj then
        table.insert(sections, 2, {
            heading = '  Project',
            items = {
                { label = 'Name', value = proj:name() },
                { label = 'Type', value = proj:type() or '-' },
                { label = 'Root', value = proj:root() },
                { label = 'Git', value = branch or 'not a repo', hl = branch and 'String' or 'Comment' },
            },
        })
    end

    return InfoPanel {
        title = '  IDE Status',
        sections = sections,
    }
end

return InfoPanel
