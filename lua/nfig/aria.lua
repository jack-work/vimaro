local config = require("nfig.config")

local M = {}

M.attended = nil

function M.list()
	local out = config.run_sync({ "list", "-A", "-j" })
	if out.code ~= 0 then
		config.err("figaro list failed: " .. config.stderr(out))
		return {}
	end
	local ok, list = pcall(vim.json.decode, out.stdout)
	if not ok or type(list) ~= "table" then
		config.err("could not parse `figaro list -j`")
		return {}
	end
	local arias = vim.tbl_filter(function(a)
		return a.kind == "conversation"
	end, list)
	table.sort(arias, function(a, b)
		return (a.last_active or 0) > (b.last_active or 0)
	end)
	return arias
end

local function relhome(path)
	local home = vim.env.HOME or ""
	if path and home ~= "" and vim.startswith(path, home) then
		return "~" .. path:sub(#home + 1)
	end
	return path or ""
end

local function label(a)
	local mark = (a.id and a.id == M.attended) and "●" or (a.state == "active" and "▶" or " ")
	local name = a.handle or a.short or a.id or ""
	local mantra = (a.mantra and a.mantra ~= "") and a.mantra or "(no mantra)"
	return ("%s %-24s %-52s %s"):format(mark, name, mantra:sub(1, 52), relhome(a.cwd))
end

function M.attend(id, then_do)
	if id and id ~= "" then
		M.attended = id
		config.notify("attending " .. id)
		if then_do then
			then_do(id)
		end
		return
	end
	local arias = M.list()
	if #arias == 0 then
		config.err("no arias found")
		return
	end
	vim.ui.select(arias, { prompt = "figaro: attend aria", format_item = label }, function(choice)
		if choice then
			M.attend(choice.id, then_do)
		end
	end)
end

function M.detach()
	M.attended = nil
	config.notify("detached")
end

function M.statusline()
	return M.attended and ("figaro:" .. M.attended) or ""
end

local function dispatch(text, id)
	local args
	if id then
		args = { "send", "-A", "--id", id }
		if config.options.forget then
			table.insert(args, "-f")
		end
	else
		args = { "new", "-A" }
	end
	vim.list_extend(args, { "-j", "--stdin" })

	local preview = text:gsub("%s+", " "):sub(1, 48)
	config.run(args, { stdin = text }, function(out)
		if out.code ~= 0 then
			config.err("send failed: " .. config.stderr(out))
			return
		end
		local ok, res = pcall(vim.json.decode, vim.trim(out.stdout or ""))
		if ok and type(res) == "table" and res.aria_id and not M.attended then
			M.attended = res.aria_id
		end
		config.notify(("sent → %s: %s"):format(M.attended or "?", preview))
	end)
end

function M.send(text)
	if not text or vim.trim(text) == "" then
		config.err("nothing to send")
		return
	end
	if M.attended then
		dispatch(text, M.attended)
		return
	end
	local arias = M.list()
	table.insert(arias, 1, { mantra = "＋ new aria", cwd = vim.fn.getcwd() })
	vim.ui.select(arias, { prompt = "figaro: send to which aria?", format_item = label }, function(choice)
		if not choice then
			return
		end
		if choice.id then
			M.attended = choice.id
		end
		dispatch(text, choice.id)
	end)
end

function M.selection()
	local mode = vim.fn.mode()
	local lines
	if mode:match("^[vV\22]") then
		lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	else
		lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = "V" })
	end
	return table.concat(lines or {}, "\n")
end

local compose_count = 0

function M.compose(seed)
	compose_count = compose_count + 1
	local buf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(buf, ("figaro://%s/%d"):format(M.attended or "new", compose_count))
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = config.options.compose_ft
	if seed and seed ~= "" then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(seed, "\n"))
	end

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
			if vim.trim(text) == "" then
				config.err("empty prompt, not sent")
				return
			end
			vim.bo[buf].modified = false
			M.send(text)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_delete(buf, { force = true })
				end
			end)
		end,
	})

	vim.cmd.split()
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_win_set_height(0, math.max(10, math.floor(vim.o.lines * 0.3)))
	vim.cmd.startinsert()
	config.notify("compose: :w to send" .. (M.attended and (" → " .. M.attended) or ""))
end

function M.prompt(visual)
	local text = visual and M.selection() or ""
	if vim.trim(text) ~= "" then
		M.send(text)
	else
		M.compose()
	end
end

function M.listen()
	if not M.attended then
		return M.attend(nil, function()
			M.listen()
		end)
	end
	vim.cmd.split()
	vim.cmd.terminal(("%s listen %s"):format(vim.fn.shellescape(config.options.cmd), vim.fn.shellescape(M.attended)))
	vim.cmd.startinsert()
end

function M.status()
	if not M.attended then
		config.notify("not attending any aria", vim.log.levels.WARN)
		return
	end
	config.run({ "status", M.attended }, {}, function(out)
		local text = vim.trim(out.code == 0 and out.stdout or config.stderr(out))
		vim.notify(text, out.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR, { title = "figaro" })
	end)
end

return M
