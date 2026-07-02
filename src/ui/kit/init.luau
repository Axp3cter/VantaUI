--!strict
--!optimize 2

--[[
	kit

	The shared atoms every region builds from, shaped as a scope mixin. View
	scopes are built as fusion.scoped(fusion.constructors, kit) so components
	read as scope:Text with a props table. View construction is wrapped in
	kit.theme:is(tree):during(build) and components read the theme from that
	context, never from props.
]]

local Hairline = require("@ui/kit/Hairline")
local Icon = require("@ui/kit/Icon")
local KeyCap = require("@ui/kit/KeyCap")
local Text = require("@ui/kit/Text")
local Tile = require("@ui/kit/Tile")
local rich = require("@ui/kit/rich")
local theme = require("@ui/kit/theme")

return table.freeze({
	--[[
		The theme context. Regions needing the tree for their own chrome call
		kit.useTheme(), and the palette binds it with kit.theme is() during().
	]]
	theme = theme.context,
	useTheme = theme.now,
	rich = rich,

	Text = Text,
	Icon = Icon,
	Tile = Tile,
	KeyCap = KeyCap,
	Hairline = Hairline,
})
