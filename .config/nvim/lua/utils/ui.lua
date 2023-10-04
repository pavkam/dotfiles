-- general UI functionality
local icons = require 'utils.icons'

M = {}

local function get_signs(win)
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.tbl_map(function(sign)
        return vim.fn.sign_getdefined(sign.name)[1]
    end, vim.fn.sign_getplaced(buf, { group = "*", lnum = vim.v.lnum })[1].signs)
end

local function icon(sign, len)
    sign = sign or {}
    len = len or 1

    local text = vim.fn.strcharpart(sign.text or "", 0, len) ---@type string

    text = text .. string.rep(" ", len - vim.fn.strchars(text))

    return sign.texthl and ("%#" .. sign.texthl .. "#" .. text .. "%*") or text
end

function M.fold_text()
    local ok = pcall(vim.treesitter.get_parser, vim.api.nvim_get_current_buf())
    local ret = ok and vim.treesitter.foldtext and vim.treesitter.foldtext()
    if not ret then
        ret = {
            {
                vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1], {}
            }
        }
    end

    table.insert(ret, { " " .. icons.ellipsis })
    return ret
end

function M.status_column()
  local win = vim.g.statusline_winid

  if vim.wo[win].signcolumn == "no" then
    return ''
  end

  ---@type Sign?,Sign?,Sign?
  local left, right, fold
  for _, s in ipairs(get_signs(win)) do
    if s.name:find("GitSign") then
      right = s
    elseif not left then
      left = s
    end
  end

  vim.api.nvim_win_call(win, function()
    if vim.fn.foldclosed(vim.v.lnum) >= 0 then
      fold = { text = vim.opt.fillchars:get().foldclose or "", texthl = "Folded" }
    end
  end)

  local nu = ""
  if vim.wo[win].number and vim.v.virtnum == 0 then
    nu = vim.wo[win].relativenumber and vim.v.relnum ~= 0 and vim.v.relnum or vim.v.lnum
  end

  return table.concat({
    icon(left),
    [[%=]],
    nu .. " ",
    icon(fold or right, 2),
  }, "")
end

function M.hl_fg_color(name)
  ---@type {foreground?:number}?
  local hl = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name }) or vim.api.nvim_get_hl_by_name(name, true)
  local fg = hl and hl.fg or hl.foreground
  return fg and { fg = string.format("#%06x", fg) }
end

return M
