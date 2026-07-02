--!strict
--!optimize 2

--[[
	KeyCap

	One footer key chip, either a text key like Enter or a glyph key like
	arrowUp. Arrow keys are drawn with icon glyphs rather than font characters,
	so nothing can render as a missing-glyph box.
]]

local Icon = require("@ui/kit/Icon")
local Text = require("@ui/kit/Text")
local fusion = require("@runtime/fusion")
local theme = require("@ui/kit/theme")
local tokens = require("@design/tokens")

type Scope = fusion.Scope

export type Props = {
	-- Exactly one of `key` (text) or `icon` (glyph name).
	key: string?,
	icon: string?,
	visible: fusion.UsedAs<boolean>?,
	layoutOrder: number?,
}

return function(scope: Scope, props: Props): Instance
	assert(props.key ~= nil or props.icon ~= nil, "KeyCap needs a key or an icon")
	local tree = theme.now()

	local children: { fusion.Child } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, tokens.KeyCapCorner) }),
	}

	if props.key ~= nil then
		table.insert(
			children,
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, tokens.KeyCapPadding),
				PaddingRight = UDim.new(0, tokens.KeyCapPadding),
			})
		)
		table.insert(
			children,
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(tokens.KeyCapMinWidth, 0),
			})
		)
		table.insert(
			children,
			Text(scope, {
				Name = "Key",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, tokens.KeyCapHeight),
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = props.key,
				TextColor3 = tree.Text.Secondary.Color,
			})
		)
	elseif props.icon ~= nil then
		table.insert(
			children,
			Icon(scope, {
				icon = props.icon,
				style = "Secondary",
				size = tokens.KeyCapIconSize,
				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
			})
		)
	end

	return scope:New("Frame")({
		Name = "Cap",
		LayoutOrder = props.layoutOrder,
		AutomaticSize = if props.key ~= nil then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		Size = if props.key ~= nil
			then UDim2.fromOffset(0, tokens.KeyCapHeight)
			else UDim2.fromOffset(tokens.KeyCapMinWidth, tokens.KeyCapHeight),
		BackgroundColor3 = tree.Surface.Color,
		BackgroundTransparency = tree.Surface.Alpha,
		Visible = if props.visible == nil then true else props.visible,

		[fusion.Children] = children,
	})
end
