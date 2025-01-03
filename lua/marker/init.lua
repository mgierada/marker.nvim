local Menu = require("snipe.menu")
local state = require("marker.state")

local M = {}

local PREVIEW_WINDOW_TITLE_COPY = "Mark Preview:"
local WINDOW_TITLE_COPY = "Global Marks"
local MAX_HIGHT_PREVIEW = 30

--- Retrieve marks and filter only alphabetic ones (A-Z).
--- @return Mark[] List of marks with only alphabetic names
local get_marks = function()
  --- @class GlobalMarks
  --- @field items table  -- List of marks from Vim
  --- @field buffer_name fun(mark_name: string): string

  --- @type GlobalMarks
  local global_marks = {
    items = vim.fn.getmarklist(),

    --- Get the buffer name for a mark.
    --- @param mark_name string
    --- @return string
    buffer_name = function(mark_name, opts)
      return vim.api.nvim_get_mark(mark_name, {})[4]
    end,
  }

  local marks = { global_marks }

  --- @type Mark[]
  local marks_table = {}

  for _, v in ipairs(marks) do
    for _, m in ipairs(v.items) do
      local mark = string.sub(m.mark, 2, 3)

      -- Only include alphabetic marks (A-Z)
      if not mark:match("^%a$") then
        goto continue
      end

      local bufnum, lnum, col, _ = unpack(m.pos)
      local buffer_name = v.buffer_name(mark, lnum)
      local line_to_display = string.format("%s %6d %4d %s", mark, lnum, col - 1, buffer_name)

      --- @type Mark
      local row = {
        line = line_to_display,
        lnum = lnum,
        colnum = col,
        file = m.file or "",
        bufnum = bufnum,
      }

      -- Alphanumeric marks (A-Z) go to the main table
      table.insert(marks_table, row)

      ::continue::
    end
  end

  if not marks_table or vim.tbl_isempty(marks_table) then
    vim.notify("No marks found", vim.log.levels.INFO)
    return {}
  end
  return marks_table
end

--- Preview a specific mark in a floating window.
--- @param mark Mark The mark to preview
local function preview_mark(mark)
  if not state.preview_enabled then
    -- Close the preview window if it exists
    if _G.preview_state and _G.preview_state.win_id and vim.api.nvim_win_is_valid(_G.preview_state.win_id) then
      vim.api.nvim_win_close(_G.preview_state.win_id, true)
    end
    return
  end

  if not mark.file or mark.file == "" then
    return
  end

  -- Define a global reference for the preview window and buffer
  if not _G.preview_state then
    _G.preview_state = { win_id = nil, buf_id = nil }
  end

  -- Resolve the file path
  local resolved_file = vim.fn.expand(mark.file)         -- Expand `~` to full path
  resolved_file = vim.fn.fnamemodify(resolved_file, ":p") -- Convert to absolute path

  -- Determine the buffer to load content from
  local buf
  if vim.fn.bufname() == resolved_file then
    -- Use the current buffer if it's the same as the mark's file
    buf = vim.api.nvim_get_current_buf()
  else
    -- Otherwise, add and load the file in a hidden buffer
    buf = vim.fn.bufadd(resolved_file)
    vim.fn.bufload(buf)
  end

  -- Lines to load for the preview
  local PREVIEW_LINES = 15
  local start_line_to_load = math.max(0, mark.lnum - 1) -- Ensure valid line number
  local end_line_to_load = start_line_to_load + PREVIEW_LINES

  -- Get the specific lines to preview
  local lines = vim.api.nvim_buf_get_lines(buf, start_line_to_load, end_line_to_load, false)
  if not lines or vim.tbl_isempty(lines) then
    vim.notify("No content found in preview", vim.log.levels.INFO)
    return
  end

  local highlight_line = mark.lnum - start_line_to_load -- Adjust for the preview starting line

  -- Create or update the floating window and buffer
  local preview_buf, win_id
  if _G.preview_state.win_id and vim.api.nvim_win_is_valid(_G.preview_state.win_id) then
    -- Reuse the existing preview buffer and window
    preview_buf = _G.preview_state.buf_id
    if not vim.api.nvim_buf_is_valid(preview_buf) then
      preview_buf = vim.api.nvim_create_buf(false, true)
      _G.preview_state.buf_id = preview_buf
    end
    win_id = _G.preview_state.win_id
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, vim.list_extend({ PREVIEW_WINDOW_TITLE_COPY }, lines))
    vim.api.nvim_buf_clear_namespace(preview_buf, -1, 0, -1) -- Clear previous highlights
    if highlight_line > 0 and highlight_line <= #lines then
      vim.api.nvim_buf_add_highlight(preview_buf, -1, "Visual", highlight_line, 0, -1)
    end
  else
    -- Determine window dimensions
    local win_width = math.min(80, vim.o.columns - 4)
    -- local win_height = math.min(#lines + 2, 30) -- Height based on content, max 30
    local win_height = math.min(MAX_HIGHT_PREVIEW)
    local screen_width = vim.o.columns
    local screen_height = vim.o.lines
    local win_row = math.floor((screen_height - win_height) / 2)
    local win_col = math.floor((screen_width - win_width) / 2)

    -- Floating window options
    local opts = {
      relative = "editor",
      width = win_width,
      height = win_height,
      row = win_row,
      col = win_col,
      style = "minimal",
      border = "single",
    }

    -- Create a new buffer and floating window
    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, vim.list_extend({ PREVIEW_WINDOW_TITLE_COPY }, lines))
    if highlight_line > 0 and highlight_line <= #lines then
      vim.api.nvim_buf_add_highlight(preview_buf, -1, "Visual", highlight_line, 0, -1)
    end

    win_id = vim.api.nvim_open_win(preview_buf, false, opts)
    _G.preview_state.buf_id = preview_buf
    _G.preview_state.win_id = win_id

    -- Close the preview window when leaving the buffer
    M.auto_close_on_leave(win_id)
  end
end

--- Automatically close the floating window when leaving the buffer.
--- @param win_id number The window ID to close
--- @return nil
function M.auto_close_on_leave(win_id)
  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    callback = function()
      if vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
      end
    end,
    once = true,
  })
end

--- Toggle the preview state.
--- @return nil
function M.toggle_preview()
  state.preview_enabled = not state.preview_enabled

  -- Get the currently hovered item
  local hovered_item = nil
  if _G.menu_instance then
    local menu = _G.menu_instance
    if menu and menu.items and menu.hovered then
      hovered_item = menu.items[menu:hovered()]
    end
  end

  if not state.preview_enabled then
    -- Close the preview window and clean up the state
    if _G.preview_state and _G.preview_state.win_id and vim.api.nvim_win_is_valid(_G.preview_state.win_id) then
      vim.api.nvim_win_close(_G.preview_state.win_id, true)
    end
    _G.preview_state = nil
  else
    -- Preview the hovered item immediately, if available
    if hovered_item then
      preview_mark(hovered_item)
    end
  end
end

-- Expose open_marks_menu in the module table
M.open_marks_menu = function(opts)
  local marks = get_marks()

  local menu = Menu:new({
    position = opts.position,
    open_win_override = { title = WINDOW_TITLE_COPY },
  })

  menu:add_new_buffer_callback(function(m)
    -- Save the menu instance globally
    _G.menu_instance = m

    vim.keymap.set("n", opts.mappings.cancel, function()
      m:close()
      _G.menu_instance = nil -- Clear the menu instance when closing
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
      vim.api.nvim_win_set_cursor(new_win, { item.lnum, item.colnum - 1 })
    end, { nowait = true, buffer = m.buf })

    vim.keymap.set("n", opts.mappings.preview, function()
      M.toggle_preview() -- Toggle preview state

      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = m.buf,
        callback = function()
          if state.preview_enabled then
            local hovered_item = m.items[m:hovered()]
            if hovered_item then
              preview_mark(hovered_item)
            end
          end
        end,
        desc = "Update mark preview on hover after pressing 'p'",
        once = false, -- Keep running until the menu is closed
      })
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
    preview = "p",
  },
}

M.setup = function(opts)
  local config = vim.tbl_deep_extend("force", default_config, opts or {})

  vim.keymap.set("n", config.mappings.open, function()
    M.open_marks_menu(config)
  end, { desc = "Find global marks" })
end

return M
