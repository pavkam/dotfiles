return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            {
                "theHamsta/nvim-dap-virtual-text",
                dependencies = {
                    "mfussenegger/nvim-dap"
                },
                opts = {}
            },
            {
                "leoluz/nvim-dap-go",
                dependencies = {
                    "mfussenegger/nvim-dap"
                },
                config = true,
            },
            {
                "mfussenegger/nvim-dap-python",
                dependencies = {
                    "mfussenegger/nvim-dap",
                    "williamboman/mason.nvim",
                },
                ft = "python",
                config = function(_, opts)
                    local path = require("mason-registry").get_package("debugpy"):get_install_path() .. "/venv/bin/python"
                    require("dap-python").setup(path, opts)
                end,
            },
            {
                "mxsdev/nvim-dap-vscode-js",
                dependencies = {
                    "mfussenegger/nvim-dap",
                    {
                        "microsoft/vscode-js-debug",
                        build = "npm ci --legacy-peer-deps && npx gulp vsDebugServerBundle && (rm out || true) && mv dist out"
                    }
                },
                config = function()
                    local function get_js_debug()
                        local path = vim.fn.stdpath "data"
                        return path .. "/lazy/vscode-js-debug"
                    end

                    require("dap-vscode-js").setup {
                        node_path = "node",
                        debugger_path = get_js_debug(),
                        adapters = {"pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost"}
                    }
                end
            },
            {
                "rcarriga/nvim-dap-ui",
                dependencies = {
                    "mfussenegger/nvim-dap"
                },
                keys = {
                    {
                        "<leader>dU",
                        function()
                            require("dapui").toggle({})
                        end,
                        desc = "Toggle UI"
                    },
                    {
                        "<leader>de",
                        function()
                            require("dapui").eval()
                        end,
                        desc = "Evaluate",
                        mode = {"n", "v"}
                    },
                },
                opts = {},
                config = function(_, opts)
                    local dap = require("dap")
                    local dapui = require("dapui")

                    dapui.setup(opts)
                    dap.listeners.after.event_initialized["dapui_config"] = function()
                        dapui.open({})
                    end
                    dap.listeners.before.event_terminated["dapui_config"] = function()
                        dapui.close({})
                    end
                    dap.listeners.before.event_exited["dapui_config"] = function()
                        dapui.close({})
                    end
                end,
            },
            {
                "jay-babu/mason-nvim-dap.nvim",
                dependencies = {
                    "williamboman/mason.nvim",
                    "mfussenegger/nvim-dap",
                },
                cmd = {
                    "DapInstall",
                    "DapUninstall"
                },
                opts = {
                    automatic_installation = true,
                },
                opts = {
                    ensure_installed = {
                        "bash",
                        "coreclr",
                        "python",
                        "js",
                        "delve"
                    }
                }
            },
        },
        keys = {
            { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
            { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
            { "<leader>dc",
                function()
                    local dap_setup = require 'utils.dap'
                    dap_setup.continue();
                end,
                desc = "Continue"
            },
            { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
            { "<leader>dg", function() require("dap").goto_() end, desc = "Go to line (no execute)" },
            { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
            { "<leader>dj", function() require("dap").down() end, desc = "Down" },
            { "<leader>dk", function() require("dap").up() end, desc = "Up" },
            { "<leader>dl", function() require("dap").run_last() end, desc = "Run Last" },
            { "<leader>dO", function() require("dap").step_out() end, desc = "Step Out" },
            { "<leader>do", function() require("dap").step_over() end, desc = "Step Over" },
            { "<leader>dP", function() require("dap").pause() end, desc = "Pause" },
            { "<leader>dR", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
            { "<leader>ds", function() require("dap").session() end, desc = "Session" },
            { "<leader>dQ", function() require("dap").terminate() end, desc = "Terminate" },
            { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Inspect Symbol" },
        },
        config = function()
            local icons = require "utils.icons"

            vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

            for name, sign in pairs(icons.dap) do
                sign = type(sign) == "table" and sign or { sign }
                vim.fn.sign_define(
                    "Dap" .. name,
                    { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
                )
            end
        end,
    }
}
