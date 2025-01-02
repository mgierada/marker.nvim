local Menu = require("snipe.menu")

local M = {}

--- @class Mark
--- @field line string  -- The formatted display line for the mark
--- @field lnum number  -- The line number of the mark
--- @field colnum number   -- The column number of the mark
--- @field file string  -- The file associated with the mark (empty if none)
--- @field bufnum number   -- The buffer number of the mark

local PREVIEW_WINDOW_TITLE_COPY = "Mark Preview:"
local WINDOW_TITLE_COPY = "Global Marks"

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
	if not mark.file or mark.file == "" then
		return
	end

	-- Determine the buffer to load content from
	local buf

	local current_buf_name = vim.fn.bufname()
	local file_exists = mark.file
	vim.notify("Current buffer: " .. current_buf_name, vim.log.levels.INFO)
	vim.notify("Mark file: " .. mark.file, vim.log.levels.INFO)

	if vim.fn.bufname() == mark.file then
		-- Use the current buffer if it's the same as the mark's file
		vim.notify("Previewing mark in current buffer", vim.log.levels.INFO)
		buf = vim.api.nvim_get_current_buf()
	else
		-- Otherwise, add and load the file in a hidden buffer
		vim.notify("Previewing mark in hidden buffer", vim.log.levels.INFO)
		buf = vim.fn.bufadd(mark.file)
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

	-- Determine window dimensions
	local win_width = math.min(80, vim.o.columns - 4)
	local win_height = math.min(#lines + 2, 30) -- Height based on content, max 30
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

	-- Create a new buffer for the preview
	local preview_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, vim.list_extend({ PREVIEW_WINDOW_TITLE_COPY }, lines))

	-- Open the floating window with the preview buffer
	local win_id = vim.api.nvim_open_win(preview_buf, false, opts)

	-- Automatically close the floating window when navigating away
	vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave" }, {
		callback = function()
			if vim.api.nvim_win_is_valid(win_id) then
				vim.api.nvim_win_close(win_id, true)
			end
		end,
		once = true,
	})
end

-- Expose open_marks_menu in the module table
M.open_marks_menu = function(opts)
	local marks = get_marks()

	local menu = Menu:new({
		position = opts.position,
		open_win_override = { title = WINDOW_TITLE_COPY },
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
			vim.api.nvim_win_set_cursor(new_win, { item.lnum, item.colnum - 1 })
		end, { nowait = true, buffer = m.buf })

		vim.keymap.set("n", opts.mappings.preview, function()
			local hovered = m:hovered()
			local item = m.items[hovered]
			preview_mark(item)
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
