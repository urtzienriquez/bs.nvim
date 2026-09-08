--- Terminal toggle, porting the author's `ctrl_s_shell` vimscript to Lua in
--- full. The idea: one reusable terminal buffer with unlimited scrollback that
--- keeps running even when its window is hidden, so you can send it work and
--- come back later.
---
---   `<C-s>`         toggle: open / focus the terminal, or return to the
---                   window you came from when it is focused. An existing
---                   terminal is brought to the foreground wherever it is
---                   (previous window, this tabpage, or another tabpage);
---                   otherwise a fresh one opens in a new tabpage.
---   `'<C-s>`        "here": show the terminal in the *current* window (split
---                   nothing, create it there if needed).
---   `[count]<C-s>`  always open the terminal as a split `count` lines tall,
---                   skipping the foreground paths.
---
--- Leaving the terminal cleans up after itself: when it was alone in its
--- tabpage, that tabpage is closed. Toggling keymaps work both in normal mode
--- and inside the terminal buffer itself.

local M = {}

local config = require("bs.config")

---@type number|nil
M.buf = nil

---@type number|nil
M.prevwin = nil

---Buffer the `here` terminal displaced; restore it when leaving a lone-window
--- terminal (`:terminal` can co-opt an empty `[No Name]` buffer, in which case
--- the alternate buffer IS the terminal and is useless as a restore target).
---@type number|nil
M.prevbuf = nil

local function is_valid(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function in_terminal()
	return is_valid(M.buf) and vim.api.nvim_get_current_buf() == M.buf
end

---Remember the currently focused window as the place to return to (never a
--- terminal window).
local function remember_prev()
	local w = vim.api.nvim_get_current_win()
	if vim.bo[vim.api.nvim_get_current_buf()].buftype ~= "terminal" then
		M.prevwin = w
	end
end

---Create a fresh terminal buffer.
---@param count integer split height when >0 (opens a split instead of a tab)
---@param here boolean show it in the current window instead of a new tabpage
local function create_terminal(count, here)
	if not here then
		if count > 0 then
			vim.cmd(count .. "split")
		elseif config.options.terminal.here then
			vim.cmd("split")
		else
			vim.cmd("tab split")
		end
	end

	vim.cmd("terminal")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].scrollback = config.options.terminal.scrollback or -1
	vim.bo[buf].buflisted = false
	M.buf = buf

	-- Inside the terminal, the toggle key leaves terminal mode first (plain
	-- `<Cmd>` would run mid-terminal-mode and leave the window limbo-like) and
	-- then flips back to the previous window.
	local toggle = config.options.terminal.toggle
	if toggle and toggle ~= "" then
		vim.keymap.set("t", toggle, "<C-\\><C-n><Cmd>lua require('bs.terminal').toggle()<CR>", { buffer = buf })
	end
end

---Leave the terminal: go back to the previous window and, if the terminal
--- was alone in its tabpage, close that tabpage.
local function leave_terminal()
	if not in_terminal() then
		return
	end
	local left_tab = vim.api.nvim_get_current_tabpage()
	local term_win = vim.api.nvim_get_current_win()

	-- A `'<C-s>` here-terminal lives in the window we left: restore that
	-- window's previous buffer in place instead of jumping elsewhere (the
	-- previous-window would be this very window, which only shows the
	-- terminal, and `wincmd p` could land on an unrelated helper window).
	if M.prevbuf and M.prevwin == term_win then
		local rest = M.prevbuf
		if rest and vim.api.nvim_buf_is_valid(rest) and rest ~= M.buf and vim.bo[rest].buftype ~= "terminal" then
			vim.api.nvim_win_set_buf(term_win, rest)
		else
			-- The displaced buffer was absorbed by `:terminal` (fresh nvim,
			-- empty `[No Name]`); give the window a clean scratch buffer.
			vim.cmd("enew")
		end
		M.prevbuf = nil
		return
	end

	local ok = false
	if M.prevwin and vim.api.nvim_win_is_valid(M.prevwin) and vim.api.nvim_win_get_buf(M.prevwin) ~= M.buf then
		ok = pcall(vim.api.nvim_set_current_win, M.prevwin)
	end
	if not ok then
		vim.cmd("wincmd p")
	end

	-- The terminal was the only window in its tabpage: close the tabpage.
	local left_wins = vim.api.nvim_tabpage_list_wins(left_tab)
	if
		#left_wins == 1
		and vim.api.nvim_get_current_tabpage() ~= left_tab
		and vim.api.nvim_win_get_buf(left_wins[1]) == M.buf
	then
		pcall(vim.api.nvim_win_close, left_wins[1], true)
	end

	-- Still looking at the terminal: jump to another real (editable, non-helper)
	-- window in this tabpage.
	if in_terminal() then
		local moved = false
		for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local wbuf = vim.api.nvim_win_get_buf(w)
			local bt = vim.bo[wbuf].buftype
			if w ~= term_win and bt ~= "terminal" and bt ~= "nofile" then
				vim.api.nvim_set_current_win(w)
				moved = true
				break
			end
		end
		if not moved then
			-- Nothing to put back (fresh nvim: the empty `[No Name]` buffer
			-- was absorbed by `:terminal`): give the terminal window a clean
			-- scratch buffer.
			vim.api.nvim_set_current_win(term_win)
			vim.cmd("enew")
		end
	end

	-- Remember the terminal window so a later toggle-in can return to it
	-- directly (matches the reference `prevwid` bookkeeping).
	M.prevwin = term_win
end

---Open the existing (hidden) terminal in a window: a new tabpage by default,
--- or a split when `config.here` is set. The caller has already recorded the
--- window to return to in `M.prevwin`.
local function show_hidden_terminal()
	if config.options.terminal.here then
		vim.cmd("split")
	else
		vim.cmd("tab split")
	end
	vim.api.nvim_win_set_buf(0, M.buf)
	vim.bo[M.buf].buflisted = false
end

---Toggle the terminal: focus it, create it, or return to the previous window.
---@param count integer when >0, always open the terminal as a split of that
---        height (skips the foreground logic, like `[count]<C-s>`).
---@param here boolean? show the terminal in the current window (`'<C-s>`).
function M.toggle(count, here)
	count = count or vim.v.count or 0
	here = here or false

	if in_terminal() then
		leave_terminal()
		return
	end

	-- The window we are leaving; toggling out later returns to it (the
	-- reference's `prevwid` bookkeeping).
	local leaving = vim.api.nvim_get_current_win()

	if here then
		-- `'<C-s>`: put the terminal in the current window.
		M.prevwin = leaving
		M.prevbuf = vim.api.nvim_win_get_buf(leaving)
		if not is_valid(M.buf) then
			create_terminal(0, true)
		else
			vim.api.nvim_win_set_buf(leaving, M.buf)
		end
		return
	end

	if count > 0 then
		-- `[count]<C-s>`: force a split `count` lines tall.
		M.prevwin = leaving
		if not is_valid(M.buf) then
			create_terminal(count, false)
			return
		end
		vim.cmd(count .. "split")
		pcall(vim.api.nvim_win_set_buf, 0, M.buf)
		return
	end

	if not is_valid(M.buf) then
		M.prevwin = leaving
		create_terminal(0, false)
		return
	end

	-- The previous window already shows the terminal: just return to it.
	if M.prevwin and vim.api.nvim_win_is_valid(M.prevwin) and vim.api.nvim_win_get_buf(M.prevwin) == M.buf then
		vim.api.nvim_set_current_win(M.prevwin)
		return
	end

	-- Visible in this tabpage?
	local w = vim.fn.bufwinid(M.buf)
	if w > 0 then
		M.prevwin = leaving
		vim.api.nvim_set_current_win(w)
		return
	end

	-- Visible in another tabpage?
	local ws = vim.fn.win_findbuf(M.buf)
	if not vim.tbl_isempty(ws) then
		M.prevwin = leaving
		vim.api.nvim_set_current_win(ws[1])
		return
	end

	-- Living but hidden: re-show it.
	M.prevwin = leaving
	show_hidden_terminal()
end

---Wipe the terminal buffer.
function M.close()
	if is_valid(M.buf) then
		pcall(vim.api.nvim_buf_delete, M.buf, { force = true })
	end
	M.buf = nil
end

return M
