--- Keybinding generation.
---
--- Only the prefix and the one-shot mark/unmark chords are mapped; the deck
--- is a real window with its own buffer-local keys. The prefix is
--- deliberately the only map starting with it, so `<leader>'` fires
--- immediately (no timeoutlen / trigger conflicts).
---
---   `<leader>'`        open/close the marks deck
---   `<A-m>{char}`      mark the current file as `{char}`   (one shot)
---   `<A-,>{char}`      unmark `{char}`                     (one shot)

local M = {}

function M.setup()
	local opts = require("bs.config").options
	local prefix = opts.prefix

	vim.keymap.set("n", prefix, function()
		require("bs.deck").open()
	end, { desc = "bs: open marks deck" })

	for key in opts.mark_keys:gmatch(".") do
		vim.keymap.set("n", opts.mark_prefix .. key, function()
			require("bs.marks").mark(key)
		end, { desc = "bs: mark this file as '" .. key .. "'" })
		vim.keymap.set("n", opts.unmark_prefix .. key, function()
			require("bs.marks").unmark(key)
		end, { desc = "bs: unmark '" .. key .. "'" })
	end

	local toggle = opts.terminal.toggle
	if toggle and toggle ~= "" and toggle ~= prefix then
		vim.keymap.set("n", toggle, function()
			require("bs.terminal").toggle(vim.v.count, false)
		end, { desc = "bs: toggle terminal" })
		-- `'<C-s>` shows the terminal in the current window.
		vim.keymap.set("n", "'" .. toggle, function()
			require("bs.terminal").toggle(0, true)
		end, { desc = "bs: terminal in current window" })
	end
end

return M
