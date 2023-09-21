local astro_utils = require "astronvim.utils"

return {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(opts)
        opts.open_files_do_not_replace_types = astro_utils.list_insert_unique(opts.open_files_do_not_replace_types, { "neotest-output" })
        opts.default_component_configs = { with_markers = true }
    end
}
