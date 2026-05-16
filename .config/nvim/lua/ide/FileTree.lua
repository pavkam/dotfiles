-- FileTree: file explorer abstraction.
-- Uses the TurboVision FileTree toolkit component for a proper tree view.

local FileTreePanel = require 'ide.toolkit.FileTree'

local FileTree = Class('FileTree')

function FileTree:init()
    self._panel = nil
end

function FileTree:toggle()
    if self._panel and self._panel:is_visible() then
        self._panel:close()
        self._panel = nil
    else
        -- Use project root, git root, or buffer directory
        local cwd
        if IDE then
            cwd = IDE.git:root()
            if not cwd then
                local buf = require('ide.Buffer').current()
                if buf:is_valid() and buf:path() then
                    cwd = IDE.fs:dirname(buf:path())
                end
            end
        end
        cwd = cwd or vim.fn.getcwd()
        self._panel = FileTreePanel({ cwd = cwd })
        self._panel:show()
    end
end

function FileTree:reveal()
    self:toggle()
end

function FileTree:focus()
    if self._panel and self._panel:is_visible() then return end
    self:toggle()
end

function FileTree:close()
    if self._panel then
        self._panel:close()
        self._panel = nil
    end
end

---@return string
function FileTree:__tostring() return 'FileTree()' end

return FileTree
