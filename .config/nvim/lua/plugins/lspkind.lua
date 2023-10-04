return {
    "onsails/lspkind.nvim",
    opts = {
        mode = "symbol",
        symbol_map = require("utils.icons").SourceSymbols,
        menu = {},
    },
    config = function(_, opts)
        require("lspkind").init(opts)
    end
}
