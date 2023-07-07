local neotest_ns = vim.api.nvim_create_namespace('neotest')

vim.diagnostic.config({
    virtual_text = {
        format = function(diagnostic)
            local message = diagnostic.message:gsub('\n', ' '):gsub('\t', ' '):gsub('%s+', ' '):gsub('^%s+', '')
            return message
        end
    }
}, neotest_ns)

local jest = require('neotest-jest')
jest = jest({
    jestCommand = "yarn test --",
    jestConfigFile = "jest.config.ts",
    env = {
        CI = true
    },
    cwd = function(path)
        return vim.fn.getcwd()
    end
}), require('neotest').setup({
    adapters = {require('neotest-go'), jest}
})
