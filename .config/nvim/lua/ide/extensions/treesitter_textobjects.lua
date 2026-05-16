-- TreesitterTextobjects Extension: select, move, and swap around
-- treesitter nodes (functions, blocks, parameters, classes, conditionals).
-- Uses buf:ast() for buffer-scoped treesitter access.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Position = require 'ide.Position'

local TreesitterTextobjects = Class('TreesitterTextobjects', Extension)

function TreesitterTextobjects:init()
    Extension.init(self, 'TreesitterTextobjects')
end

--- Read text from a buffer region (0-indexed coordinates).
--- Concentrates the single raw API call needed since Buffer lacks get_text.
---@param buf Buffer
---@param sr integer # 0-indexed start row
---@param sc integer # 0-indexed start col
---@param er integer # 0-indexed end row
---@param ec integer # 0-indexed end col
---@return string[]
local function buf_get_text(buf, sr, sc, er, ec)
    return vim.api.nvim_buf_get_text(buf:id(), sr, sc, er, ec, {})
end

--- Collect all nodes matching a query capture, sorted by position.
---@param query_name string e.g. '@function.outer'
---@param buf Buffer
---@return TSNode[], vim.treesitter.Query|nil
local function collect_capture_nodes(query_name, buf)
    local ast = buf:ast()
    if not ast:has_parser() then return {} end

    local capture = query_name:match('^@(.+)$')
    if not capture then return {} end

    local query = ast:query('textobjects')
    if not query then return {} end

    local root = ast:root()
    if not root then return {} end

    local nodes = {}
    for id, node in query:iter_captures(root, buf:id()) do
        if query.captures[id] == capture then
            nodes[#nodes + 1] = node
        end
    end

    -- Sort by start position for deterministic ordering
    table.sort(nodes, function(a, b)
        local ar, ac = a:range()
        local br, bc = b:range()
        if ar ~= br then return ar < br end
        return ac < bc
    end)

    return nodes
end

--- Find the nearest node matching a query capture in direction.
---@param query_name string e.g. '@function.outer'
---@param buf Buffer
---@param direction 'next_start'|'next_end'|'prev_start'|'prev_end'
---@return TSNode|nil
local function find_textobject(query_name, buf, direction)
    local ast = buf:ast()
    if not ast:has_parser() then return nil end

    local capture = query_name:match('^@(.+)$')
    if not capture then return nil end

    local query = ast:query('textobjects')
    if not query then return nil end

    local root = ast:root()
    if not root then return nil end

    local cursor = Window.current():cursor()
    local crow, ccol = cursor.row - 1, cursor.col - 1

    local best = nil
    local best_dist = math.huge

    for id, node in query:iter_captures(root, buf:id()) do
        local name = query.captures[id]
        if name == capture then
            local sr, sc, er, ec = node:range()
            local dist, valid

            if direction == 'next_start' then
                dist = (sr - crow) * 10000 + (sc - ccol)
                valid = dist > 0
            elseif direction == 'next_end' then
                dist = (er - crow) * 10000 + (ec - ccol)
                valid = dist > 0
            elseif direction == 'prev_start' then
                dist = (crow - sr) * 10000 + (ccol - sc)
                valid = dist > 0
            elseif direction == 'prev_end' then
                dist = (crow - er) * 10000 + (ccol - ec)
                valid = dist > 0
            end

            if valid and dist < best_dist then
                best = node
                best_dist = dist
            end
        end
    end
    return best
end

--- Select a textobject (visual mode).
---@param query_name string
local function select_textobject(query_name)
    local buf = Buffer.current()
    local ast = buf:ast()
    if not ast:has_parser() then return end

    local capture = query_name:match('^@(.+)$')
    if not capture then return end

    local query = ast:query('textobjects')
    if not query then return end

    local root = ast:root()
    if not root then return end

    local cursor = Window.current():cursor()
    local crow, ccol = cursor.row - 1, cursor.col - 1

    local best = nil
    local best_size = math.huge

    for id, node in query:iter_captures(root, buf:id()) do
        local name = query.captures[id]
        if name == capture then
            local sr, sc, er, ec = node:range()
            if crow >= sr and crow <= er then
                if crow > sr or ccol >= sc then
                    if crow < er or ccol <= ec then
                        local size = (er - sr) * 10000 + (ec - sc)
                        if size < best_size then
                            best = node
                            best_size = size
                        end
                    end
                end
            end
        end
    end

    if best then
        local sr, sc, er, ec = best:range()
        Window.current():set_cursor(Position(sr + 1, sc + 1))
        IDE.keys:normal('v')
        Window.current():set_cursor(Position(er + 1, math.max(1, ec)))
    end
end

--- Move cursor to next/previous textobject.
---@param query_name string
---@param direction string
local function goto_textobject(query_name, direction)
    local buf = Buffer.current()
    local node = find_textobject(query_name, buf, direction)
    if node then
        if direction:match('end') then
            local _, _, er, ec = node:range()
            Window.current():set_cursor(Position(er + 1, ec + 1))
        else
            local sr, sc = node:range()
            Window.current():set_cursor(Position(sr + 1, sc + 1))
        end
    end
end

--- Swap the textobject under cursor with the next or previous one of the same kind.
---@param query_name string e.g. '@function.outer'
---@param direction 'next'|'prev'
local function swap_textobject(query_name, direction)
    local buf = Buffer.current()
    local nodes = collect_capture_nodes(query_name, buf)
    if #nodes < 2 then return end

    local cursor = Window.current():cursor()
    local crow = cursor.row - 1

    -- Find the node at or containing the cursor
    local current_idx = nil
    for i, node in ipairs(nodes) do
        local sr, _, er, _ = node:range()
        if crow >= sr and crow <= er then
            current_idx = i
            break
        end
    end

    if not current_idx then return end

    local target_idx
    if direction == 'next' then
        target_idx = current_idx + 1
    else
        target_idx = current_idx - 1
    end

    if target_idx < 1 or target_idx > #nodes then return end

    local current_node = nodes[current_idx]
    local target_node = nodes[target_idx]

    local sr1, sc1, er1, ec1 = current_node:range()
    local sr2, sc2, er2, ec2 = target_node:range()

    local text1 = buf_get_text(buf, sr1, sc1, er1, ec1)
    local text2 = buf_get_text(buf, sr2, sc2, er2, ec2)

    -- Replace in reverse document order to preserve indices
    if sr1 > sr2 or (sr1 == sr2 and sc1 > sc2) then
        buf:set_text(sr1, sc1, er1, ec1, text2)
        buf:set_text(sr2, sc2, er2, ec2, text1)
    else
        buf:set_text(sr2, sc2, er2, ec2, text1)
        buf:set_text(sr1, sc1, er1, ec1, text2)
    end
end

function TreesitterTextobjects:on_register(ctx)
    -- Textobject selection (visual + operator-pending)
    local select_maps = {
        { 'ak', '@block.outer', 'Around block' },
        { 'ik', '@block.inner', 'Inside block' },
        { 'ac', '@class.outer', 'Around class' },
        { 'ic', '@class.inner', 'Inside class' },
        { 'af', '@function.outer', 'Around function' },
        { 'if', '@function.inner', 'Inside function' },
        { 'al', '@loop.outer', 'Around loop' },
        { 'il', '@loop.inner', 'Inside loop' },
        { 'aa', '@parameter.outer', 'Around argument' },
        { 'ia', '@parameter.inner', 'Inside argument' },
        { 'a?', '@conditional.outer', 'Around conditional' },
        { 'i?', '@conditional.inner', 'Inside conditional' },
    }

    for _, m in ipairs(select_maps) do
        local lhs, q, desc = m[1], m[2], m[3]
        ctx:keymap({ 'x', 'o' }, lhs, function() select_textobject(q) end, { desc = desc })
    end

    -- Movement (normal + visual + operator-pending)
    local move_maps = {
        { ']f', '@function.outer', 'next_start', 'Next function start' },
        { ']F', '@function.outer', 'next_end', 'Next function end' },
        { ']k', '@block.outer', 'next_start', 'Next block start' },
        { ']K', '@block.outer', 'next_end', 'Next block end' },
        { ']a', '@parameter.inner', 'next_start', 'Next argument' },
        { ']A', '@parameter.inner', 'next_end', 'Next argument end' },
        { '[f', '@function.outer', 'prev_start', 'Previous function start' },
        { '[F', '@function.outer', 'prev_end', 'Previous function end' },
        { '[k', '@block.outer', 'prev_start', 'Previous block start' },
        { '[K', '@block.outer', 'prev_end', 'Previous block end' },
        { '[a', '@parameter.inner', 'prev_start', 'Previous argument' },
        { '[A', '@parameter.inner', 'prev_end', 'Previous argument end' },
    }

    for _, m in ipairs(move_maps) do
        local lhs, q, dir, desc = m[1], m[2], m[3], m[4]
        ctx:keymap({ 'n', 'x', 'o' }, lhs, function() goto_textobject(q, dir) end, { desc = desc })
    end

    -- Swap operations (normal mode only)
    local swap_maps = {
        { '>K', '@block.outer', 'next', 'Swap next block' },
        { '<K', '@block.outer', 'prev', 'Swap previous block' },
        { '>F', '@function.outer', 'next', 'Swap next function' },
        { '<F', '@function.outer', 'prev', 'Swap previous function' },
        { '>A', '@parameter.inner', 'next', 'Swap next argument' },
        { '<A', '@parameter.inner', 'prev', 'Swap previous argument' },
    }

    for _, m in ipairs(swap_maps) do
        local lhs, q, dir, desc = m[1], m[2], m[3], m[4]
        ctx:keymap('n', lhs, function() swap_textobject(q, dir) end, { desc = desc })
    end

    ctx:keymap('n', '\\', function()
        if Buffer.current():ast():has_parser() then
            IDE.keys:normal('viw')
        end
    end, { desc = 'Increment selection' })
end

return TreesitterTextobjects
