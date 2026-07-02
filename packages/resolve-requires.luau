--!strict
--[[
	darklua's `luau` require mode resolves alias requires (`@packages/...`) but
	mis-resolves relative and `@self` requires in this layout, so this rewrites
	every relative/@self require in a vendored tree into the equivalent alias
	require, using the alias map from .luaurc. Idempotent: alias requires are left
	untouched.

	usage: lune run packages/resolve-requires.luau <targetDir> [.luaurc]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

-- Normalise a POSIX path, collapsing "." and ".." segments.
local function normalise(path: string): string
	local parts: { string } = {}
	for segment in path:gmatch("[^/]+") do
		if segment == ".." then
			if #parts > 0 and parts[#parts] ~= ".." then
				parts[#parts] = nil
			else
				table.insert(parts, "..")
			end
		elseif segment ~= "." and segment ~= "" then
			table.insert(parts, segment)
		end
	end
	return table.concat(parts, "/")
end

-- The directory containing a file path.
local function dirname(path: string): string
	local parts: { string } = {}
	for segment in path:gmatch("[^/]+") do
		table.insert(parts, segment)
	end
	parts[#parts] = nil
	return table.concat(parts, "/")
end

-- Read the alias map from .luaurc, with each target normalised ("./packages" -> "packages").
local function loadAliases(luaurcPath: string): { [string]: string }
	local config = serde.decode("json", fs.readFile(luaurcPath))
	local aliases: { [string]: string } = {}
	if typeof(config) == "table" and typeof(config.aliases) == "table" then
		for name, target in config.aliases do
			aliases[name] = normalise(target)
		end
	end
	return aliases
end

-- Resolve a require specifier found in `fileDir` to a repo-relative path, or nil
-- if it is already an alias/absolute require that should be left alone.
local function resolveSpecifier(specifier: string, fileDir: string): string?
	if specifier == "@self" then
		return normalise(fileDir)
	elseif specifier:sub(1, 6) == "@self/" then
		return normalise(`{fileDir}/{specifier:sub(7)}`)
	elseif
		specifier == "."
		or specifier == ".."
		or specifier:sub(1, 2) == "./"
		or specifier:sub(1, 3) == "../"
	then
		return normalise(`{fileDir}/{specifier}`)
	end
	return nil
end

-- Express a repo-relative path as an alias require, choosing the most specific alias.
local function toAlias(resolved: string, aliases: { [string]: string }): string?
	local bestName: string? = nil
	local bestLength = -1
	for name, target in aliases do
		if resolved == target or resolved:sub(1, #target + 1) == `{target}/` then
			if #target > bestLength then
				bestName = name
				bestLength = #target
			end
		end
	end
	if bestName == nil then
		return nil
	end

	local rest = resolved:sub(bestLength + 1):gsub("^/", "")
	return if rest == "" then `@{bestName}` else `@{bestName}/{rest}`
end

local function rewriteFile(filePath: string, aliases: { [string]: string }): number
	local fileDir = dirname(filePath)
	local changes = 0

	local rewritten = fs.readFile(filePath)
		:gsub('require%s*%(%s*"([^"]+)"%s*%)', function(specifier: string): string?
			local resolved = resolveSpecifier(specifier, fileDir)
			if resolved == nil then
				return nil
			end
			local alias = toAlias(resolved, aliases)
			if alias == nil then
				return nil
			end
			changes += 1
			return `require("{alias}")`
		end)

	if changes > 0 then
		fs.writeFile(filePath, rewritten)
	end
	return changes
end

local function walk(root: string, visit: (string) -> ())
	for _, entry in fs.readDir(root) do
		local path = `{root}/{entry}`
		if fs.metadata(path).kind == "dir" then
			walk(path, visit)
		elseif path:match("%.luau?$") then
			visit(path)
		end
	end
end

local target = process.args[1] or "packages/Fusion"
local luaurc = process.args[2] or ".luaurc"

local aliases = loadAliases(luaurc)
local totalFiles = 0
local totalChanges = 0

walk(target, function(filePath: string)
	local changes = rewriteFile(filePath, aliases)
	if changes > 0 then
		totalFiles += 1
		totalChanges += changes
	end
end)

print(
	`resolve-requires: normalised {totalChanges} require(s) across {totalFiles} file(s) under {target}`
)
