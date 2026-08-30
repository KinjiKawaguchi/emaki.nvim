std = "luajit"
cache = true

-- `vim` is writable (vim.g.loaded_emaki, vim.bo[...] = ...), Snacks is not.
globals = { "vim" }
read_globals = { "Snacks" }

ignore = {
  "631", -- line is too long; stylua owns formatting
}
