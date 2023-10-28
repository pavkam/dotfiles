local utils = require 'utils'
local ui = require 'utils.ui'

-- highlight on yank
utils.on_event(
    "TextYankPost",
    function() vim.highlight.on_yank() end,
    "*"
)

-- resize splits if window got resized
utils.on_event(
    "VimResized",
    function()
        local current_tab = vim.fn.tabpagenr()
        vim.cmd("tabdo wincmd =")
        vim.cmd("tabnext " .. current_tab)
    end
)

-- go to last loc when opening a buffer
utils.on_event(
    "BufReadPost",
    function()
        local exclude = { "gitcommit" }
        local buf = vim.api.nvim_get_current_buf()

        if vim.tbl_contains(exclude, vim.bo[buf].filetype) then
            return
        end

        local mark = vim.api.nvim_buf_get_mark(buf, '"')
        local lcount = vim.api.nvim_buf_line_count(buf)

        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end
)

-- TODO: not working in help buffers
-- close some filetypes with <q>
utils.on_event(
    "FileType",
    function(evt)
        vim.bo[evt.buf].buflisted = false

        local has_mapping = not vim.tbl_isempty(vim.fn.maparg("q", "n", 0, 1))
        if not has_mapping then
            vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = evt.buf, silent = true, remap = true })
        end
    end,
    ui.special_file_types
)

-- wrap and check for spell in text filetypes
utils.on_event(
    "FileType",
    function()
        vim.opt_local.wrap = true
        vim.opt_local.spell = true
    end,
    {
        "gitcommit",
        "markdown",
    }
)

-- quick-fix functionality
utils.on_event(
    "FileType",
    function(evt)
        if ui.is_special_buffer(evt.buf) then
            return
        end

        vim.keymap.set(
            "n", "<leader>qa",
            function ()
                local r, c = unpack(vim.api.nvim_win_get_cursor(0))
                local line = vim.api.nvim_get_current_line()
                if not line or line == '' then
                    line = '<empty>'
                end

                utils.info(string.format("Added position **%d:%d** to quick-fix list.", r, c))

                vim.fn.setqflist({
                    {
                        bufnr = vim.api.nvim_get_current_buf(),
                        lnum = r,
                        col = c,
                        text = line
                    },
                }, "a")

                vim.api.nvim_command("copen")
                vim.api.nvim_command("wincmd p")
            end,
            { desc = "Add quick-fix item" }
        )

        vim.keymap.set(
            "n", "<leader>qA",
            function ()
                local r, c = unpack(vim.api.nvim_win_get_cursor(0))
                local line = vim.api.nvim_get_current_line()
                if not line or line == '' then
                    line = '<empty>'
                end

                utils.info(string.format("Added position **%d:%d** to locations list.", r, c))
                vim.fn.setloclist(0, {
                    {
                        bufnr = vim.api.nvim_get_current_buf(),
                        lnum = r,
                        col = c,
                        text = line
                    },
                }, "a")

                vim.api.nvim_command("lopen")
                vim.api.nvim_command("wincmd p")
            end,
            { desc = "Add location item" }
        )
    end
)

utils.on_event(
    "FileType",
    function(evt)
        vim.keymap.set('n', 'x', function ()
            if package.loaded["bqf"] then
                require('bqf').hidePreviewWindow()
            end

            local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
            local qftype
            if info.quickfix == 0 then
                qftype = nil
            elseif info.loclist == 0 then
                qftype = "c"
            else
                qftype = "l"
            end

            local list = qftype == "l" and vim.fn.getloclist(0) or vim.fn.getqflist()
            local r, c = unpack(vim.api.nvim_win_get_cursor(0))

            table.remove(list, r)

            local close = #list == 0
            if qftype == "l" then
                vim.fn.setloclist(0, list)
                vim.cmd("lclose")
            else
                vim.fn.setqflist(list)
                vim.cmd("cclose")
            end

            r = math.min(r, #list)
            if (r > 0) then
                vim.api.nvim_win_set_cursor(0, { r, c })
            end
        end, { desc = 'Remove item', buffer = evt.buf })

        vim.keymap.set('n', '<del>', 'x', { desc = "Remove item", buffer = evt.buf, remap = true })
        vim.keymap.set('n', '<bs>', 'x', { desc = "Remove item", buffer = evt.buf, remap = true })
    end,
    "qf"
)

-- Auto create dir when saving a file, in case some intermediate directory does not exist
utils.on_event(
    "BufWritePre",
    function(evt)
        if evt.match:match("^%w%w+://") then
            return
        end

        local file = vim.loop.fs_realpath(evt.match) or evt.match
        vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end
)

-- HACK: re-caclulate folds when entering a buffer through Telescope
-- @see https://github.com/nvim-telescope/telescope.nvim/issues/699
utils.on_event(
    "BufEnter",
    function()
        if vim.opt.foldmethod:get() == "expr" then
            vim.schedule(function() vim.opt.foldmethod = "expr" end)
        end
    end
)

-- better search
vim.on_key(
    function(char)
        if vim.fn.mode() == "n" then
            local new_hlsearch = vim.tbl_contains({ "<CR>", "n", "N", "*", "#", "?", "/" }, vim.fn.keytrans(char))
            if vim.opt.hlsearch:get() ~= new_hlsearch then
                vim.opt.hlsearch = new_hlsearch
            end
        end
    end,
    vim.api.nvim_create_namespace("auto_hlsearch")
)

-- HACK: Disable custom statuscolumn for terminals because truncation/wrapping bug
-- https://github.com/neovim/neovim/issues/25472
utils.on_event(
    "TermOpen",
    function()
        vim.opt_local.foldcolumn = "0"
        vim.opt_local.signcolumn = "no"
        vim.opt_local.statuscolumn = nil
    end
)

-- mkview and loadview for real files
utils.on_event(
    { "BufWinLeave", "BufWritePost", "WinLeave" },
    function(args)
        if vim.b[args.buf].view_activated then vim.cmd.mkview { mods = { emsg_silent = true } } end
    end
)

utils.on_event(
    "BufWinEnter",
    function(evt)
        if not vim.b[evt.buf].view_activated then
            local filetype = vim.api.nvim_get_option_value("filetype", { buf = evt.buf })
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = evt.buf })
            local ignore_filetypes = { "gitcommit", "gitrebase", "svg", "hgcommit" }

            if buftype == "" and filetype and filetype ~= "" and not vim.tbl_contains(ignore_filetypes, filetype) then
                vim.b[evt.buf].view_activated = true
                vim.cmd.loadview { mods = { emsg_silent = true } }
            end
        end
    end
)

-- clear root path cache when LSP changes
utils.on_event(
    { "LspDetach", "LspAttach", "BufWritePost" },
    function(evt)
        if vim.api.nvim_buf_is_valid(evt.buf) then
            vim.b[evt.buf].root_path_cache = nil
        end
    end
)

-- emit a warning when an LSP is dettached!
utils.on_event(
    { "LspDetach" },
    function(evt)
        -- TODO: only compain once per client not per buffer!
        local client = vim.lsp.get_client_by_id(evt.data.client_id)
        utils.warn("Language Server *" .. client.name .. "* has detached!")
    end
)

-- file detection commands
utils.on_event(
    { "BufReadPost", "BufNewFile", "BufWritePost" },
    function(evt)
        local current_file = vim.fn.resolve(vim.fn.expand "%")

        -- if custom events have been triggered, bail
        if vim.b[evt.buf].custom_events_triggered then
            return
        end

        if not ui.is_special_buffer(evt.buf) then
            utils.trigger_user_event("NormalFile")

            if utils.file_is_under_git(current_file) then
                utils.trigger_user_event("GitFile")
            end
        end

        -- do not retrigger these events if the file name is set
        if current_file ~= "" then
            vim.b[evt.buf].custom_events_triggered = true
        end
    end
)
