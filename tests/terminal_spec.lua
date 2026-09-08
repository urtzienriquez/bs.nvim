--- Tests for the terminal toggle (the headless-safe subset: tab create/close,
--- re-focus, count split, and the `'<C-s>` here-toggle restore).
local bs = require("bs")
local term = require("bs.terminal")

bs.setup({ notify = false })

local function tab_count()
	return #vim.api.nvim_list_tabpages()
end

local function buftype()
	return vim.bo[vim.api.nvim_get_current_buf()].buftype
end

local function num_windows()
	return #vim.api.nvim_tabpage_list_wins(0)
end

describe("bs terminal", function()
	before_each(function()
		vim.cmd("only")
		vim.cmd("enew")
		term.buf = nil
		term.prevwin = nil
		term.prevbuf = nil
	end)

	it("opens in its own tab and closes the empty tab when toggled out", function()
		local before = tab_count()

		bs.terminal()
		assert.are.same("terminal", buftype())
		assert.are.same(before + 1, tab_count())
		assert.is_true(vim.api.nvim_buf_is_valid(term.buf), "terminal buffer recorded")

		bs.terminal()
		assert.are.not_same("terminal", buftype())
		assert.are.same(before, tab_count(), "empty terminal tab closed")
	end)

	it("re-focuses the existing terminal instead of creating a second one", function()
		bs.terminal()
		local first = term.buf

		bs.terminal() -- out
		assert.are.not_same("terminal", buftype())

		bs.terminal() -- back in
		assert.are.same(first, term.buf, "same terminal reused")
		assert.are.same("terminal", buftype())

		bs.terminal() -- leave again and clean up
		assert.are.not_same("terminal", buftype())
	end)

	it("opens as a split of the requested height with a count", function()
		local wins = num_windows()

		bs.terminal(3)
		assert.are.same(wins + 1, num_windows())
		assert.are.same("terminal", buftype())

		bs.terminal() -- out
		assert.are.not_same("terminal", buftype(), "cursor leaves the terminal split")
		assert.is_true(vim.api.nvim_buf_is_valid(term.buf), "terminal buffer kept")
	end)

	it("'here' shows the terminal in the current window and restores the file", function()
		local path = vim.fn.tempname()
		vim.cmd("edit " .. vim.fn.fnameescape(path))

		bs.terminal(0, true)
		assert.are.same("terminal", buftype())
		assert.are.same(1, num_windows(), "no split or tab in here mode")

		bs.terminal() -- out;
		assert.are.not_same("terminal", buftype())
		assert.are.same(path, vim.api.nvim_buf_get_name(0), "file restored in the window")
		assert.is_true(vim.api.nvim_buf_is_valid(term.buf), "terminal kept alive hidden")
	end)
end)
