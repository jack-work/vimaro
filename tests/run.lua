local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local diff = require("vimaro.diff")
local failures, passed = 0, 0

local function test(name, fn)
	local ok, e = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failures = failures + 1
		io.stderr:write(("FAIL %s\n  %s\n"):format(name, e))
	end
end

local function eq(want, got)
	if not vim.deep_equal(want, got) then
		error(("want %s\n  got  %s"):format(vim.inspect(want), vim.inspect(got)), 2)
	end
end

local buffer = {
	"local function add(a, b)",
	"\treturn a + c",
	"end",
	"",
	"print(add(1, 2))",
}

test("applies a fenced diff with prose around it", function()
	local reply = table.concat({
		"Here is the fix:",
		"```diff",
		"--- a/x.lua",
		"+++ b/x.lua",
		"@@ -1,3 +1,3 @@",
		" local function add(a, b)",
		"-\treturn a + c",
		"+\treturn a + b",
		" end",
		"```",
		"Done.",
	}, "\n")
	local out = assert(diff.apply(buffer, diff.parse(reply), 1))
	eq("\treturn a + b", out[2])
	eq(#buffer, #out)
end)

test("ignores wrong hunk line numbers from the model", function()
	local reply = "```diff\n--- a/x\n+++ b/x\n@@ -40,2 +40,2 @@\n-\treturn a + c\n+\treturn a + b\n end\n```"
	local out = assert(diff.apply(buffer, diff.parse(reply), 1))
	eq("\treturn a + b", out[2])
end)

test("treats a bare empty line in a hunk as blank context", function()
	local reply = "```diff\n--- a/x\n+++ b/x\n@@ -3,3 +3,3 @@\n end\n\n-print(add(1, 2))\n+print(add(1, 3))\n```"
	local out = assert(diff.apply(buffer, diff.parse(reply), 1))
	eq("print(add(1, 3))", out[5])
end)

test("a removed lua comment is not mistaken for a file header", function()
	local lines = { "-- old", "x = 1" }
	local reply = "```diff\n--- a/x\n+++ b/x\n@@ -1,2 +1,2 @@\n--- old\n+-- new\n x = 1\n```"
	local out = assert(diff.apply(lines, diff.parse(reply), 1))
	eq({ "-- new", "x = 1" }, out)
end)

test("matches despite trailing whitespace drift", function()
	local lines = { "a = 1   ", "b = 2" }
	local reply = "```diff\n--- a/x\n+++ b/x\n@@ -1,2 +1,2 @@\n a = 1\n-b = 2\n+b = 3\n```"
	local out = assert(diff.apply(lines, diff.parse(reply), 1))
	eq({ "a = 1", "b = 3" }, out)
end)

test("picks the occurrence nearest the hint when context repeats", function()
	local lines = { "x()", "y", "x()", "y" }
	local reply = "```diff\n--- a/f\n+++ b/f\n@@ @@\n-x()\n+z()\n```"
	local out = assert(diff.apply(lines, diff.parse(reply), 3))
	eq({ "x()", "y", "z()", "y" }, out)
end)

test("applies several hunks", function()
	local reply = "```diff\n--- a/x\n+++ b/x\n@@ -2 +2 @@\n-\treturn a + c\n+\treturn a + b\n@@ -5 +5 @@\n-print(add(1, 2))\n+print(add(2, 2))\n```"
	local out = assert(diff.apply(buffer, diff.parse(reply), 1))
	eq("\treturn a + b", out[2])
	eq("print(add(2, 2))", out[5])
end)

test("refuses a hunk that does not match", function()
	local reply = "```diff\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-nothing like this\n+x\n```"
	local out, why = diff.apply(buffer, diff.parse(reply), 1)
	eq(nil, out)
	assert(why:match("does not match"))
end)

test("an empty fence proposes nothing", function()
	eq({}, diff.parse("```diff\n```"))
	eq({}, diff.parse("No change needed."))
end)

test("changed_span narrows the edit to the lines that differ", function()
	local span = diff.changed_span({ "a", "b", "c", "d" }, { "a", "B", "B2", "d" })
	eq({ first = 1, last = 3, replacement = { "B", "B2" } }, span)
end)

test("unified preview carries headers", function()
	local u = diff.unified({ "a", "b" }, { "a", "c" }, "f.lua")
	eq("--- a/f.lua", u[1])
	eq("+++ b/f.lua", u[2])
	assert(vim.tbl_contains(u, "+c") and vim.tbl_contains(u, "-b"))
end)

print(("%d passed, %d failed"):format(passed, failures))
os.exit(failures == 0 and 0 or 1)
