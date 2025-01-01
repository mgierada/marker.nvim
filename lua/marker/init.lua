local Menu = require("snipe.menu")

local M = {}

local get_marks = function()
  local global_marks = {
    items = vim.fn.getmarklist(),

    --- @param mark_name string
    --- @return string
    buffer_name = function(mark_name)
      return vim.api.nvim_get_mark(mark_name, {})[4]
    end,
  }

  local marks = { global_marks }

  local marks_table = {}

  for _, v in ipairs(marks) do
    for _, m in ipairs(v.items) do
      local mark = string.sub(m.mark, 2, 3)

      -- Only include alphabetic marks (A-Z)
      if not mark:match("^%a$") then
        goto continue
      end

      local buf, lnum, col, _ = unpack(m.pos)
      local name = v.buffer_name(mark, lnum)
      local line = string.format("%s %6d %4d %s", mark, lnum, col - 1, name)

      local row = {
        line = line,
        lnum = lnum,
        col = col,
        file = m.file or "",
        buf = buf,
      }

      -- Alphanumeric marks (A-Z) go to the main table
      table.insert(marks_table, row)

      ::continue::
    end
  end

  -- marks_table = vim.fn.extend(marks_table, marks_others)

  if not marks_table or vim.tbl_isempty(marks_table) then
    vim.notify("No marks found", vim.log.levels.INFO)
    return {}
  end
  return marks_table
end

-- Expose open_marks_menu in the module table
M.open_marks_menu = function(opts)
  local marks = get_marks()

  local menu = Menu:new({
    position = opts.position,
    open_win_override = { title = "Global Marks" },
  })

  menu:add_new_buffer_callback(function(m)
    vim.keymap.set("n", opts.mappings.cancel, function()
      m:close()
    end, { nowait = true, buffer = m.buf })

    vim.keymap.set("n", opts.mappings.select, function()
      local hovered = m:hovered()
      local item = m.items[hovered]
      m:close()
      if item.file and item.file ~= "" then
        vim.cmd("edit " .. item.file)
      else
        vim.api.nvim_set_current_buf(item.buf)
      end
      local new_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(new_win, { item.lnum, item.col - 1 })
    end, { nowait = true, buffer = m.buf })
  end)

  menu:open(marks, function(m, i)
    local item = marks[i]
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(win, { item.lnum, item.col - 1 })
    m:close()
  end, function(mark_item)
    return mark_item.line
  end)
end

local default_config = {
  position = "cursor",
  mappings = {
    cancel = "<esc>",
    open = "<leader>ml",
    select = "<cr>",
  },
}

M.setup = function(opts)
  local config = vim.tbl_deep_extend("force", default_config, opts or {})

  vim.keymap.set("n", config.mappings.open, function()
    M.open_marks_menu(config)
  end, { desc = "Find global marks" })
end

return M
