--!strict
--!optimize 2

--[[
	Hairline

	The 1px separator line, full width of its parent.
]]

local fusion = require("@runtime/fusion")
local theme = require("@ui/kit/theme")
local tokens = require("@design/tokens")

type Scope = fusion.Scope

export type Props = {
	name: string?,
	visible: fusion.UsedAs<boolean>?,
	layoutOrder: number?,
	anchorPoint: Vector2?,
	position: UDim2?,
}

return function(scope: Scope, props: Props): Instance
	local tree = theme.now()

	return scope:New("Frame")({
		Name = props.name or "Hairline",
		Visible = if props.visible == nil then true else props.visible,
		LayoutOrder = props.layoutOrder,
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.new(1, 0, 0, tokens.SeparatorHeight),
		BorderSizePixel = 0,
		BackgroundColor3 = tree.Separator.Color,
		BackgroundTransparency = tree.Separator.Alpha,
	})
end
