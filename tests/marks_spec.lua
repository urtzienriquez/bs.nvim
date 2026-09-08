--- Tests for bs marks: mark/unmark/list order, jump + cursor restore, file
--- reopen, and the confirm-before-reassign behaviour.
local bs = require("bs")
local marks = require("bs.marks")
local config = require("bs.config")

bs.setup({ notify = false })

local function edit_temp_file()
	local path = vim.fn.tempname()
	vim.cmd("edit " .. vim.fn.fnameescape(path))
	return path
end

describe("bs marks", function()
	before_each(function()
		marks.clear()
	end)

	it("marks the current buffer and lists in insertion order", function()
		local a = edit_temp_file()
		assert.is_true(marks.mark("a"))
		local b = edit_temp_file()
		assert.is_true(marks.mark("b"))

		local rows = marks.list()
		assert.are.same(2, #rows)
		assert.are.same("a", rows[1].char)
		assert.are.same(a, rows[1].path)
		assert.are.same("b", rows[2].char)
		assert.are.same(b, rows[2].path)
	end)

	it("refuses to mark the same buffer under a second key", function()
		edit_temp_file()
		assert.is_true(marks.mark("a"))
		assert.is_false(marks.mark("b"))
		assert.is_nil(marks.marks["b"])
	end)

	it("re-marking the same buffer under its own key is a no-op", function()
		edit_temp_file()
		assert.is_true(marks.mark("a"))
		assert.is_true(marks.mark("a"))
		assert.are.same(1, #marks.list())
	end)

	it("refuses to mark an unnamed buffer", function()
		vim.cmd("enew")
		assert.is_false(marks.mark("a"))
		assert.is_nil(marks.marks["a"])
	end)

	it("asks before re-assigning a key and keeps the old mark when declined", function()
		local a = edit_temp_file()
		assert.is_true(marks.mark("a"))
		edit_temp_file()

		local asked = false
		local function decline()
			asked = true
			return false
		end
		assert.is_false(marks.mark("a", { confirm = decline }))
		assert.is_true(asked, "confirmation was requested")
		assert.are.same(a, marks.marks["a"].path)
		assert.are.same(1, #marks.list())
	end)

	it("re-assigns when confirmed and keeps a single deck row", function()
		local a = edit_temp_file()
		assert.is_true(marks.mark("a"))
		local b = edit_temp_file()

		local function accept()
			return true
		end
		assert.is_true(marks.mark("a", { confirm = accept }))
		assert.are.same(b, marks.marks["a"].path)
		assert.are.same(1, #marks.list())
	end)

	it("skips the confirmation when confirm_reassign is disabled", function()
		edit_temp_file()
		assert.is_true(marks.mark("a"))
		local b = edit_temp_file()

		config.options.confirm_reassign = false
		assert.is_true(marks.mark("a")) -- no opts; must not block
		config.options.confirm_reassign = true

		assert.are.same(b, marks.marks["a"].path)
		assert.are.same(1, #marks.list())
	end)

	it("unmarks and drops it from the listing order", function()
		edit_temp_file()
		assert.is_true(marks.mark("a"))
		edit_temp_file()
		assert.is_true(marks.mark("b"))

		assert.is_true(marks.unmark("a"))
		local rows = marks.list()
		assert.are.same(1, #rows)
		assert.are.same("b", rows[1].char)
	end)

	it("jumps back to the marked buffer and its cursor position", function()
		local path = edit_temp_file()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
		vim.api.nvim_win_set_cursor(0, { 3, 2 })
		assert.is_true(marks.mark("a"))

		edit_temp_file()
		assert.is_true(marks.jump("a"))
		assert.are.same(path, vim.fn.expand("%:p"))

		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		assert.are.same(3, row)
		assert.are.same(2, col)
	end)

	it("reopens a wiped file mark from disk", function()
		local path = edit_temp_file()
		assert.is_true(marks.mark("a"))
		local buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_delete(buf, {})

		edit_temp_file()
		assert.is_true(marks.jump("a"))
		assert.are.same(path, vim.fn.expand("%:p"))
	end)
end)
