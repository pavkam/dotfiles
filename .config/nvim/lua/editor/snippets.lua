local utils = require 'core.utils'
local syntax = require 'editor.syntax'
local cmp = require 'cmp'
local project = require 'project'
local comments = require 'editor.comments'
local markdown = require 'extras.markdown'

---@class editor.snippets
---@field name string
local M = {}

local built_in = {
    TM_CURRENT_LINE = function()
        return syntax.current_line()
    end,
    TM_CURRENT_WORD = function()
        return syntax.node_text_under_cursor()
    end,
    TM_LINE_INDEX = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        return tostring(pos[2])
    end,
    TM_LINE_NUMBER = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        return tostring(pos[1])
    end,
    TM_FILENAME = function()
        return vim.fn.expand '%:t'
    end,
    TM_FILENAME_BASE = function()
        return vim.fn.expand '%:t:s?\\.[^\\.]\\+$??'
    end,
    TM_DIRECTORY = function()
        return vim.fn.expand '%:p:h'
    end,
    TM_FILEPATH = function()
        return vim.fn.expand '%:p'
    end,
    CLIPBOARD = function()
        return vim.fn.getreg('"', true)
    end,
    CURRENT_YEAR = function()
        return os.date '%Y'
    end,
    CURRENT_YEAR_SHORT = function()
        return os.date '%y'
    end,
    CURRENT_MONTH = function()
        return os.date '%m'
    end,
    CURRENT_MONTH_NAME = function()
        return os.date '%B'
    end,
    CURRENT_MONTH_NAME_SHORT = function()
        return os.date '%b'
    end,
    CURRENT_DATE = function()
        return os.date '%d'
    end,
    CURRENT_DAY_NAME = function()
        return os.date '%A'
    end,
    CURRENT_DAY_NAME_SHORT = function()
        return os.date '%a'
    end,
    CURRENT_HOUR = function()
        return os.date '%H'
    end,
    CURRENT_MINUTE = function()
        return os.date '%M'
    end,
    CURRENT_SECOND = function()
        return os.date '%S'
    end,
    CURRENT_SECONDS_UNIX = function()
        return tostring(os.time())
    end,
    LINE_COMMENT = function()
        local opts = comments.comment_options()
        return opts and opts.single_line or ''
    end,
    BLOCK_COMMENT_START = function()
        local opts = comments.comment_options()
        return opts and opts.multi_line_start or ''
    end,
    BLOCK_COMMENT_END = function()
        local opts = comments.comment_options()
        return opts and opts.multi_line_end or ''
    end,
    RELATIVE_FILEPATH = function()
        return project.path_components().file_path
    end,
    WORKSPACE_FOLDER = function()
        return project.path_components().work_space_path
    end,
    WORKSPACE_NAME = function()
        return project.path_components().work_space_name
    end,
    CURRENT_TIMEZONE_OFFSET = function()
        local offset = utils.get_timezone_offset(os.time())
        return string.format('%+.4d', offset):gsub('([+-])(%d%d)(%d%d)$', '%1%2:%3')
    end,
    RANDOM = function()
        return string.format('%06d', math.random(999999))
    end,
    RANDOM_HEX = function()
        return string.format('%06x', math.random(16777216)) --16^6
    end,
    UUID = function()
        return utils.uuid()
    end,
}

M.name = 'snippets'

---@type table<string, table<string, string>>
M.snippets = {
    lua = {
        ['hello'] = 'world',
    },
    typescript = {
        ['hello'] = 'world',
    },
}

--- Expands the variables in a snippet
---@param snippet string # The snippet to expand
---@return string # The expanded snippet
local function expand_built_in_vars(snippet)
    local expanded_snippet = snippet

    for match in snippet:gmatch '%${(.-)}' do
        local fun = built_in[match]
        if fun then
            expanded_snippet = expanded_snippet:gsub('${' .. match .. '}', fun)
        end
    end

    return expanded_snippet
end

--- Creates a new cmp source
---@return table # The new source
M.new = function()
    return setmetatable({}, { __index = M })
end

--- Determine if the source is available
---@return boolean # If the source is available
function M:is_available()
    return true
end

--- Get the name of the source
---@return string # The name of the source
function M:get_debug_name()
    return M.name
end

--- Get the completion items
---@param callback fun(items: lsp.CompletionItem[]) # The callback to execute
function M:complete(_, callback)
    local snippets = M.snippets[vim.bo.filetype]
    if snippets == nil then
        return
    end

    ---@type lsp.CompletionItem[]
    local response = {}

    for key, snippet in pairs(snippets) do
        table.insert(response, {
            label = key,
            kind = cmp.lsp.CompletionItemKind.Snippet,
            insertTextFormat = cmp.lsp.InsertTextFormat.Snippet,
            insertTextMode = cmp.lsp.InsertTextMode.AdjustIndentation,
            insertText = snippet,
            data = {
                prefix = key,
                body = snippet,
            },
        })
    end

    callback(response)
end

--- Resolves the completion item
---@param completion_item lsp.CompletionItem # The completion item to resolve
---@param callback fun(item: lsp.CompletionItem) # The callback to execute
function M:resolve(completion_item, callback)
    local file_type = vim.api.nvim_get_option_value('filetype', { buf = 0 })

    completion_item.documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = string.format('```%s\n%s\n```', file_type, markdown.escape(completion_item.data.body)),
    }
    completion_item.insertText = expand_built_in_vars(completion_item.data.body)

    callback(completion_item)
end

--- Executes the completion item
---@param completion_item lsp.CompletionItem # The completion item to execute
---@param callback fun(ci: lsp.CompletionItem) # The callback to execute
function M:execute(completion_item, callback)
    dbg(completion_item)
    callback(completion_item)
end

cmp.register_source(M.name, M --[[@as cmp.Source]])
