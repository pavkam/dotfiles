-- Canvas: drawing primitives for building custom UI screens.
-- Provides text, lines, boxes, fills, and centering on a virtual grid.
-- Renders to a buffer with highlights.

local Buffer = require 'ide.Buffer'

local Canvas = Class('Canvas')

---@param width integer
---@param height integer
function Canvas:init(width, height)
    self._width = width
    self._height = height
    self._lines = {}
    self._highlights = {} -- { row, col_start, col_end, group }[]

    -- Initialize with empty lines
    for _ = 1, height do
        self._lines[#self._lines + 1] = string.rep(' ', width)
    end
end

--- Draw text at a position.
---@param row integer # 1-indexed
---@param col integer # 1-indexed
---@param text string
--- Get the byte offset for a given 1-indexed display column in a string.
---@param str string
---@param display_col integer # 1-indexed
---@return integer # byte offset
local function byte_offset_for_col(str, display_col)
    if display_col <= 1 then return 0 end
    local target = display_col - 1
    local byte_pos = 0
    local col_pos = 0
    local len = #str
    while byte_pos < len and col_pos < target do
        local b = str:byte(byte_pos + 1)
        local seq_len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
        if byte_pos + seq_len > len then break end
        local ch = str:sub(byte_pos + 1, byte_pos + seq_len)
        col_pos = col_pos + vim.api.nvim_strwidth(ch)
        byte_pos = byte_pos + seq_len
    end
    return byte_pos
end

--- Truncate a string to a maximum display width.
---@param str string
---@param max_width integer
---@return string
local function display_truncate(str, max_width)
    local byte_pos = 0
    local col_pos = 0
    local len = #str
    while byte_pos < len do
        local b = str:byte(byte_pos + 1)
        local seq_len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
        if byte_pos + seq_len > len then break end
        local ch = str:sub(byte_pos + 1, byte_pos + seq_len)
        local cw = vim.api.nvim_strwidth(ch)
        if col_pos + cw > max_width then break end
        col_pos = col_pos + cw
        byte_pos = byte_pos + seq_len
    end
    return str:sub(1, byte_pos)
end

---@param hl? string # highlight group
function Canvas:text(row, col, text, hl)
    if row < 1 or row > self._height then return end
    local line = self._lines[row]
    local line_dw = vim.api.nvim_strwidth(line)
    local text_dw = vim.api.nvim_strwidth(text)

    -- Pad line if col exceeds current display width
    if col - 1 > line_dw then
        line = line .. string.rep(' ', col - 1 - line_dw)
    end

    local byte_start = byte_offset_for_col(line, col)
    local byte_end = byte_offset_for_col(line, col + text_dw)

    local before = line:sub(1, byte_start)
    local after = line:sub(byte_end + 1)
    self._lines[row] = before .. text .. after

    -- Trim or pad to target display width
    local new_dw = vim.api.nvim_strwidth(self._lines[row])
    if new_dw > self._width then
        self._lines[row] = display_truncate(self._lines[row], self._width)
    elseif new_dw < self._width then
        self._lines[row] = self._lines[row] .. string.rep(' ', self._width - new_dw)
    end

    if hl then
        self._highlights[#self._highlights + 1] = {
            row = row, col_start = byte_start, col_end = byte_start + #text, group = hl,
        }
    end
end

--- Center text on a row.
---@param row integer # 1-indexed
---@param text string
---@param hl? string
function Canvas:center(row, text, hl)
    local col = math.max(1, math.floor((self._width - vim.api.nvim_strwidth(text)) / 2) + 1)
    self:text(row, col, text, hl)
end

--- Draw a horizontal line.
---@param row integer
---@param col integer
---@param width integer
---@param char? string # default '─'
---@param hl? string
function Canvas:hline(row, col, width, char, hl)
    char = char or '─'
    self:text(row, col, string.rep(char, width), hl)
end

--- Draw a vertical line.
---@param row integer
---@param col integer
---@param height integer
---@param char? string # default '│'
---@param hl? string
function Canvas:vline(row, col, height, char, hl)
    char = char or '│'
    for r = row, math.min(row + height - 1, self._height) do
        self:text(r, col, char, hl)
    end
end

--- Fill a region with a character.
---@param row integer
---@param col integer
---@param w integer
---@param h integer
---@param char? string # default ' '
---@param hl? string
function Canvas:fill(row, col, w, h, char, hl)
    char = char or ' '
    for r = row, math.min(row + h - 1, self._height) do
        self:text(r, col, string.rep(char, w), hl)
    end
end

--- Draw a box with border characters.
---@param row integer
---@param col integer
---@param w integer
---@param h integer
---@param style? 'single'|'double' # default 'single'
---@param hl? string
function Canvas:box(row, col, w, h, style, hl)
    local chars
    if style == 'double' then
        chars = { tl = '╔', tr = '╗', bl = '╚', br = '╝', h = '═', v = '║' }
    else
        chars = { tl = '┌', tr = '┐', bl = '└', br = '┘', h = '─', v = '│' }
    end
    -- Top
    self:text(row, col, chars.tl .. string.rep(chars.h, w - 2) .. chars.tr, hl)
    -- Sides
    for r = row + 1, row + h - 2 do
        self:text(r, col, chars.v, hl)
        self:text(r, col + w - 1, chars.v, hl)
    end
    -- Bottom
    self:text(row + h - 1, col, chars.bl .. string.rep(chars.h, w - 2) .. chars.br, hl)
end

--- Draw a table with headers and rows.
---@param row integer
---@param col integer
---@param headers string[]
---@param rows string[][]
---@param hl_header? string
---@param hl_row? string
function Canvas:table(row, col, headers, rows, hl_header, hl_row)
    -- Calculate column widths
    local widths = {}
    for i, h in ipairs(headers) do
        widths[i] = vim.api.nvim_strwidth(h)
    end
    for _, r in ipairs(rows) do
        for i, cell in ipairs(r) do
            widths[i] = math.max(widths[i] or 0, vim.api.nvim_strwidth(cell))
        end
    end

    -- Draw header
    local c = col
    for i, h in ipairs(headers) do
        self:text(row, c, h .. string.rep(' ', widths[i] - vim.api.nvim_strwidth(h)), hl_header)
        c = c + widths[i] + 2
    end

    -- Draw separator
    local total_w = 0
    for _, w in ipairs(widths) do total_w = total_w + w + 2 end
    self:hline(row + 1, col, total_w - 2, '─', hl_header)

    -- Draw rows
    for ri, r in ipairs(rows) do
        c = col
        for i, cell in ipairs(r) do
            self:text(row + 1 + ri, c, cell .. string.rep(' ', widths[i] - vim.api.nvim_strwidth(cell)), hl_row)
            c = c + widths[i] + 2
        end
    end
end

--- Draw right-aligned text on a row.
---@param row integer
---@param text string
---@param hl? string
function Canvas:right(row, text, hl)
    local col = math.max(1, self._width - vim.api.nvim_strwidth(text))
    self:text(row, col, text, hl)
end

--- Draw text with word wrapping within a region.
---@param row integer
---@param col integer
---@param width integer
---@param text string
---@param hl? string
---@return integer # number of rows used
function Canvas:wrap_text(row, col, width, text, hl)
    local words = vim.split(text, '%s+')
    local current_line = ''
    local lines_used = 0

    for _, word in ipairs(words) do
        if #current_line + #word + 1 > width and current_line ~= '' then
            self:text(row + lines_used, col, current_line, hl)
            lines_used = lines_used + 1
            current_line = word
        else
            current_line = current_line == '' and word or (current_line .. ' ' .. word)
        end
    end
    if current_line ~= '' then
        self:text(row + lines_used, col, current_line, hl)
        lines_used = lines_used + 1
    end
    return lines_used
end

--- Draw a progress bar.
---@param row integer
---@param col integer
---@param width integer
---@param progress number # 0-1
---@param hl_filled? string
---@param hl_empty? string
function Canvas:progress(row, col, width, progress, hl_filled, hl_empty)
    local filled = math.floor(width * math.max(0, math.min(1, progress)))
    local empty = width - filled
    self:text(row, col, string.rep('█', filled), hl_filled)
    self:text(row, col + filled, string.rep('░', empty), hl_empty)
end

--- Draw a separator line with optional centered title.
---@param row integer
---@param title? string
---@param hl? string
function Canvas:separator(row, title, hl)
    if title then
        local pad = math.floor((self._width - #title - 4) / 2)
        self:hline(row, 1, pad, '─', hl)
        self:text(row, pad + 1, ' ' .. title .. ' ', hl)
        self:hline(row, pad + #title + 3, self._width - pad - #title - 2, '─', hl)
    else
        self:hline(row, 1, self._width, '─', hl)
    end
end

--- Draw a key-value pair (label: value).
---@param row integer
---@param col integer
---@param label string
---@param value string
---@param hl_label? string
---@param hl_value? string
function Canvas:kv(row, col, label, value, hl_label, hl_value)
    self:text(row, col, label .. ': ', hl_label)
    self:text(row, col + #label + 2, value, hl_value)
end

--- Create a sub-canvas (viewport into a region).
---@param row integer
---@param col integer
---@param w integer
---@param h integer
---@return Canvas
function Canvas:sub(row, col, w, h)
    local sub = Canvas(w, h)
    sub._parent = self
    sub._offset_row = row - 1
    sub._offset_col = col - 1
    return sub
end

--- Blit a sub-canvas onto the parent.
---@param sub Canvas
---@param row integer
---@param col integer
function Canvas:blit(sub, row, col)
    for r = 1, sub._height do
        local line = sub._lines[r]
        if line then
            self:text(row + r - 1, col, line)
        end
    end
    for _, hl in ipairs(sub._highlights) do
        self._highlights[#self._highlights + 1] = {
            row = hl.row + row - 1,
            col_start = hl.col_start + col - 1,
            col_end = hl.col_end + col - 1,
            group = hl.group,
        }
    end
end

--- Get all lines.
---@return string[]
function Canvas:get_lines()
    return self._lines
end

--- Get all highlights.
---@return table[]
function Canvas:get_highlights()
    return self._highlights
end

--- Render to a buffer with highlights.
---@param buf Buffer|integer
---@param ns? integer # namespace
function Canvas:render(buf, ns)
    local buf_id = type(buf) == 'number' and buf or buf:id()
    ns = ns or vim.api.nvim_create_namespace('ide_canvas')

    vim.bo[buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, self._lines)
    vim.bo[buf_id].modifiable = false

    vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)
    for _, hl in ipairs(self._highlights) do
        vim.api.nvim_buf_add_highlight(buf_id, ns, hl.group, hl.row - 1, hl.col_start, hl.col_end)
    end
end

function Canvas:width() return self._width end
function Canvas:height() return self._height end

function Canvas:__tostring()
    return string.format('Canvas(%dx%d)', self._width, self._height)
end

return Canvas
