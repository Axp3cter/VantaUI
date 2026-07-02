--!strict
--!optimize 2

--[[
	EmptyState

	The "nothing here" overlay for the list area. It is a sibling overlay rather
	than a list child, so it never depends on how UIListLayout treats hidden
	elements. The muted icon makes an empty search read as intentional rather
	than broken.
]]

local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local tokens = require("@design/tokens")

local Children = fusion.Children

type Scope = fusion.Scope

export type Props = {
	text: fusion.UsedAs<string>,
	visible: fusion.UsedAs<boolean>,
}

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()

	return scope:New("Frame")({
		Name = "Empty",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.visible,

		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, tokens.Spacing.SM),
			}),
			kit.Icon(scope, {
				icon = "magnifyingglass",
				color = tree.Text.Tertiary.Color,
				size = tokens.IconSize,
				layoutOrder = 1,
			}),
			kit.Text(scope, {
				Name = "Text",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = props.text,
				TextColor3 = tree.Text.Tertiary.Color,
			}),
		},
	})
end
