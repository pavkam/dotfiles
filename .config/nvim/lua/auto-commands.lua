local utils = require 'utils'
local ui = require 'utils.ui'

-- highlight on yank
utils.auto_command(
    "TextYankPost",
    function() vim.highlight.on_yank() end,
    "*"
)

-- resize splits if window got resized
utils.auto_command(
    "VimResized",
    function()
        local current_tab = vim.fn.tabpagenr()
        vim.cmd("tabdo wincmd =")
        vim.cmd("tabnext " .. current_tab)
    end
)

-- go to last loc when opening a buffer
utils.auto_command(
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

-- close some filetypes with <q>
utils.auto_command(
    "FileType",
    function(evt)
        vim.bo[evt.buf].buflisted = false

        local has_mapping = vim.tbl_isempty(vim.fn.maparg("q", "n", 0, 1))
        if not has_mapping then
            vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = evt.buf, silent = true })
        end
    end,
    ui.special_buffer_file_types
)

-- wrap and check for spell in text filetypes
utils.auto_command(
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

-- Auto create dir when saving a file, in case some intermediate directory does not exist
utils.auto_command(
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
utils.auto_command(
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
utils.auto_command(
    "TermOpen",
    function()
        vim.opt_local.foldcolumn = "0"
        vim.opt_local.signcolumn = "no"
        vim.opt_local.statuscolumn = nil
    end
)

-- mkview and loadview for real files
utils.auto_command(
    { "BufWinLeave", "BufWritePost", "WinLeave" },
    function(args)
        if vim.b[args.buf].view_activated then vim.cmd.mkview { mods = { emsg_silent = true } } end
    end
)

utils.auto_command(
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

-- leave vim if last window is closed
utils.auto_command(
    "WinClosed",
    function(evt)
        local listed_buffers = vim.fn.getbufinfo({ buflisted = 1 })
        local open_buffers = vim.tbl_filter(
            function(buffer)
                return #buffer.windows > 1 or (#buffer.windows == 1 and buffer.windows[1] ~= tonumber(evt.match))
            end,
            listed_buffers
        )
        local modified_buffers = vim.tbl_filter(
            function(buffer)
                return buffer.changed
            end,
            listed_buffers
        )

        local filetype = vim.api.nvim_get_option_value("filetype", { buf = evt.buf })
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = evt.buf })

        if #open_buffers == 0 and not ui.is_special_buffer(evt.buf) then
            if #modified_buffers > 0 then
                utils.warn("There are unsaved changes in some buffers. Will not exit!")
                vim.schedule(function() vim.cmd("b" .. modified_buffers[1].bufnr) end)
            else
                vim.cmd('qa')
            end
        end
    end
)
