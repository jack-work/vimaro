local M = {}

M.defaults = {
	cmd = "figaro",
	forget = true,
	notify = true,
	compose_ft = "markdown",
}

M.options = vim.deepcopy(M.defaults)

function M.set(opts)
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

function M.notify(msg, level)
	if M.options.notify or (level and level >= vim.log.levels.WARN) then
		vim.notify(msg, level or vim.log.levels.INFO, { title = "figaro" })
	end
end

function M.err(msg)
	vim.notify(msg, vim.log.levels.ERROR, { title = "figaro" })
end

function M.run(args, opts, on_exit)
	local argv = { M.options.cmd }
	vim.list_extend(argv, args)
	local ok, proc = pcall(vim.system, argv, vim.tbl_extend("force", { text = true }, opts or {}), function(out)
		vim.schedule(function()
			on_exit(out)
		end)
	end)
	if not ok then
		vim.schedule(function()
			on_exit({ code = 127, stdout = "", stderr = tostring(proc) })
		end)
	end
	return ok and proc or nil
end

function M.run_sync(args)
	local argv = { M.options.cmd }
	vim.list_extend(argv, args)
	local ok, proc = pcall(vim.system, argv, { text = true })
	if not ok then
		return { code = 127, stdout = "", stderr = tostring(proc) }
	end
	return proc:wait()
end

function M.stderr(out)
	return vim.trim(out.stderr or "")
end

return M
