-- emaki.nvim - read PDFs in Neovim as one continuously scrolling document.
--
-- Pages are rendered as images by snacks.image and stacked down a single
-- buffer, so ordinary motions scroll the document. Only the pages near the
-- viewport are materialised.

local config = require("emaki.config")

local M = {}

---@param opts? emaki.Opts
function M.setup(opts)
  config.setup(opts)
end

---Take over a buffer that snacks.image has opened as an image.
---@param buf integer
function M.attach(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local file = vim.api.nvim_buf_get_name(buf)
  if file:lower():sub(-4) ~= ".pdf" then
    return
  end
  if not rawget(_G, "Snacks") or not Snacks.image then
    vim.notify("emaki requires snacks.nvim with the image module enabled", vim.log.levels.ERROR, { title = "emaki" })
    return
  end

  require("emaki.session").open(buf, function(err)
    vim.notify(("emaki could not open this PDF: %s"):format(err), vim.log.levels.ERROR, { title = "emaki" })
  end)
end

---@param buf? integer
function M.zoom(buf, delta)
  require("emaki.session").zoom(buf or 0, delta)
end

---@param buf? integer
function M.fit_width(buf)
  require("emaki.session").fit_width(buf or 0)
end

---@param buf? integer
---@param page integer
function M.goto_page(buf, page)
  require("emaki.session").goto_page(buf or 0, function()
    return page
  end)
end

---@param buf? integer
function M.extract_text(buf)
  require("emaki.session").extract_text(buf or 0)
end

---Diagnostic dump; the measurements only exist in a real terminal.
---@param buf? integer
function M.inspect(buf)
  local layout = require("emaki.layout")
  local session = require("emaki.session").get(buf or 0)
  if not session then
    vim.notify("no emaki session in this buffer", vim.log.levels.WARN, { title = "emaki" })
    return
  end
  local win = vim.fn.bufwinid(session.buf)
  local info = win ~= -1 and vim.fn.getwininfo(win)[1] or {}
  local term = Snacks.image.terminal.size()
  local env = Snacks.image.terminal.env()
  local pages = vim.tbl_keys(session.placements)
  table.sort(pages)

  local out = {
    ("terminal  %s  placeholders=%s remote=%s"):format(env.name, tostring(env.placeholders), tostring(env.remote)),
    ("cell      %dx%d px  scale=%s"):format(term.cell_width, term.cell_height, tostring(term.scale)),
    ("window    width=%s height=%s textoff=%s"):format(info.width, info.height, info.textoff),
    ("paper     %gx%g pt  limit %d cols"):format(session.doc.width, session.doc.height, layout.limit_cols(session.doc)),
    ("layout    %d cols x %d rows  gap %d  total %d lines"):format(
      session.layout.cols,
      session.layout.rows,
      session.layout.gap,
      layout.total_lines(session.layout)
    ),
    ("rendered  pages %s"):format(table.concat(vim.tbl_map(tostring, pages), ", ")),
  }
  local sample = session.placements[pages[1]]
  if sample then
    local ok, state = pcall(sample.state, sample)
    if ok then
      out[#out + 1] = ("actual    %d cols x %d rows"):format(state.loc.width, state.loc.height)
    end
  end
  vim.notify(table.concat(out, "\n"), vim.log.levels.INFO, { title = "emaki" })
end

return M
