--- bs.nvim – buffer-marks with a harpoon-style floating deck: `<leader>'` opens
--- a small window listing your marks; a mark jumps to it and the deck closes
--- (a quick hop is two keystrokes), or press `'` for sticky mode and it stays
--- open so you can flick between buffers. `<leader>+`/`<leader>-` mark/unmark
--- the current buffer, and a terminal is bundled for running work next to
--- them.

local M = {}

---Apply configuration and bind keys.
---@param user_opts? table See `bs.config`.
function M.setup(user_opts)
	require("bs.config").setup(user_opts)
	require("bs.keymaps").setup()
	require("bs.marks").setup()
end

---Open the marks deck (same as pressing `<leader>'`).
function M.deck()
	require("bs.deck").open()
end

---Mark the current file as `char`.
---@param char string
function M.mark(char)
	require("bs.marks").mark(char)
end

---Jump to the file marked `char`.
---@param char string
function M.jump(char)
	require("bs.marks").jump(char)
end

---Remove the mark for `char`.
---@param char string
function M.unmark(char)
	require("bs.marks").unmark(char)
end

---Toggle the terminal.
---@param count? integer `[count]<C-s>`: open as a split this tall
---@param here? boolean `'<C-s>`: show the terminal in the current window
function M.terminal(count, here)
	require("bs.terminal").toggle(count, here)
end

return M
