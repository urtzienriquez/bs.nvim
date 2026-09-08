--- bs.nvim – plugin entrypoint.
---
--- Mirrors replent.nvim's structure: this file just guards against double
--- loading and wires up the (single, light) global keybinding. All logic is
--- otherwise kicked in lazily from inside the callback.

if vim.g.loaded_bs then
	return
end
vim.g.loaded_bs = true

require("bs.config").setup()
require("bs.keymaps").setup()
