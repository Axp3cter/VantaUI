--!strict
--!optimize 2

--[[
	rich

	RichText helpers shared by every label that renders markup. Any user
	supplied text (argument names, typed values, command names) is escaped
	before it meets a RichText label, so it can never break the formatting.
]]

local rich = {}

function rich.escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

return table.freeze(rich)
