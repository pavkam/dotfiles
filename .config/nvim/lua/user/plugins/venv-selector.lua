return {
    "linux-cultist/venv-selector.nvim",
    ft = { 'python' },
    keys = function(_, keys)
        -- wipe existing mappings
        for k in pairs (keys) do
            keys[k] = nil
        end
    end
}
