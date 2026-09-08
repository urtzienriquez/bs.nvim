--- Tests for keymap wiring and the marks deck window.
local bs = require("bs")
local deck = require("bs.deck")
local marks = require("bs.marks")

bs.setup({ notify = false })

describe("bs keymaps", function()
	it("binds mark, unmark, deck and terminal keys", function()
		assert.is_true(vim.fn.maparg("<A-m>a", "n") ~= "", "<A-m>a marks")
		assert.is_true(vim.fn.maparg("<A-,>a", "n") ~= "", "<A-,>a unmarks")
		assert.is_true(vim.fn.maparg("<leader>'", "n") ~= "", "<leader>' opens the deck")
		assert.is_true(vim.fn.maparg("<C-s>", "n") ~= "", "<C-s> toggles the terminal")
		assert.is_true(vim.fn.maparg("'<C-s>", "n") ~= "", "'<C-s> shows the terminal here")
	end)
end)

describe("bs deck", function()
	before_each(function()
		if deck.win_id ~= nil and vim.api.nvim_win_is_valid(deck.win_id) then
			deck.close()
		end
		marks.clear()
	end)

	it("opens a floating marks window", function()
		local win = deck.open()
		assert.is_true(vim.api.nvim_win_is_valid(win), "deck window exists")
		assert.is_true(vim.api.nvim_buf_is_valid(deck.bufnr), "deck buffer exists")
		local tail = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(deck.bufnr), ":t")
		assert.are.same("bs-marks", tail)
	end)

	it("closes the deck and clears its state", function()
		deck.open()
		assert.is_true(vim.api.nvim_win_is_valid(deck.win_id))

		deck.close()
		assert.is_nil(deck.win_id)
		assert.is_nil(deck.bufnr)
	end)

	it("renders one row per mark", function()
		local path = vim.fn.tempname()
		vim.cmd("edit " .. vim.fn.fnameescape(path))
		assert.is_true(marks.mark("a"))

		deck.open()
		local lines = vim.api.nvim_buf_get_lines(deck.bufnr, 0, -1, false)
		assert.are.same(1, #lines)

		deck.close()
	end)
end)
