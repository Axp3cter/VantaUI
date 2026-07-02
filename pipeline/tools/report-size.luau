--!strict
--[[
	Reports the size of each built bundle and asserts it is fully self-contained
	(no leftover `require(` calls) and within the size budget. Run after the
	pipeline: `lune run pipeline/tools/report-size.luau`. Exits non-zero if a
	bundle is missing, still contains requires, or exceeds the budget.
]]

local fs = require("@lune/fs")

local BUNDLES = { "dist/vanta.luau", "dist/example.luau" }
local BUDGET_BYTES = 520 * 1024

local function kib(bytes: number): string
	return `{string.format("%.1f", bytes / 1024)} KiB`
end

local failed = false

for _, path in BUNDLES do
	if not fs.isFile(path) then
		print(`MISSING  {path}`)
		failed = true
		continue
	end
	local source = fs.readFile(path)
	local requires = 0
	for _ in string.gmatch(source, "require%s*%(") do
		requires += 1
	end
	local overBudget = #source > BUDGET_BYTES
	local flag = if requires ~= 0 then "REQUIRES" elseif overBudget then "OVERSIZE" else "ok"
	print(`{flag}  {path}  {kib(#source)}  ({requires} require calls, budget {kib(BUDGET_BYTES)})`)
	if requires ~= 0 or overBudget then
		failed = true
	end
end

if failed then
	error("bundle size/self-containment check failed", 0)
end
