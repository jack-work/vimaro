local M = {}

local function fenced_body(text)
	local body = text:match("```%s*diff%s*\n(.-)\n```")
		or text:match("```%s*patch%s*\n(.-)\n```")
		or text:match("```[%w_-]*\n(.-)\n```")
	return body or text
end

function M.parse(text)
	local lines = vim.split(fenced_body(text or ""), "\n", { plain = true })
	local hunks, hunk = {}, nil
	local seen_header = false

	local function close()
		if hunk and (#hunk.old > 0 or #hunk.new > 0) then
			table.insert(hunks, hunk)
		end
		hunk = nil
	end

	local function open(old_start)
		close()
		hunk = { old_start = old_start, old = {}, new = {} }
	end

	for i, line in ipairs(lines) do
		local next_line = lines[i + 1] or ""
		if line:match("^%-%-%- ") and next_line:match("^%+%+%+ ") then
			close()
			seen_header = true
		elseif line:match("^%+%+%+ ") and not hunk then
			seen_header = true
		elseif line:match("^@@") then
			open(tonumber(line:match("^@@ %-(%d+)")))
		elseif line:match("^\\") then
		elseif hunk or seen_header then
			local tag, rest = line:sub(1, 1), line:sub(2)
			if line == "" then
				tag, rest = " ", ""
			end
			if tag == " " or tag == "-" or tag == "+" then
				if not hunk then
					open(nil)
				end
				if tag ~= "+" then
					table.insert(hunk.old, rest)
				end
				if tag ~= "-" then
					table.insert(hunk.new, rest)
				end
			else
				close()
			end
		end
	end
	close()

	for _, h in ipairs(hunks) do
		while #h.old > 0 and #h.new > 0 and h.old[#h.old] == "" and h.new[#h.new] == "" do
			table.remove(h.old)
			table.remove(h.new)
		end
	end
	return vim.tbl_filter(function(h)
		return not vim.deep_equal(h.old, h.new)
	end, hunks)
end

local normalizers = {
	function(s)
		return s
	end,
	function(s)
		return (s:gsub("%s+$", ""))
	end,
	function(s)
		return vim.trim(s)
	end,
}

local function matches_at(lines, block, at, norm)
	for j = 1, #block do
		local have = lines[at + j - 1]
		if have == nil or norm(have) ~= norm(block[j]) then
			return false
		end
	end
	return true
end

local function locate(lines, hunk, hint)
	if #hunk.old == 0 then
		local at = (hunk.old_start or hint or #lines) + 1
		return math.max(1, math.min(at, #lines + 1))
	end
	for _, norm in ipairs(normalizers) do
		local best, best_dist
		for at = 1, #lines - #hunk.old + 1 do
			if matches_at(lines, hunk.old, at, norm) then
				local dist = math.abs(at - (hunk.old_start or hint or at))
				if not best or dist < best_dist then
					best, best_dist = at, dist
				end
			end
		end
		if best then
			return best
		end
	end
end

function M.apply(lines, hunks, hint)
	local placed = {}
	for i, hunk in ipairs(hunks) do
		local at = locate(lines, hunk, hint)
		if not at then
			return nil, ("hunk %d does not match the buffer:\n%s"):format(i, table.concat(hunk.old, "\n"))
		end
		table.insert(placed, { at = at, hunk = hunk })
	end
	table.sort(placed, function(a, b)
		return a.at < b.at
	end)
	for i = 2, #placed do
		local prev = placed[i - 1]
		if prev.at + #prev.hunk.old > placed[i].at then
			return nil, "hunks overlap"
		end
	end

	local out = vim.list_slice(lines, 1, #lines)
	for i = #placed, 1, -1 do
		local p = placed[i]
		for _ = 1, #p.hunk.old do
			table.remove(out, p.at)
		end
		for k = #p.hunk.new, 1, -1 do
			table.insert(out, p.at, p.hunk.new[k])
		end
	end
	return out
end

function M.changed_span(before, after)
	local prefix = 0
	while prefix < #before and prefix < #after and before[prefix + 1] == after[prefix + 1] do
		prefix = prefix + 1
	end
	local suffix = 0
	while
		suffix < #before - prefix
		and suffix < #after - prefix
		and before[#before - suffix] == after[#after - suffix]
	do
		suffix = suffix + 1
	end
	return {
		first = prefix,
		last = #before - suffix,
		replacement = vim.list_slice(after, prefix + 1, #after - suffix),
	}
end

function M.unified(before, after, name)
	local body = vim.diff(table.concat(before, "\n") .. "\n", table.concat(after, "\n") .. "\n", {
		result_type = "unified",
		ctxlen = 3,
	})
	if not body or body == "" then
		return {}
	end
	local out = { "--- a/" .. name, "+++ b/" .. name }
	vim.list_extend(out, vim.split(body:gsub("\n$", ""), "\n", { plain = true }))
	return out
end

return M
