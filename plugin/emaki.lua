if vim.g.loaded_emaki then
  return
end
vim.g.loaded_emaki = true

-- snacks.image sets filetype=image on buffers it recognises, before it creates
-- the placement. Deferring lets that finish so emaki can replace it.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("emaki_attach", { clear = true }),
  pattern = "image",
  callback = function(event)
    vim.schedule(function()
      require("emaki").attach(event.buf)
    end)
  end,
})

vim.api.nvim_create_user_command("EmakiInspect", function()
  require("emaki").inspect(0)
end, { desc = "emaki: show measured layout" })
