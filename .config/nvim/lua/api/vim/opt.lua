---@alias vim.opt.Value boolean|number|string|string[]
---@alias vim.opt.Setting vim.opt.Value
---@alias vim.opt.Descriptor table<string, vim.opt.Setting>

--- Sets Vim options
---@param opts vim.opt.Descriptor|vim.opt.Descriptor[] # The options to set
function vim.opt.apply(opts)
    assert(opts)
    opts = vim.to_list(opts)

    for key, value in pairs(opts) do
        assert(type(key) == 'string')

        local value_type = type(value)

        if vim.list_contains({ 'boolean', 'number', 'string', 'table' }, value_type) then
            local ok, err = pcall(function()
                vim.opt[key] = value
            end)

            if not ok then
                vim.error(string.format('Failed to set option "%s" to `%s`: %s', key, value, vim.inspect(err)))
            end
        end
    end
end
