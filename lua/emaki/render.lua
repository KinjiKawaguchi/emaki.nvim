-- Materialises only the pages near the viewport and drops the rest, so a
-- three hundred page document costs the same as a three page one.

local config = require("emaki.config")
local layout = require("emaki.layout")

local M = {}

local patched = false

---Rewrite the PDF conversion arguments snacks uses. See `patch_snacks_convert`
---in the configuration for why both changes are needed.
function M.patch_convert()
  if patched or not config.options.patch_snacks_convert then
    return
  end
  patched = true
  local convert = Snacks.image.config.convert
  convert.magick = convert.magick or {}
  convert.magick.pdf = {
    "-density",
    config.options.density,
    "{src}[{page}]",
    "-background",
    "white",
    "-alpha",
    "remove",
    -- Metadata only; this does not resample the image.
    "-units",
    "PixelsPerInch",
    "-density",
    96,
  }
end

---@param session emaki.Session
---@param page integer
local function place(session, page)
  local row = layout.page_row(session.layout, page)
  local ok, placement = pcall(Snacks.image.placement.new, session.buf, ("%s#page=%d"):format(session.file, page), {
    pos = { row, 0 },
    -- Without an explicit range only one line of the image overlays real
    -- buffer text and the remainder becomes virtual lines, which desynchronises
    -- page positions from line numbers.
    range = { row, 0, row + session.layout.rows - 1, 0 },
    conceal = true,
    -- snacks otherwise treats the buffer as belonging to a single image: it
    -- pins the view to line 1 on every update, blanks the buffer while
    -- converting, and clears the whole namespace when falling back. None of
    -- that can coexist with stacked pages.
    inline = true,
    width = session.layout.cols,
    height = session.layout.rows,
    auto_resize = false,
  })
  if ok then
    session.placements[page] = placement
  end
end

---@param session emaki.Session
---@param page integer
local function unplace(session, page)
  local placement = session.placements[page]
  if placement then
    pcall(function()
      placement:close()
    end)
    session.placements[page] = nil
  end
end

---@param session emaki.Session
function M.clear(session)
  for page in pairs(session.placements) do
    unplace(session, page)
  end
end

---@param session emaki.Session
---@return integer|nil first, integer|nil last
local function visible_pages(session)
  local win = vim.fn.bufwinid(session.buf)
  if win == -1 then
    return nil, nil
  end
  local margin = session.layout.block * config.options.preload_pages
  local top = math.max(1, vim.fn.line("w0", win) - margin)
  local bottom = vim.fn.line("w$", win) + margin
  -- locate() also returns a fraction; bind explicitly so the extra value does
  -- not leak into the caller's argument list.
  local first = layout.locate(session.layout, top)
  local last = layout.locate(session.layout, bottom)
  return first, last
end

---@param session emaki.Session
function M.sync(session)
  if not vim.api.nvim_buf_is_valid(session.buf) then
    return
  end
  M.patch_convert()
  local first, last = visible_pages(session)
  if not first then
    return
  end
  for page in pairs(session.placements) do
    if page < first or page > last then
      unplace(session, page)
    end
  end
  for page = first, last do
    if not session.placements[page] then
      place(session, page)
    end
  end
end

return M
