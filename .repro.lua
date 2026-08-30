-- Minimal configuration for reproducing issues: nvim -u .repro.lua file.pdf
local root = vim.fn.fnamemodify("./.repro", ":p")
for _, name in ipairs({ "config", "data", "state", "cache" }) do
  vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end

local lazypath = root .. "/plugins/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.runtimepath:prepend(lazypath)

require("lazy").setup({
  root = root .. "/plugins",
  spec = {
    { "folke/snacks.nvim", opts = { image = { enabled = true } } },
    { dir = vim.fn.fnamemodify(".", ":p"), opts = {} },
  },
})
