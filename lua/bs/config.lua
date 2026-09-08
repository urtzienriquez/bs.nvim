local M = {}

---@class BSConfig
M.defaults = {
	-- `<leader>'` opens the marks deck: a small floating window listing every
	-- mark. Pressing a mark jumps to its file (deck stays open to flick
	-- between buffers), `<Esc>` closes it.
	prefix = "<leader>'",

	-- One-shot mark/unmark: `<A-m>{char}` marks the current file as `{char}`,
	-- `<A-,>{char}` unmarks it. One keystroke after the key, back to normal
	-- mode. Re-marking a *different* buffer under an already-assigned key
	-- asks for confirmation first (Enter/`n` keeps the old mark).
	mark_prefix = "<A-m>",
	unmark_prefix = "<A-,>",
	-- Ask before re-assigning an already-used key (in case you forgot it was
	-- taken). Set to false for the old silent overwrite.
	confirm_reassign = true,

	-- Characters you may use as mark names.
	mark_keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",

	-- Deck keys. The deck is transient: a mark (or `<CR>`) and the split/tab
	-- keys act on the highlighted row and close it. `sticky` (`'`) toggles a
	-- persistent mode where those keys keep the deck open for flicking (the
	-- title shows `[sticky]`); `<Esc>` always closes. `<C-p>`/`<C-n>` move
	-- the highlight and never close it (`j`/`k` are reserved for marks).
	deck = {
		select = "<CR>",
		sticky = "'",
		hsplit = "<C-s>",
		vsplit = "<C-v>",
		tab = "<C-t>",
		up = "<C-p>",
		down = "<C-n>",
		close = "<Esc>",
	},

	-- Show a short notification when marking/unmarking.
	notify = true,

	-- Terminal settings (ported from the `ctrl_s_shell` approach).
	terminal = {
		-- Toggle key for the terminal. Set to "" to disable.
		--   `<C-s>`         toggle (open/focus/return)
		--   `'<C-s>`        terminal in the current window
		--   `[count]<C-s>`  open as a split `count` lines tall
		toggle = "<C-s>",
		-- Where a *new* terminal goes for plain `<C-s>`: its own tabpage by
		-- default; set to true to split the current window instead.
		here = false,
		-- Maximum scrollback (-1 = unlimited).
		scrollback = -1,
	},
}

M.options = vim.deepcopy(M.defaults)

---@param user_opts? table
function M.setup(user_opts)
	M.options = vim.tbl_deep_extend("force", M.options, user_opts or {})
end

return M
