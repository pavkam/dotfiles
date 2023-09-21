return {
    'NeogitOrg/neogit',
    enabled = false,
    keys = function(_, keys)
        -- wipe existing mappings
        for k in pairs (keys) do
            keys[k] = nil
        end
    end
}
