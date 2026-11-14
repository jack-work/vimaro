local config = require("nfig.config")
local diff = require("nfig.diff")

local M = {}

local severity_names = { "ERROR", "WARN", "INFO", "HINT" }

local function target_range(buf, opts)
	if opts.line1 and opts.line2 and opts.range and opts.range > 0 then
		return opts.line1, opts.line2, true
	end
	local mode = vim.fn.mode()
	if mode:match("^[vV\22]") then
		local a, b = vim.fn.line("v"), vim.fn.line(".")
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
		return math.min(a, b), math.max(a, b), true
	end
	local cursor = vim.api.nvim_win_get_cursor(0)[1]
	local n = config.options.fix.context
	local last = vim.api.nvim_buf_line_count(buf)
	return math.max(1, cursor - n), math.min(last, cursor + n), false, cursor
end

local function diagnostics_text(buf, first, last)
	local found = vim.tbl_filter(function(d)
		return d.lnum + 1 >= first and d.lnum + 1 <= last
	end, vim.diagnostic.get(buf))
	table.sort(found, function(a, b)
		return a.lnum < b.lnum or (a.lnum == b.lnum and a.col < b.col)
	end)
	local out = {}
	for _, d in ipairs(found) do
		local origin = table.concat(vim.tbl_filter(function(s)
			return s ~= ""
		end, { d.source or "", d.code and tostring(d.code) or "" }), " ")
		table.insert(
			out,
			("line %d col %d %s%s: %s"):format(
				d.lnum + 1,
				d.col + 1,
				severity_names[d.severity] or "?",
				origin ~= "" and (" [" .. origin .. "]") or "",
				(d.message:gsub("\n", " "))
			)
		)
	end
	return out
end

function M.request(ctx)
	local parts = {
		("File: %s"):format(ctx.path),
		("Filetype: %s"):format(ctx.filetype ~= "" and ctx.filetype or "unknown"),
		("Lines %d-%d%s:"):format(ctx.first, ctx.last, ctx.selected and " (selected by the user)" or ""),
		"```" .. ctx.filetype,
		table.concat(ctx.lines, "\n"),
		"```",
	}
	if #ctx.diagnostics > 0 then
		table.insert(parts, "Diagnostics:")
		vim.list_extend(parts, ctx.diagnostics)
	else
		table.insert(parts, "Diagnostics: none")
	end
	if ctx.cursor then
		table.insert(parts, ("Cursor is on line %d."):format(ctx.cursor))
	end
	vim.list_extend(parts, {
		"",
		"Fix the problem in this code: the diagnostics if there are any, otherwise the evident bug.",
		"Reply with ONE unified diff in a ```diff fence and nothing else.",
		("Use the headers `--- a/%s` and `+++ b/%s` and `@@ -N,M +N,M @@` hunk headers with real file line numbers."):format(
			ctx.name,
			ctx.name
		),
		"Copy context and removed lines exactly as they appear, including indentation.",
		"Change only what the fix needs, inside the lines shown.",
		"If nothing needs fixing, reply with an empty ```diff fence.",
	})
	return table.concat(parts, "\n")
end

local function gather(opts)
	local buf = vim.api.nvim_get_current_buf()
	local first, last, selected, cursor = target_range(buf, opts or {})
	local abs = vim.api.nvim_buf_get_name(buf)
	local name = abs ~= "" and vim.fn.fnamemodify(abs, ":.") or "[No Name]"
	local diag_first, diag_last = first, last
	if not selected then
		diag_first, diag_last = cursor, cursor
	end
	return {
		buf = buf,
		path = abs ~= "" and abs or name,
		name = name,
		filetype = vim.bo[buf].filetype,
		first = first,
		last = last,
		selected = selected,
		cursor = cursor,
		lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false),
		diagnostics = diagnostics_text(buf, diag_first, diag_last),
	}
end

local function ask(ctx, prompt, on_reply)
	local fix = config.options.fix
	local ttl_seconds = math.ceil(fix.timeout_ms / 1000) + 30
	local mint = {
		"new",
		"-A",
		"-O",
		fix.outfit,
		"-S",
		vim.json.encode({ mantra = "nfig fix " .. ctx.name }),
		"-S",
		("system.ttl=%ds"):format(ttl_seconds),
		"-j",
	}
	if fix.delete and #fix.delete > 0 then
		vim.list_extend(mint, { "-D", table.concat(fix.delete, ",") })
	end
	config.run(mint, {}, function(minted)
		local ok, res = pcall(vim.json.decode, vim.trim(minted.stdout or ""))
		if minted.code ~= 0 or not ok or type(res) ~= "table" or not res.aria_id then
			return on_reply(nil, "could not start a figaro: " .. config.stderr(minted))
		end
		local id = res.aria_id
		config.run(
			{ "send", "-A", "--id", id, "-r", "--stdin" },
			{ stdin = prompt, timeout = fix.timeout_ms },
			function(out)
				config.run({ "kill", id, "--now" }, {}, function() end)
				if out.code ~= 0 then
					local why = out.signal == 15 and "timed out" or config.stderr(out)
					return on_reply(nil, ("figaro %s failed: %s"):format(res.handle or id, why))
				end
				on_reply(out.stdout or "")
			end
		)
	end)
end

local function close_window(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

function M.confirm(preview, on_answer)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, preview)
	vim.bo[buf].filetype = "diff"
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local widest = 0
	for _, l in ipairs(preview) do
		widest = math.max(widest, vim.fn.strdisplaywidth(l))
	end
	local width = math.min(math.max(widest + 2, 40), math.floor(vim.o.columns * 0.8))
	local height = math.min(#preview, math.floor(vim.o.lines * 0.7))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " figaro fix ",
		title_pos = "center",
		footer = " y apply · n discard ",
		footer_pos = "center",
	})

	local answered = false
	local function answer(yes)
		if answered then
			return
		end
		answered = true
		close_window(win)
		on_answer(yes)
	end
	for _, key in ipairs({ "y", "Y", "<CR>" }) do
		vim.keymap.set("n", key, function()
			answer(true)
		end, { buffer = buf, nowait = true })
	end
	for _, key in ipairs({ "n", "N", "q", "<Esc>" }) do
		vim.keymap.set("n", key, function()
			answer(false)
		end, { buffer = buf, nowait = true })
	end
	vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
		buffer = buf,
		once = true,
		callback = function()
			vim.schedule(function()
				answer(false)
			end)
		end,
	})
end

local function propose(ctx, reply)
	if not vim.api.nvim_buf_is_valid(ctx.buf) then
		return
	end
	local hunks = diff.parse(reply)
	if #hunks == 0 then
		config.notify("no fix proposed", vim.log.levels.WARN)
		return
	end
	local before = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
	local after, why = diff.apply(before, hunks, ctx.first)
	if not after then
		config.err("could not apply the proposed diff: " .. why .. "\n\n" .. reply)
		return
	end
	local preview = diff.unified(before, after, ctx.name)
	if #preview == 0 then
		config.notify("the proposed diff changes nothing", vim.log.levels.WARN)
		return
	end
	local tick = vim.api.nvim_buf_get_changedtick(ctx.buf)
	M.confirm(preview, function(yes)
		if not yes then
			return
		end
		if not vim.api.nvim_buf_is_valid(ctx.buf) then
			return
		end
		if vim.api.nvim_buf_get_changedtick(ctx.buf) ~= tick then
			config.err("buffer changed while the fix was shown; run grf again")
			return
		end
		local span = diff.changed_span(before, after)
		vim.api.nvim_buf_set_lines(ctx.buf, span.first, span.last, false, span.replacement)
		config.notify("fix applied")
	end)
end

function M.fix(opts)
	local ctx = gather(opts)
	if #ctx.lines == 0 then
		config.err("nothing to fix")
		return
	end
	config.notify(("asking %s about %s:%d-%d"):format(config.options.fix.outfit, ctx.name, ctx.first, ctx.last))
	ask(ctx, M.request(ctx), function(reply, failure)
		if failure then
			config.err(failure)
			return
		end
		propose(ctx, reply)
	end)
end

return M
