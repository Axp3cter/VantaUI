--!strict
--!optimize 2

--[[
	Icon

	The reusable icon view, an ImageLabel bound to the theme. Every icon in the
	UI goes through here, so scaling and theming stay uniform. Primary uses the
	Icon token and Secondary the muted text token, unless an explicit colour is
	supplied.
]]

local fusion = require("@runtime/fusion")
local icons = require("@design/icons")
local theme = require("@ui/kit/theme")
local tokens = require("@design/tokens")

type Scope = fusion.Scope

export type Style = "Primary" | "Secondary"

export type Props = {
	icon: fusion.UsedAs<string | number>,
	style: fusion.UsedAs<Style>?,
	-- A row passes its springing selection colour here. It overrides style.
	color: fusion.UsedAs<Color3>?,
	transparency: fusion.UsedAs<number>?,
	size: number?,
	layoutOrder: number?,
	anchorPoint: Vector2?,
	position: UDim2?,
}

return function(scope: Scope, props: Props): Instance
	local tree = theme.now()

	local color: fusion.UsedAs<Color3> = props.color
		or scope:Computed(function(use: fusion.Use): Color3
			local style = if props.style then use(props.style) else "Primary"
			return if style == "Secondary"
				then use(tree.Text.Secondary.Color)
				else use(tree.Icon.Color)
		end)

	return scope:New("ImageLabel")({
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(props.size or tokens.IconSize, props.size or tokens.IconSize),
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		Image = scope:Computed(function(use): string
			return icons.get(use(props.icon))
		end),
		ImageColor3 = color,
		ImageTransparency = props.transparency,
	})
end
