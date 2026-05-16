-- Cursor/position value object.
-- Normalizes neovim's inconsistent 0/1-based indexing into a clean API.
-- Internally stores 1-based row, 1-based col (human-readable).

local Position = Class('Position')

--- Create a position.
---@param row integer # 1-based line number
---@param col integer # 1-based column number
function Position:init(row, col)
    self.row = row or 1
    self.col = col or 1
end

--- Create from neovim's cursor format (1-based row, 0-based col).
---@param cursor integer[] # {row, col} from nvim_win_get_cursor
---@return Position
function Position.from_cursor(cursor)
    return Position(cursor[1], cursor[2] + 1)
end

--- Convert to neovim's cursor format (1-based row, 0-based col).
---@return integer[]
function Position:to_cursor()
    return { self.row, self.col - 1 }
end

---@return string
function Position:__tostring()
    return string.format('%d:%d', self.row, self.col)
end

return Position
