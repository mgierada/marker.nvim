local Menu = require("snipe.menu")

local M = {}

--- @class Mark
--- @field line string  -- The formatted display line for the mark
--- @field lnum number  -- The line number of the mark
--- @field colnum number   -- The column number of the mark
--- @field file string  -- The file associated with the mark (empty if none)
--- @field bufnum number   -- The buffer number of the mark

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

	-- Open the file in a hidden buffer to get its content
	--- @type number
	local buf = vim.fn.bufadd(mark.file)
	vim.fn.bufload(buf)

	-- Get the specific line to preview
	--- @type string|nil
	local line_content = vim.api.nvim_buf_get_lines(buf, mark.lnum - 1, mark.lnum, false)[1]
	line_content = line_content or "[Empty Line]"

	-- Determine window dimensions
	--- @type number
	local win_width = math.min(80, vim.api.nvim_get_option("columns") - 4)
	--- @type number
	local win_height = 3

	-- Calculate center position
	--- @type number
	local screen_width = vim.o.columns
	--- @type number
	local screen_height = vim.o.lines
	--- @type number
	local win_row = math.floor((screen_height - win_height) / 2)
	--- @type number
	local win_col = math.floor((screen_width - win_width) / 2)

	--- @type table<string, any>
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
	--- @type number
	local preview_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "Preview:", line_content })

	-- Open the floating window with the preview buffer
	--- @type number
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
