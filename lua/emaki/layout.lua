-- Where each page sits once the whole document is laid out as one tall buffer.
-- A page occupies `rows` buffer lines and is followed by `gap` blank ones.

local config = require("emaki.config")

local M = {}

-- snacks encodes the row and column of each image cell as a combining
-- diacritic on U+10EEEE, and only 297 diacritics are available. A placement
-- wider or taller than this silently loses the excess, which reads as the
-- page being cut off.
M.MAX_CELLS = 297

---Ask snacks for the cell size it would use, so rounding matches exactly.
---Computing the aspect ratio here instead drifts by a row and shows up as a
---gap under every page, or as pages overlapping.
---
---The rasterised page is always larger than the box we ask for, so fit() takes
---the scale-down branch; feeding it an oversized image keeps it there.
---@param doc emaki.Document
---@param box { width: integer, height: integer }
---@return { width: integer, height: integer }
local function fit(doc, box)
  return Snacks.image.util.fit("", box, {
    info = { size = { width = doc.width * 10, height = doc.height * 10 }, dpi = { width = 72, height = 72 } },
  })
end

---Widest page the placeholder encoding can represent, with the height kept
---within the same limit.
---@param doc emaki.Document
---@return integer
function M.limit_cols(doc)
  local size = fit(doc, { width = M.MAX_CELLS, height = M.MAX_CELLS })
  return math.max(config.options.min_cols, size.width)
end

---@class emaki.Layout
---@field pages integer
---@field cols integer
---@field rows integer
---@field gap integer
---@field block integer rows + gap

---@param doc emaki.Document
---@param cols integer requested page width in cells
---@return emaki.Layout
function M.build(doc, cols)
  local size = fit(doc, { width = cols, height = 9999 })
  local rows = math.max(1, size.height)
  local gap = config.options.gap
  return { pages = doc.pages, cols = size.width, rows = rows, gap = gap, block = rows + gap }
end

---@param layout emaki.Layout
---@return integer
function M.total_lines(layout)
  return layout.pages * layout.block
end

---First buffer line of a page, 1-indexed.
---@param layout emaki.Layout
---@param page integer
---@return integer
function M.page_row(layout, page)
  return (page - 1) * layout.block + 1
end

---Which page a buffer line belongs to, and how far into it.
---@param layout emaki.Layout
---@param row integer
---@return integer page, number fraction 0..1
function M.locate(layout, row)
  local index = math.max(0, row - 1)
  local page = math.min(layout.pages, math.floor(index / layout.block) + 1)
  return page, (index % layout.block) / layout.block
end

return M
