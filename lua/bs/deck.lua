--- A harpoon-style floating marks deck.
---
--- `<leader>'` opens a floating window listing every mark, transient by
--- default: a mark key (or `<CR>`) jumps to that file and closes the deck,
--- so a single hop is two keystrokes with nothing to undo. Splits and tabs
--- (`<C-s>`/`<C-v>`/`<C-t>`) act on the highlighted row and close too.
---
--- Press `'` in the deck to make it **sticky**: mark keys keep the deck open
--- so you can flick from file to file (the highlighted row follows the file
--- you're looking at), and `<C-s>`/`<C-v>`/`<C-t>` still work — then `'`
--- again (or `<Esc>`) closes it. While sticky, the title changes to
--- indicate it.
---
--- Because `j`/`k` can be marks, moving the highlight uses `<C-p>`/`<C-n>`
--- (never close the deck). Everything runs on ordinary buffer-local keymaps
--- in a real window, so every key returns to the event loop and Neovim
--- repaints between keys — the same reason harpoon's UI never lags. No
--- blocking getchar loop, no temporary global mappings.

local marks = require("bs.marks")

local M = {}

---@type number?
M.win_id = nil
---@type number?
M.bufnr = nil
---@type number?
M.from_win = nil
---@type boolean
M.sticky = false

---Keys that must do nothing in the deck unless they map a mark or a command:
--- without this, unmarked letters (`j`, `k`, ...) fall through to the scratch
--- buffer's default normal-mode behaviour and move the cursor. `'` is
--- excluded on purpose (it toggles sticky).
---@type string[]
local BLOCK_KEYS = {}
for ch in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"):gmatch(".") do
	table.insert(BLOCK_KEYS, ch)
end
for _, k in ipairs({
	"<Up>",
	"<Down>",
	"<Left>",
	"<Right>",
	"<PageUp>",
	"<PageDown>",
	"<Home>",
	"<End>",
	"w",
	"b",
	"e",
	"0",
	"$",
	"^",
	"g",
	"{",
	"}",
	"(",
	")",
	"[",
	"]",
	"f",
	"F",
	"t",
	"T",
	"n",
	"N",
	"*",
	"#",
	"%",
	"/",
	"?",
	'"',
	"`",
	"<C-u>",
	"<C-d>",
	"<C-f>",
	"<C-b>",
	"<C-e>",
	"<C-y>",
}) do
	table.insert(BLOCK_KEYS, k)
end

---Path of the file the deck opened from (or its latest flick target); this
--- is what "current file" means while the deck itself holds focus.
---@return string
local function current_path()
	if M.from_win ~= nil and vim.api.nvim_win_is_valid(M.from_win) then
		return marks.identity(vim.api.nvim_win_get_buf(M.from_win))
	end
	return ""
end

---@return { char: string, path: string, current: boolean }[]
local function rows()
	local current = current_path()
	local out = {}
	for _, m in ipairs(marks.list()) do
		out[#out + 1] = { char = m.char, path = m.path, current = m.path == current }
	end
	return out
end

function M.close()
	if M.win_id ~= nil and vim.api.nvim_win_is_valid(M.win_id) then
		vim.api.nvim_win_close(M.win_id, true)
	end
	if M.bufnr ~= nil and vim.api.nvim_buf_is_valid(M.bufnr) then
		vim.api.nvim_buf_delete(M.bufnr, { force = true })
	end
	M.win_id, M.bufnr, M.from_win, M.sticky = nil, nil, nil, false
end

local function row_at_cursor()
	local r = vim.api.nvim_win_get_cursor(M.win_id)[1]
	return rows()[r]
end

local function move_cursor(delta)
	local r = vim.api.nvim_win_get_cursor(M.win_id)[1]
	local last = math.max(1, vim.api.nvim_buf_line_count(M.bufnr))
	r = math.max(1, math.min(r + delta, last))
	vim.api.nvim_win_set_cursor(M.win_id, { r, 0 })
end

---Jump `char` in the underlying window; closes the deck unless it is sticky.
local function jump_char(char)
	if M.from_win == nil or not vim.api.nvim_win_is_valid(M.from_win) then
		return
	end
	if not marks.jump(char, M.from_win) then
		return
	end
	if M.sticky then
		render()
	else
		local landing = M.from_win
		M.close()
		if vim.api.nvim_win_is_valid(landing) then
			vim.api.nvim_set_current_win(landing)
		end
	end
end

local function jump_highlighted()
	local row = row_at_cursor()
	if row then
		jump_char(row.char)
	end
end

---Open the highlighted mark in a split/tab; closes the deck unless sticky.
---@param kind "h"|"v"|"tab"
local function open_highlighted(kind)
	if M.win_id == nil or not vim.api.nvim_win_is_valid(M.win_id) then
		return
	end
	if M.from_win == nil or not vim.api.nvim_win_is_valid(M.from_win) then
		return
	end
	local row = row_at_cursor()
	if not row then
		return
	end
	local target
	local deck_win = M.win_id
	-- Operate from `from_win`. `nvim_set_current_win` (not `nvim_win_call`,
	-- which uses a "no_display" window switch) performs the proper
	-- leave/enter_tabpage side effects, so the tabline's size bookkeeping
	-- stays correct and the tabline doesn't vanish after the split/tab.
	if vim.api.nvim_win_is_valid(M.from_win) then
		vim.api.nvim_set_current_win(M.from_win)
		if kind == "tab" then
			-- `tab split` duplicates the current window's buffer into a new
			-- tabpage; `tabnew` would leave a stray `[No Name]` buffer behind
			-- once the jump below points the new window at the mark.
			vim.cmd("tab split")
		else
			vim.cmd(kind == "v" and "vsplit" or "split")
		end
		target = vim.api.nvim_get_current_win()
		marks.jump(row.char, target)
		if M.sticky then
			vim.api.nvim_set_current_win(deck_win)
			render()
			return
		end
	end
	M.close()
	if target ~= nil and vim.api.nvim_win_is_valid(target) then
		vim.api.nvim_set_current_win(target)
	end
end

local function toggle_sticky()
	M.sticky = not M.sticky
	if M.win_id ~= nil and vim.api.nvim_win_is_valid(M.win_id) then
		vim.api.nvim_win_set_config(M.win_id, { title = M.sticky and " bs [sticky] " or " bs " })
	end
end

---Redraw the deck contents and rebuild its keymaps (marks can change under
--- us), then park the cursor on the row of the file we're currently looking
--- at so `<CR>`/`<C-s>`/`<C-v>`/`<C-t>` act on it straight away.
function render()
	if M.bufnr == nil or not vim.api.nvim_buf_is_valid(M.bufnr) then
		return
	end
	vim.api.nvim_buf_clear_namespace(M.bufnr, -1, 0, -1)

	vim.api.nvim_buf_set_option(M.bufnr, "modifiable", true)
	local rs = rows()
	local lines = {}
	for _, r in ipairs(rs) do
		lines[#lines + 1] = string.format("%s  %s", r.char, r.path)
	end
	vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(M.bufnr, "modifiable", false)

	for _, k in ipairs(vim.api.nvim_buf_get_keymap(M.bufnr, "n")) do
		pcall(vim.api.nvim_buf_del_keymap, M.bufnr, "n", k.lhs)
	end
	-- Anything that isn't a mark, a command, or a deck key is a no-op first;
	-- the mark and command maps below override their entries.
	for _, k in ipairs(BLOCK_KEYS) do
		vim.keymap.set("n", k, function() end, { buffer = M.bufnr, nowait = true })
	end
	for _, r in ipairs(rs) do
		vim.keymap.set("n", r.char, function()
			jump_char(r.char)
		end, { buffer = M.bufnr, nowait = true })
	end
	local keys = require("bs.config").options.deck
	vim.keymap.set("n", keys.select, function()
		jump_highlighted()
	end, { buffer = M.bufnr, nowait = true })
	vim.keymap.set("n", keys.sticky, toggle_sticky, { buffer = M.bufnr, nowait = true })
	vim.keymap.set("n", keys.hsplit, function()
		open_highlighted("h")
	end, { buffer = M.bufnr, nowait = true })
	vim.keymap.set("n", keys.vsplit, function()
		open_highlighted("v")
	end, { buffer = M.bufnr, nowait = true })
	vim.keymap.set("n", keys.tab, function()
		open_highlighted("tab")
	end, { buffer = M.bufnr, nowait = true })
	vim.keymap.set("n", keys.down, function()
		move_cursor(1)
	end, { buffer = M.bufnr, nowait = true })
	vim.keymap.set("n", keys.up, function()
		move_cursor(-1)
	end, { buffer = M.bufnr, nowait = true })
	vim.keymap.set("n", keys.close, M.close, { buffer = M.bufnr, nowait = true })

	local current = current_path()
	for i, r in ipairs(rs) do
		if r.path == current then
			vim.api.nvim_buf_add_highlight(M.bufnr, -1, "Search", i - 1, 0, -1)
			vim.api.nvim_win_set_cursor(M.win_id, { i, 0 })
		end
	end
end

---Open the deck (or close it, if already open).
function M.open()
	if M.win_id ~= nil and vim.api.nvim_win_is_valid(M.win_id) then
		M.close()
		return
	end

	M.from_win = vim.api.nvim_get_current_win()
	M.sticky = false

	local buf = vim.api.nvim_create_buf(false, true)
	M.bufnr = buf
	vim.api.nvim_buf_set_name(buf, "bs-marks")
	vim.bo[buf].bufhidden = "wipe"

	local rs = rows()
	local width = math.max(30, math.floor(vim.o.columns * 0.5))
	local height = math.max(3, #rs + 2)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = height,
		border = "single",
		title = " bs ",
		title_pos = "center",
		style = "minimal",
	})
	M.win_id = win
	vim.wo[win].cursorline = true
	vim.wo[win].cursorlineopt = "line"

	vim.api.nvim_create_autocmd("WinClosed", {
		once = true,
		pattern = tostring(win),
		callback = function()
			if M.win_id == win then
				M.win_id, M.bufnr, M.from_win = nil, nil, nil
			end
		end,
	})

	render()
	return win
end

return M
