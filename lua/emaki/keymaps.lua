local config = require("emaki.config")

local M = {}

---@param buf integer
function M.apply(buf)
  local session = require("emaki.session")
  local keys = config.options.keys

  ---@param lhs string|false
  local function map(lhs, rhs, desc)
    if lhs and lhs ~= "" then
      vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = "emaki: " .. desc, silent = true })
    end
  end

  map(keys.next_page, function()
    session.goto_page(buf, function(page)
      return page + 1
    end)
  end, "next page")

  map(keys.prev_page, function()
    session.goto_page(buf, function(page)
      return page - 1
    end)
  end, "previous page")

  map(keys.last_page, function()
    session.goto_page(buf, function(_, pages)
      return pages
    end)
  end, "last page")

  map(keys.first_page, function()
    session.goto_page(buf, function()
      return 1
    end)
  end, "first page")

  map(keys.zoom_in, function()
    session.zoom(buf, config.options.zoom_step)
  end, "zoom in")

  map(keys.zoom_out, function()
    session.zoom(buf, -config.options.zoom_step)
  end, "zoom out")

  map(keys.fit_width, function()
    session.fit_width(buf)
  end, "fit page to window width")

  map(keys.goto_page, function()
    vim.ui.input({ prompt = "Page: " }, function(input)
      local page = tonumber(input)
      if page then
        session.goto_page(buf, function()
          return page
        end)
      end
    end)
  end, "go to page")

  map(keys.extract_text, function()
    session.extract_text(buf)
  end, "extract text layer")
end

return M
