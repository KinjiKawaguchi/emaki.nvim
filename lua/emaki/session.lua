-- One session per PDF buffer: the scaffolding of blank lines the pages sit on,
-- the zoom level, and the autocommands that keep them in step.

local config = require("emaki.config")
local layout = require("emaki.layout")
local pdf = require("emaki.pdf")
local render = require("emaki.render")

local M = {}

---@class emaki.Session
---@field buf integer
---@field file string
---@field doc emaki.Document
---@field layout emaki.Layout
---@field placements table<integer, any>

---@type table<integer, emaki.Session>
local sessions = {}

---@param buf integer
---@return emaki.Session|nil
function M.get(buf)
  return sessions[buf == 0 and vim.api.nvim_get_current_buf() or buf]
end

---Widest the page may be: the text area, capped by what the placeholder
---encoding can represent.
---@param buf integer
---@param doc emaki.Document
---@return integer
local function max_cols(buf, doc)
  local win = vim.fn.bufwinid(buf)
  local available = vim.o.columns
  if win ~= -1 then
    local info = vim.fn.getwininfo(win)[1]
    available = info.width - info.textoff
  end
  return math.max(config.options.min_cols, math.min(available, layout.limit_cols(doc)))
end

---@param buf integer
local function apply_wo(buf)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    for key, value in pairs(config.options.wo) do
      pcall(vim.api.nvim_set_option_value, key, value, { scope = "local", win = win })
    end
  end
end

---@param session emaki.Session
local function fill(session)
  local lines = {}
  for i = 1, layout.total_lines(session.layout) do
    lines[i] = ""
  end
  vim.bo[session.buf].modifiable = true
  vim.api.nvim_buf_set_lines(session.buf, 0, -1, false, lines)
  vim.bo[session.buf].modifiable = false
  vim.bo[session.buf].modified = false
end

---@param session emaki.Session
local function update_winbar(session)
  local win = vim.fn.bufwinid(session.buf)
  if win == -1 then
    return
  end
  local page = layout.locate(session.layout, vim.api.nvim_win_get_cursor(win)[1])
  local text = config.options.winbar({
    name = vim.fn.fnamemodify(session.file, ":t"),
    page = page,
    pages = session.layout.pages,
    cols = session.layout.cols,
  })
  pcall(vim.api.nvim_set_option_value, "winbar", text:gsub("%%", "%%%%"), { scope = "local", win = win })
end

M.update_winbar = update_winbar

---Rebuild the page positions at a new width, keeping the spot in the document
---that the cursor was on.
---@param session emaki.Session
---@param cols integer
local function relayout(session, cols)
  local win = vim.fn.bufwinid(session.buf)
  local page, fraction = 1, 0
  if win ~= -1 then
    page, fraction = layout.locate(session.layout, vim.api.nvim_win_get_cursor(win)[1])
  end

  render.clear(session)
  session.layout = layout.build(session.doc, cols)
  fill(session)

  if win ~= -1 then
    local row = layout.page_row(session.layout, page) + math.floor(fraction * session.layout.block)
    row = math.max(1, math.min(row, layout.total_lines(session.layout)))
    vim.api.nvim_win_set_cursor(win, { row, 0 })
  end
  render.sync(session)
  update_winbar(session)
end

---@param buf integer
---@param delta integer
function M.zoom(buf, delta)
  local session = M.get(buf)
  if not session then
    return
  end
  local cols = math.max(config.options.min_cols, math.min(session.layout.cols + delta, max_cols(buf, session.doc)))
  if cols ~= session.layout.cols then
    relayout(session, cols)
  end
end

---@param buf integer
function M.fit_width(buf)
  local session = M.get(buf)
  if session then
    relayout(session, max_cols(buf, session.doc))
  end
end

---@param buf integer
---@param resolve fun(page: integer, pages: integer): integer
function M.goto_page(buf, resolve)
  local session = M.get(buf)
  local win = session and vim.fn.bufwinid(session.buf) or -1
  if win == -1 then
    return
  end
  local current = layout.locate(session.layout, vim.api.nvim_win_get_cursor(win)[1])
  local page = math.max(1, math.min(resolve(current, session.layout.pages), session.layout.pages))
  vim.api.nvim_win_set_cursor(win, { layout.page_row(session.layout, page), 0 })
  vim.cmd("normal! zt")
  render.sync(session)
  update_winbar(session)
end

---@param buf integer
function M.extract_text(buf)
  local session = M.get(buf)
  if not session then
    return
  end
  pdf.text(session.file, function(lines, err)
    if not lines then
      vim.notify(err or "pdftotext failed", vim.log.levels.ERROR, { title = "emaki" })
      return
    end
    vim.cmd.tabnew()
    local text_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(text_buf, 0, -1, false, lines)
    pcall(vim.api.nvim_buf_set_name, text_buf, session.file .. " [text]")
    for key, value in pairs({
      buftype = "nofile",
      filetype = "text",
      modifiable = false,
      modified = false,
      swapfile = false,
    }) do
      vim.bo[text_buf][key] = value
    end
  end)
end

---@param session emaki.Session
local function setup_autocmds(session)
  local group = vim.api.nvim_create_augroup("emaki_" .. session.buf, { clear = true })
  vim.api.nvim_create_autocmd({ "WinScrolled", "CursorMoved" }, {
    group = group,
    buffer = session.buf,
    callback = function()
      render.sync(session)
      update_winbar(session)
    end,
  })
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = group,
    buffer = session.buf,
    callback = function()
      local limit = max_cols(session.buf, session.doc)
      if session.layout.cols > limit then
        relayout(session, limit)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    buffer = session.buf,
    callback = function()
      apply_wo(session.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = session.buf,
    callback = function()
      render.clear(session)
      sessions[session.buf] = nil
    end,
  })
end

---snacks creates its own placement for the buffer and leaves `inline` unset, so
---an unconverted image starts a progress spinner on an 80ms timer. Every tick
---clears the whole snacks namespace, which erases the pages emaki draws.
---
---Two details make this awkward to wait out. The timer stops only when the
---placement reports itself ready, and `close()` makes ready() permanently
---false — so closing that placement mid-conversion strands the timer for the
---rest of the session. And when the timer does stop it returns without removing
---the extmark it drew, so a stale "loading" mark is left behind and its mere
---presence says nothing about whether the timer is still alive.
---
---So test liveness instead: the timer replaces the extmark on every tick, and a
---new extmark gets a new id. An id that survives a poll interval means the
---timer has stopped. A cached page never spins at all, which is why restarting
---Neovim appeared to fix this.
---@param buf integer
---@param done fun()
local function after_snacks_settles(buf, done)
  local ns = Snacks.image.placement.ns
  local POLL_MS = 150
  local GRACE_MS = 300
  local LIMIT_MS = 60000

  ---@return integer|nil
  local function spinner_id()
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
      for _, chunk in ipairs((mark[4] or {}).virt_text or {}) do
        if chunk[2] == "SnacksImageLoading" then
          return mark[1]
        end
      end
    end
  end

  local uv = vim.uv or vim.loop
  local timer = assert(uv.new_timer())
  local waited, last, seen = 0, nil, false

  timer:start(
    POLL_MS,
    POLL_MS,
    vim.schedule_wrap(function()
      waited = waited + POLL_MS
      local valid = vim.api.nvim_buf_is_valid(buf)
      if valid and waited < LIMIT_MS then
        local id = spinner_id()
        if id then
          seen = true
          -- Still being redrawn; keep waiting.
          if id ~= last then
            last = id
            return
          end
        elseif not seen and waited < GRACE_MS then
          -- Give the spinner a moment to appear before deciding there is none.
          return
        end
      end
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
      if valid then
        done()
      end
    end)
  )
end

---@param buf integer
---@param on_error fun(err: string)
function M.open(buf, on_error)
  local file = vim.api.nvim_buf_get_name(buf)
  if sessions[buf] then
    return
  end
  if vim.fn.filereadable(file) == 0 then
    return on_error("file is not readable")
  end

  local doc, err = pdf.probe(file)
  if not doc then
    return on_error(err or "could not read the PDF")
  end

  after_snacks_settles(buf, function()
    if sessions[buf] or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    -- Take over the single first-page placement snacks created. Clearing the
    -- namespace afterwards removes the spinner extmark, which close() leaves
    -- behind because it is not one of the placement's tracked ids.
    Snacks.image.placement.clean(buf)
    vim.api.nvim_buf_clear_namespace(buf, Snacks.image.placement.ns, 0, -1)
    apply_wo(buf)

    local session = { buf = buf, file = file, doc = doc, placements = {} }
    session.layout = layout.build(doc, max_cols(buf, doc))
    sessions[buf] = session

    fill(session)
    setup_autocmds(session)
    require("emaki.keymaps").apply(buf)
    render.sync(session)
    update_winbar(session)
  end)
end

return M
