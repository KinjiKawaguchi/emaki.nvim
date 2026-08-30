local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error

---@param name string
---@param hint string
local function check_executable(name, hint)
  if vim.fn.executable(name) == 1 then
    local version = vim.system({ name, "--version" }, { text = true }):wait()
    local line = vim.split(vim.trim((version.stdout or "") .. (version.stderr or "")), "\n")[1] or ""
    ok(("`%s` found %s"):format(name, line ~= "" and ("(" .. line .. ")") or ""))
    return true
  end
  error(("`%s` not found — %s"):format(name, hint))
  return false
end

local function check_tools()
  start("emaki: external tools")
  check_executable("pdfinfo", "install poppler-utils; needed for page count and paper size")
  check_executable("pdftotext", "install poppler-utils; needed for text extraction")
  check_executable("gs", "install ghostscript; ImageMagick delegates PDF rasterisation to it")
  if vim.fn.executable("magick") == 1 then
    ok("`magick` found (ImageMagick 7)")
  elseif vim.fn.executable("convert") == 1 then
    ok("`convert` found (ImageMagick 6); snacks falls back to it automatically")
  else
    error("neither `magick` nor `convert` found — install ImageMagick")
  end
end

local function check_snacks()
  start("emaki: snacks.image")
  if not rawget(_G, "Snacks") or not Snacks.image then
    error("snacks.nvim with the image module is required")
    return false
  end
  ok("snacks.image is loaded")
  if Snacks.image.config.enabled == false then
    error("snacks.image is disabled — set `image = { enabled = true }` in your snacks options")
    return false
  end
  ok("snacks.image is enabled")
  return true
end

local function check_terminal()
  start("emaki: terminal")
  local env = Snacks.image.terminal.env()
  if not env.placeholders then
    error(
      ("terminal %q does not support unicode placeholders — emaki needs kitty or Ghostty. "):format(env.name or "?")
        .. "Without them images are drawn at a fixed window position and cannot scroll with the buffer."
    )
    return
  end
  ok(("terminal %q supports unicode placeholders"):format(env.name))
  if env.remote then
    warn("remote session detected — page images are base64 encoded over the connection, which can feel slow")
  end
  local size = Snacks.image.terminal.size()
  ok(("cell size %dx%d px, scale %s"):format(size.cell_width, size.cell_height, tostring(size.scale)))
end

local function check_config()
  start("emaki: configuration")
  local config = require("emaki.config").options
  if config.patch_snacks_convert then
    ok("snacks PDF conversion arguments will be rewritten (page aspect ratio and size cap)")
  else
    warn("`patch_snacks_convert` is off — pages may be trimmed to their content and capped near 99 columns")
  end
  ok(("rasterisation density %d dpi"):format(config.density))
end

function M.check()
  check_tools()
  if check_snacks() then
    check_terminal()
  end
  check_config()
end

return M
