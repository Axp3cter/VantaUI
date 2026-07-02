--!strict
--!optimize 2

--[[
	theme

	The kit's theme context, one Contextual carrying the active ThemeTree.
	Components read the tree from here instead of a props field, so no props
	table threads the theme by hand. It is a sibling of init rather than init
	itself, because init requires every component and the components need this
	Contextual, so it cannot live in init.
]]

local Theme = require("@design/theme")
local fusion = require("@runtime/fusion")

local context: fusion.Contextual<Theme.ThemeTree?> = fusion.Contextual(nil :: Theme.ThemeTree?)

local theme = {
	context = context,
}

-- The active tree. Calling this outside a context is(tree):during() wrap is a bug.
function theme.now(): Theme.ThemeTree
	local tree = context:now()
	return assert(tree, "kit theme used outside a theme context")
end

return table.freeze(theme)
