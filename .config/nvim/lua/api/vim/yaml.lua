--- @class vim.yaml
vim.yaml = {}

---@class (exact) vim.yaml.EncodeOpts # Options for encoding YAML.
---@field indent_width integer|nil # the optional width of the indentation (default: 2).
---@field anchors table<string, any>|nil # the optional anchors to use for references.
---@field empty_lines_between_tables boolean|nil # whether to add empty lines between tables (default: false).

---@alias vim.yaml.Anchors table<any, { label: string, written: boolean }>
---@class vim.yaml.Serializer # A YAML serializer.
---@field private anchors vim.yaml.Anchors # the references to objects (anchors).
---@field private indent_width integer # the width of the indentation.
---@field private indent_str string # the current indentation level.
---@field private current_line string # the current line being written.
---@field private tracked_tables table<any, boolean> # the tables that have been tracked.
---@field private empty_lines_between_tables boolean # whether to add empty lines between tables.
---@field lines string[] # the lines of the YAML output.
local Serializer = {}
Serializer.__index = Serializer

--- Creates a new YAML serializer.
---@param opts vim.yaml.EncodeOpts|nil # the optional encoding options
---@return vim.yaml.Serializer # the new serializer
function Serializer.new(opts)
    opts = opts or {}
    opts.anchors = opts.anchors or {}
    opts.indent_width = opts.indent_width or 2
    opts.empty_lines_between_tables = opts.empty_lines_between_tables or false

    assert(opts.anchors == nil or type(opts.anchors) == 'table')
    assert(type(opts.indent_width) == 'number' and opts.indent_width > 0)
    assert(type(opts.empty_lines_between_tables) == 'boolean')

    ---@type vim.yaml.Anchors
    local anchors = {}
    for k, v in pairs(opts.anchors) do
        anchors[v] = { label = k, written = false }
    end

    ---@type vim.yaml.Serializer
    local instance = {
        anchors = anchors,
        lines = {},
        current_line = '',
        indent_str = '',
        indent_width = opts.indent_width,
        tracked_tables = {},
        empty_lines_between_tables = opts.empty_lines_between_tables,
    }

    setmetatable(instance, Serializer)
    return instance
end

--- Appends a value to the current line.
---@param value_or_fmt string # the value or format string to append
---@vararg string # the values to format
function Serializer:append(value_or_fmt, ...)
    if select('#', ...) > 0 then
        self.current_line = self.current_line .. string.format(value_or_fmt, ...)
    else
        self.current_line = self.current_line .. value_or_fmt
    end
end

--- Appends an anchor to the current line.
---@param anchor string # the anchor to append
function Serializer:append_anchor(anchor)
    self:append('&%s ', anchor)
end

--- Tracks a table for cycle detection.
---@param tbl table # the table to track
---@error if the table has already been tracked and the cycle strategy is 'error'
function Serializer:track_table(tbl)
    if self.tracked_tables[tbl] then
        error('Cycle detected while serializing object', 2)
    else
        self.tracked_tables[tbl] = true
    end
end

--- Pushes the current line to the lines and resets the current line.
---@param increase boolean|nil # whether to increase, decrease or keep the indentation level
---@param trim_empty_lines boolean|nil # whether to trim empty lines (default: false)
function Serializer:next(increase, trim_empty_lines)
    if increase == true then
        self.indent_str = self.indent_str .. string.rep(' ', self.indent_width)
    elseif increase == false then
        self.indent_str = self.indent_str:sub(1, -self.indent_width - 1)
    end

    if self.current_line:match '%S' then
        table.insert(self.lines, self.current_line)
    elseif not trim_empty_lines then
        table.insert(self.lines, self.current_line)
    elseif self.empty_lines_between_tables then
        table.insert(self.lines, '')
    end

    self.current_line = self.indent_str
end

--- Creates a function that wraps a write function to handle anchors.
---@param fn function # the write function when there is no anchor associated with the value
function Serializer:anchored(value, fn)
    local anchor = self.anchors[value]

    if anchor then
        if anchor.written then
            self:append('*%s', anchor.label)
            anchor.written = true
        else
            Serializer:append_anchor(anchor.label)
        end
    end

    fn()
end

--- Writes a table/list to the YAML output.
---@param value any[] # the list to write
function Serializer:table(value)
    assert(type(value) == 'table')
    self:track_table(value)

    self:anchored(value, function()
        if vim.tbl_isempty(value) then
            self:append '{}'
        else
            if vim.islist(value) then
                for _, v in ipairs(value) do
                    self:append '- '
                    self:object(v)
                    self:next()
                end
            else
                for k, v in pairs(value) do
                    if type(k) == 'table' then
                        self:append '? '
                        self:table(k)
                    else
                        self:object(k)
                    end

                    if type(v) == 'table' then
                        self:append ':'
                        self:next(true)
                        self:table(v)
                        self:next(false, true)
                    else
                        self:append ': '
                        self:object(v)
                        self:next()
                    end
                end
            end
        end
    end)
end

local function special_word_forms(...)
    ---@type string[]
    local result = {}

    for _, word in ipairs { ... } do
        table.insert(result, word:lower())
        table.insert(result, word:upper())
        table.insert(result, word:sub(1, 1):upper() .. word:sub(2))
    end
end

local special_words = vim.tbl_merge({
    '',
    '~',
    '#',
}, special_word_forms('yes', 'no', 'on', 'off', 'true', 'false', 'null'))

--- Writes a scalar value to the YAML output.
---@param value string|number|boolean # the scalar value to write
function Serializer:scalar(value)
    self:anchored(value, function()
        local value_type = type(value)

        if value_type == 'string' then
            local list = vim.split(value, '\n')
            if #list > 1 then
                self:append '|'
                self:next(true)

                vim.iter(list):each(function(line)
                    self:append(line)
                    self:next(nil, false)
                end)

                self:next(false)
            else
                local escaped = value:gsub("'", "''")

                if
                    escaped ~= value
                    or vim.list_contains(special_words, value)
                    or value:match '^%s'
                    or value:match '%s$'
                then
                    self:append("'%s'", escaped)
                else
                    self:append(value)
                end
            end
        elseif value == math.huge then
            self:append '.inf'
        elseif value == -math.huge then
            self:append '-.inf'
        elseif value ~= value then
            self:append '.nan'
        elseif value_type == 'number' or value_type == 'boolean' then
            self:append(tostring(value))
        else
            error(string.format('cannot serialize scalar of type `%s`', value_type), 2)
        end
    end)
end

--- Writes an object to the YAML output.
---@param obj any # the object to write
function Serializer:object(obj)
    local node_type = type(obj)

    if obj == nil then
        self:append '~'
    elseif node_type == 'string' or node_type == 'boolean' or node_type == 'number' then
        return self:scalar(obj)
    elseif node_type == 'table' then
        return self:table(obj)
    else
        error(string.format('cannot serialize object of type `%s`', node_type), 2)
    end
end

--- Encodes a Lua object into a YAML string.
---@param obj any # the object to encode
---@param opts vim.yaml.EncodeOpts|nil # the optional encoding options
---@return string # the YAML string
function vim.yaml.encode(obj, opts)
    local serializer = Serializer.new(opts)

    serializer:object(obj)

    return table.concat(serializer.lines, '\n')
end
