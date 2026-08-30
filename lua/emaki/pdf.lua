-- Thin wrappers over the poppler command line tools, with the failure modes
-- a viewer actually hits: missing binaries, encrypted files, damaged files.

local M = {}

-- A hung external tool must not take the editor with it.
local TIMEOUT_MS = 10000

---@param cmd string[]
---@return boolean ok, string output
local function run(cmd)
  local ok, result = pcall(function()
    return vim.system(cmd, { text = true, timeout = TIMEOUT_MS }):wait()
  end)
  if not ok then
    return false, tostring(result)
  end
  local output = vim.trim((result.stdout or "") .. (result.stderr or ""))
  return result.code == 0, output
end

---poppler prints a paragraph of syntax errors for a damaged file. Keep the
---first meaningful line so a notification stays readable.
---@param output string
---@return string
local function first_line(output)
  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not trimmed:lower():find("^syntax warning") then
      return trimmed
    end
  end
  return vim.trim(output)
end

---@class emaki.Document
---@field pages integer
---@field width number page width in points
---@field height number page height in points

---Read the page count and paper size.
---@param file string
---@return emaki.Document|nil doc, string|nil err
function M.probe(file)
  if vim.fn.executable("pdfinfo") == 0 then
    return nil, "pdfinfo not found; install poppler-utils"
  end

  local ok, output = run({ "pdfinfo", file })
  if not ok then
    -- pdfinfo reports a password prompt for encrypted files and a parse error
    -- for damaged ones. Both arrive here, so pass the message through rather
    -- than inventing one.
    if output:lower():find("password") then
      return nil, "encrypted PDF; emaki cannot open password protected files"
    end
    return nil, output ~= "" and first_line(output) or "pdfinfo failed"
  end

  local pages = tonumber(output:match("Pages:%s+(%d+)"))
  local width, height = output:match("Page size:%s+([%d%.]+)%s+x%s+([%d%.]+)")
  if not (pages and width and height) then
    return nil, "could not read page count or paper size from pdfinfo"
  end
  if pages < 1 then
    return nil, "PDF reports zero pages"
  end

  return {
    pages = pages,
    width = tonumber(width),
    height = tonumber(height),
  }
end

---Extract the text layer.
---@param file string
---@param on_done fun(lines: string[]|nil, err: string|nil)
function M.text(file, on_done)
  if vim.fn.executable("pdftotext") == 0 then
    return on_done(nil, "pdftotext not found; install poppler-utils")
  end
  vim.system({ "pdftotext", "-layout", file, "-" }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        return on_done(nil, vim.trim(result.stderr or "pdftotext failed"))
      end
      local lines = vim.split(result.stdout or "", "\n", { plain = true })
      -- A PDF with no text layer yields nothing useful; say so instead of
      -- opening an empty buffer.
      if #vim.tbl_filter(function(l)
        return vim.trim(l) ~= ""
      end, lines) == 0 then
        return on_done(nil, "no text layer in this PDF (scanned image?)")
      end
      on_done(lines)
    end)
  end)
end

return M
