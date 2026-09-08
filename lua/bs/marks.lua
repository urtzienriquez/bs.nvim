--- Buffer-marks: the heart of bs.nvim.
---
--- A mark is a single key (`a`..`z`, `A`..`Z`, `0`..`9`) mapped to a buffer.
--- File buffers (and writable, on-disk views like help) are identified by
--- their absolute path, so a mark survives the buffer being wiped and jumping
--- reopens the file from disk. Live buffers — terminals, nofile REPLs — are
--- identified by their buffer and name and must stay alive: nothing on disk
--- can recreate them. Each mark also remembers a cursor position, saved when
--- you mark or leave the buffer and restored when you jump back to it — so
--- flicking between buffers always lands where you left off. Marks are
--- session-local: nothing is written anywhere, but storing
--- { bufnr, path, cursor, buftype } means a future persistence layer only
--- needs to serialise this table.

local M = {}

---@type table<string, { bufnr: number|nil, buftype: string, path: string, cursor: number[]|nil }>
M.marks = {}

---Mark chars in the order they were added (a file being re-marked under the
--- same char keeps its original position).
---@type string[]
M.order = {}

local function notify(msg, level)
	if require("bs.config").options.notify then
		vim.notify("[bs] " .. msg, level or vim.log.levels.INFO)
	end
end

---A valid mark key is a single alphanumeric character.
---@param char string
---@return boolean
local function is_key(char)
	return #char == 1 and char:match("%w") ~= nil
end

---Display identity of `buf`: absolute path for file buffers, raw name for
--- live ones (terminals, nofile REPLs, ...), "" if unnamed.
---@param buf number
---@return string
local function buf_identity(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if vim.bo[buf].buftype == "" and name ~= "" then
		return vim.fn.fnamemodify(name, ":p")
	end
	return name
end

---Same as the internal identity: what a marked buffer would list as.
---@param buf number
---@return string
function M.identity(buf)
	return buf_identity(buf)
end

---Cursor of the first window currently showing `buf`, or nil.
---@param buf number
---@return number[]|nil
local function cursor_for(buf)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			return vim.api.nvim_win_get_cursor(win)
		end
	end
end

---Persist our cursor (by buffer) into every mark that points at `buf`.
---@param buf number
---@param cursor number[]
local function save_position(buf, cursor)
	if cursor == nil then
		return
	end
	local path = buf_identity(buf)
	for _, mark in pairs(M.marks) do
		if mark.bufnr == buf or (path ~= "" and mark.path == path) then
			mark.cursor = cursor
		end
	end
end

---Track where we leave every marked buffer, so a jump back lands there even
--- when the buffer was left some way other than a bs jump. Idempotent.
function M.setup()
	local group = vim.api.nvim_create_augroup("BSMarks", { clear = true })
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function(ev)
			save_position(ev.buf, cursor_for(ev.buf))
		end,
	})
end

---Mark the current buffer under `char`: a file, a terminal, a REPL — anything
--- that has a name (or is a terminal). Returns true on success; refuses to
--- mark the same buffer twice under a different char. Re-marking a different
--- buffer under an already-assigned key asks for confirmation (unless
--- `confirm_reassign` is off).
---@param char string
---@param opts? { confirm?: fun(old_path: string, new_path: string): boolean }
---@return boolean
function M.mark(char, opts)
	if not is_key(char) then
		notify(string.format("invalid mark key %q", char), vim.log.levels.WARN)
		return false
	end
	local buf = vim.api.nvim_get_current_buf()
	local buftype = vim.bo[buf].buftype or ""
	local path = buf_identity(buf)
	if path == "" and buftype ~= "terminal" then
		notify("cannot mark an unnamed buffer", vim.log.levels.WARN)
		return false
	end
	local existing = M.marks[char]
	for c, m in pairs(M.marks) do
		if c ~= char and (m.bufnr == buf or (path ~= "" and m.path == path)) then
			notify(string.format("already marked as %q (%s)", c, path), vim.log.levels.WARN)
			return false
		end
	end
	if existing and existing.bufnr == buf and existing.path == path and existing.buftype == buftype then
		-- Same buffer re-marked under its own key: leave the deck entry alone.
		notify(string.format("already marked as %q (%s)", char, path))
		return true
	end
	if existing then
		-- Re-mark a different buffer under an already-assigned key, keeping the
		-- key's original place in the deck. Ask first: the user may have
		-- forgotten the key was taken.
		local confirmed
		if opts and opts.confirm then
			confirmed = opts.confirm(existing.path, path)
		elseif require("bs.config").options.confirm_reassign then
			local answer = vim.fn.confirm(
				string.format("Mark %q is already assigned to %s.\nReplace it with %s?", char, existing.path, path),
				"&Yes\n&No",
				2,
				"Question"
			)
			confirmed = answer == 1
		else
			confirmed = true
		end
		if not confirmed then
			notify(string.format("kept mark %q on %s", char, existing.path), vim.log.levels.INFO)
			return false
		end
		M.marks[char] = { bufnr = buf, buftype = buftype, path = path, cursor = vim.api.nvim_win_get_cursor(0) }
		notify(string.format("mark %q -> %s (was %s)", char, path, existing.path))
		return true
	end
	M.marks[char] = { bufnr = buf, buftype = buftype, path = path, cursor = vim.api.nvim_win_get_cursor(0) }
	table.insert(M.order, char)
	notify(string.format("marked %q -> %s", char, path))
	return true
end

---Jump to the buffer marked by `char`. File marks reopen from disk if the
--- buffer was wiped (live marks — terminals, REPLs — must still be alive).
--- Lands on the last saved cursor position. `win` lets callers switch the
--- buffer of an arbitrary window (the deck jumps the window behind it instead
--- of itself); 0 means the current window. Returns true if a jump happened.
---@param char string
---@param win? number
---@return boolean
function M.jump(char, win)
	local mark = M.marks[char]
	if not mark then
		notify(string.format("no mark %q", char), vim.log.levels.WARN)
		return false
	end

	local target = win == nil and vim.api.nvim_get_current_win() or win
	if not vim.api.nvim_win_is_valid(target) then
		return true
	end

	local leaving = vim.api.nvim_win_get_buf(target)
	save_position(leaving, cursor_for(leaving))

	local buftype = mark.buftype or ""
	local buf = mark.bufnr

	local same_buffer = buf ~= nil and vim.api.nvim_buf_is_valid(buf)
	if buftype == "" then
		same_buffer = same_buffer
			and vim.bo[buf].buftype == ""
			and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p") == mark.path
	end

	if same_buffer then
		buf = mark.bufnr
	elseif buftype ~= "" then
		-- A live buffer (terminal/REPL) that is gone cannot be recreated.
		notify(string.format("mark %q: buffer is gone (%s)", char, mark.path), vim.log.levels.WARN)
		return false
	else
		if not vim.fn.filereadable(mark.path) then
			notify(string.format("mark %q: file missing: %s", char, mark.path), vim.log.levels.WARN)
			return false
		end
		buf = vim.fn.bufnr(mark.path, -1)
		if buf == -1 then
			buf = vim.fn.bufadd(mark.path)
		end
		if not vim.fn.bufloaded(buf) then
			vim.fn.bufload(buf)
		end
		M.marks[char].bufnr = buf
	end

	local ok = pcall(vim.api.nvim_win_set_buf, target, buf)
	if not ok then
		notify(string.format("mark %q: cannot display this buffer", char), vim.log.levels.WARN)
		return false
	end

	if mark.cursor and buftype ~= "terminal" then
		local line_count = vim.api.nvim_buf_line_count(buf)
		local row = math.max(1, math.min(mark.cursor[1], line_count))
		local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
		local col = math.max(0, math.min(mark.cursor[2], #line))
		vim.api.nvim_win_set_cursor(target, { row, col })
	end
	return true
end

---Remove the mark for `char`. Returns true if one was removed.
---@param char string
---@return boolean
function M.unmark(char)
	if M.marks[char] then
		M.marks[char] = nil
		for i, c in ipairs(M.order) do
			if c == char then
				table.remove(M.order, i)
				break
			end
		end
		notify(string.format("unmarked %q", char))
		return true
	end
	notify(string.format("no mark %q to remove", char), vim.log.levels.INFO)
	return false
end

---Every mark, in the order the buffers were added.
---@return { char: string, path: string, bufnr: number|nil, buftype: string }[]
function M.list()
	local out = {}
	for _, char in ipairs(M.order) do
		local mark = M.marks[char]
		if mark then
			out[#out + 1] = { char = char, path = mark.path, bufnr = mark.bufnr, buftype = mark.buftype }
		end
	end
	return out
end

---Drop every mark.
function M.clear()
	M.marks = {}
	M.order = {}
end

return M
