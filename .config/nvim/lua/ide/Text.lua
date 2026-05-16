-- Text: text operations for IDE features.
-- NOT a wrapper around vim.fn string functions — those belong in Canvas
-- (for rendering) or in the classes that need them (Buffer for content).
-- This class provides high-level text operations: clipboard, word extraction,
-- template expansion, and text transformation.

local Text = Class('Text')

function Text:init() end

--- Copy text to the system clipboard.
---@param text string
function Text:to_clipboard(text)
    vim.fn.setreg('+', text)
end

--- Get text from the system clipboard.
---@return string
function Text:from_clipboard()
    return vim.fn.getreg('+')
end

--- Get the word under the cursor in the current buffer.
---@return string
function Text:word_at_cursor()
    return vim.fn.expand('<cword>')
end

--- Get the WORD (whitespace-delimited) under cursor.
---@return string
function Text:bigword_at_cursor()
    return vim.fn.expand('<cWORD>')
end

--- Pad a string to a fixed display width.
---@param str string
---@param width integer
---@param align 'left'|'right'|'center'|nil
---@return string
function Text:pad(str, width, align)
    local sw = vim.api.nvim_strwidth(str)
    if sw >= width then return str end
    local padding = width - sw
    align = align or 'left'
    if align == 'right' then
        return string.rep(' ', padding) .. str
    elseif align == 'center' then
        local left = math.floor(padding / 2)
        return string.rep(' ', left) .. str .. string.rep(' ', padding - left)
    end
    return str .. string.rep(' ', padding)
end

--- Truncate a string to a maximum display width with ellipsis.
---@param str string
---@param max_width integer
---@param ellipsis string|nil
---@return string
function Text:truncate(str, max_width, ellipsis)
    ellipsis = ellipsis or '…'
    local sw = vim.api.nvim_strwidth(str)
    if sw <= max_width then return str end
    local ew = vim.api.nvim_strwidth(ellipsis)
    local target = max_width - ew
    local result = ''
    local byte = 0
    local col = 0
    while byte < #str do
        local b = str:byte(byte + 1)
        local seq = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
        local ch = str:sub(byte + 1, byte + seq)
        local cw = vim.api.nvim_strwidth(ch)
        if col + cw > target then break end
        result = result .. ch
        col = col + cw
        byte = byte + seq
    end
    return result .. ellipsis
end

--- Indent a block of text by prepending spaces.
---@param text string
---@param indent integer
---@return string
function Text:indent(text, indent)
    local prefix = string.rep(' ', indent)
    local lines = vim.split(text, '\n')
    for i, line in ipairs(lines) do
        if line ~= '' then lines[i] = prefix .. line end
    end
    return table.concat(lines, '\n')
end

--- Strip leading/trailing whitespace.
---@param str string
---@return string
function Text:strip(str)
    return vim.trim(str)
end

--- Capitalize the first letter.
---@param str string
---@return string
function Text:capitalize(str)
    if str == '' then return str end
    return str:sub(1, 1):upper() .. str:sub(2)
end

--- Convert a string to snake_case.
---@param str string
---@return string
function Text:snake_case(str)
    return str:gsub('(%u)', '_%1'):gsub('^_', ''):lower()
end

--- Convert a string to camelCase.
---@param str string
---@return string
function Text:camel_case(str)
    local parts = vim.split(str:gsub('-', '_'), '_')
    for i = 2, #parts do parts[i] = self:capitalize(parts[i]) end
    return table.concat(parts)
end

--- Convert a Unicode codepoint to a UTF-8 string.
---@param cp integer
---@return string
function Text:char(cp)
    if cp < 0x80 then
        return string.char(cp)
    elseif cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
    elseif cp < 0x10000 then
        return string.char(
            0xE0 + math.floor(cp / 4096),
            0x80 + math.floor(cp / 64) % 64,
            0x80 + cp % 64)
    else
        return string.char(
            0xF0 + math.floor(cp / 262144),
            0x80 + math.floor(cp / 4096) % 64,
            0x80 + math.floor(cp / 64) % 64,
            0x80 + cp % 64)
    end
end

--- Get the Unicode codepoint of the first character in a string.
---@param str string
---@return integer
function Text:codepoint(str)
    local b = str:byte(1)
    if b < 0x80 then return b end
    if b < 0xE0 then return (b - 0xC0) * 64 + (str:byte(2) - 0x80) end
    if b < 0xF0 then return (b - 0xE0) * 4096 + (str:byte(2) - 0x80) * 64 + (str:byte(3) - 0x80) end
    return (b - 0xF0) * 262144 + (str:byte(2) - 0x80) * 4096 + (str:byte(3) - 0x80) * 64 + (str:byte(4) - 0x80)
end

--- Count the number of UTF-8 characters in a string.
---@param str string
---@return integer
function Text:char_count(str)
    local count = 0
    local i = 1
    while i <= #str do
        local b = str:byte(i)
        i = i + (b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4)
        count = count + 1
    end
    return count
end

--- Extract a substring by character indices (0-based, inclusive on both ends).
---@param str string
---@param start integer # 0-based start character index
---@param finish integer # 0-based end character index (inclusive)
---@return string
function Text:char_sub(str, start, finish)
    local chars = {}
    local i = 1
    local idx = 0
    while i <= #str do
        local b = str:byte(i)
        local seq = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
        if idx >= start and idx <= finish then
            chars[#chars + 1] = str:sub(i, i + seq - 1)
        end
        i = i + seq
        idx = idx + 1
        if idx > finish then break end
    end
    return table.concat(chars)
end

--- Display width of a string (accounts for wide/multi-byte characters).
--- Convenience for cases where Canvas isn't available.
---@param str string
---@return integer
function Text:display_width(str)
    return vim.api.nvim_strwidth(str)
end

--- Build a :%s/ rename expression for the command line.
---@param opts? { orig?: string, new?: string, whole_word?: boolean }
---@return string # key sequence to feed
function Text:rename_expression(opts)
    opts = opts or {}
    local orig = opts.orig or '<C-r><C-w>'
    local new = opts.new or orig
    if opts.whole_word then
        orig = '\\<' .. orig .. '\\>'
    end
    return ':<C-u>%s/\\V' .. orig .. '/' .. new .. '/gI<Left><Left><Left>'
end

---@return string
function Text:__tostring()
    return 'Text()'
end

return Text
