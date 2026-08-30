---@class emaki.Config
local M = {}

---@class emaki.Opts
local defaults = {
  -- Blank buffer lines inserted between consecutive pages.
  gap = 2,
  -- Narrowest page width, in terminal cells.
  min_cols = 20,
  -- Columns added or removed by one zoom step.
  zoom_step = 10,
  -- Pages kept rendered beyond the visible range, in either direction.
  -- Raising this smooths fast scrolling at the cost of more conversions.
  preload_pages = 1,
  -- Resolution used to rasterise a page. The page is only ever scaled down
  -- from this, so it bounds how far you can zoom in before the image softens.
  density = 240,
  -- snacks.image trims PDF pages to their ink bounding box and reports the
  -- same DPI it rasterised at. The first destroys the page aspect ratio this
  -- plugin computes row counts from; the second cancels out in snacks' cell
  -- maths and caps a page at roughly 99 columns on any terminal.
  -- Both are corrected by rewriting the conversion arguments. Set to false to
  -- keep your own snacks configuration, accepting undersized pages.
  patch_snacks_convert = true,
  keys = {
    next_page = "]p",
    prev_page = "[p",
    last_page = "]P",
    first_page = "[P",
    zoom_in = "+",
    zoom_out = "-",
    fit_width = "=",
    goto_page = "<leader>pg",
    extract_text = "<leader>pt",
  },
  -- Window options applied to the viewer. Anything that changes the width of
  -- the text area shifts the page and clips its right edge, so the number and
  -- sign columns are removed by default.
  wo = {
    wrap = false,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    statuscolumn = "",
    list = false,
    spell = false,
    cursorcolumn = false,
  },
  -- Rendered into the window bar. Receives the session.
  ---@type fun(info: { name: string, page: integer, pages: integer, cols: integer }): string
  winbar = function(info)
    return (" %s   %d / %d   %d cols "):format(info.name, info.page, info.pages, info.cols)
  end,
}

---@type emaki.Opts
M.options = vim.deepcopy(defaults)

---@param opts? emaki.Opts
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

function M.defaults()
  return vim.deepcopy(defaults)
end

return M
