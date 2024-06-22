return {
    'mfussenegger/nvim-dap-python',
    ft = 'python',
    dependencies = {
        'mfussenegger/nvim-dap',
    },
    opts = {
        console = 'internalConsole',
    },
    config = function(_, opts)
        local path = require('mason-registry').get_package('debugpy'):get_install_path() .. '/venv/bin/python3'
        require('dap-python').setup(path, opts)
    end,
}
