--!strict
--!optimize 2

--[[
	icons

	Resolves an icon reference to a Roblox asset string. A known glyph name maps
	through the generated catalog, a bare number or all-digit string becomes an
	rbxassetid, an explicit content URL passes straight through, and anything
	unknown falls back to the command glyph.
]]

local catalog = require("@design/icons/catalog")
local tokens = require("@design/tokens")

local icons = {}

icons.Icons = catalog
icons.Default = catalog[tokens.Defaults.CommandIcon] or ""

function icons.get(icon: string | number): string
	-- Normalise to a string once, a number and an all-digit name are the same case.
	local text = tostring(icon)
	if string.match(text, "^%d+$") then
		return `rbxassetid://{text}`
	end
	if string.find(text, "://", 1, true) then
		return text
	end
	return catalog[text] or icons.Default
end

return table.freeze(icons)
