local utils = require 'astronvim.utils'
local is_available = utils.is_available

return function(mappings)
    mappings.n['<leader>li'] = nil
    mappings.n['<leader>lI'] = nil

    mappings.n['<leader>s.'] = mappings.n['<leader>la']
    mappings.n['<leader>la'] = nil

    mappings.n['<leader>sF'] = mappings.n['<leader>lf']
    mappings.n['<leader>lf'] = nil

    mappings.n['<leader>lh'] = nil

    mappings.n['<leader>sr'] = mappings.n['<leader>lR']
    mappings.n['<leader>lR'] = nil

    mappings.n['<leader>sR'] = mappings.n['<leader>lr']
    mappings.n['<leader>lr'] = nil

    mappings.n['<leader>sD'] = mappings.n['<leader>lD']
    mappings.n['<leader>lD'] = nil

    mappings.n['<leader>sd'] = mappings.n['<leader>ld']
    mappings.n['<leader>ld'] = nil

    mappings.n['<leader>sS'] = mappings.n['<leader>lG']
    mappings.n['<leader>lG'] = nil

    mappings.n['<leader>sl'] = mappings.n['<leader>ll']
    mappings.n['<leader>ll'] = nil

    mappings.n['<leader>sL'] = mappings.n['<leader>lL']
    mappings.n['<leader>lL'] = nil


    if is_available "telescope.nvim" then
        local tbi = require 'telescope.builtin'
        mappings.n['<leader>si'] = { tbi.lsp_implementations, desc = "Search implementations" }
    end

    return mappings
end
