--!strict
--!optimize 2

--[[
	EntryHeader

	The argument-mode title bar on the panel's one grid, a back chevron in the
	40px rail slot and the command name on the shared text column, nothing
	else. Collected values and step position both live in the checklist below,
	so the header only names where you are. The whole bar is clickable as back,
	it keeps the flat background, and a hairline underneath separates it from
	the field. Nothing here measures its own size.
]]

local Store = require("@palette/Store")
local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local motion = require("@design/motion")
local tokens = require("@design/tokens")

local Children = fusion.Children
local OnEvent = fusion.OnEvent

type Scope = fusion.Scope
type Use = fusion.Use

export type Props = {
	entry: fusion.UsedAs<Store.EntryState?>,
	-- A 0 to 1 spring off the shared in-arguments state. It grows and fades the bar.
	reveal: fusion.UsedAs<number>,
	onBack: () -> (),
	layoutOrder: number,
}

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()

	--[[
		Hold the last command's name through the fade-out. Entry clears to nil
		the instant argument mode exits, but the header is still fading, so
		reading it live would blank it mid-transition.
	]]
	local heldCommand = scope:Value("")
	scope:Observer(props.entry):onChange(function()
		local current = fusion.peek(props.entry)
		if current ~= nil then
			heldCommand:set(current.command)
		end
	end)

	--[[
		The bar's height cuts with the mode, so the content softens the cut on
		its own fast fade rather than riding the reveal, roughly 80ms of ease
		over an instant structural change.
	]]
	local fade = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(props.entry) ~= nil then 0 else 1
		end),
		motion.FadeSpeed,
		motion.FadeDamping
	)

	-- The shared text column, the same x the rows and the field use.
	local nameStart = tokens.IconTileSize + tokens.IconGap

	--[[
		The whole bar is the back affordance. The back chevron answers hover
		with the same colour lift as the clear affordance, one hover language
		for glyph affordances. Pointer only.
	]]
	local isBackHovered = scope:Value(false)
	local backColor = scope:Computed(function(use: Use): Color3
		return if use(isBackHovered)
			then use(tree.Text.Primary.Color)
			else use(tree.Text.Secondary.Color)
	end)

	-- Cast: mixed special keys (OnEvent + Children) must not unify value types.
	return scope:New("TextButton")({
		Name = "EntryHeader",
		LayoutOrder = props.layoutOrder,
		Size = scope:Computed(function(use: Use): UDim2
			local reveal: number = use(props.reveal)
			return UDim2.new(1, 0, 0, reveal * tokens.EntryHeaderHeight)
		end),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,

		[OnEvent("Activated")] = function()
			props.onBack()
		end,

		[Children] = {
			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, tokens.FieldPadding),
						PaddingRight = UDim.new(0, tokens.FieldPadding),
					}),
					--[[
						The back slot mirrors the field's magnifier slot below,
						so the chevron's centre sits on the same x 40 rail as the
						magnifier and the row tiles.
					]]
					-- Cast: mixed special keys must not unify value types.
					scope:New("Frame")({
						Name = "Back",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(tokens.IconTileSize, tokens.IconTileSize),
						BackgroundTransparency = 1,
						[OnEvent("MouseEnter")] = function()
							isBackHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							isBackHovered:set(false)
						end,
						[Children] = kit.Icon(scope, {
							icon = "chevronLeft",
							color = backColor,
							transparency = fade,
							size = tokens.ClearSize,
							anchorPoint = Vector2.new(0.5, 0.5),
							position = UDim2.fromScale(0.5, 0.5),
						}),
					} :: fusion.PropertyTable),
					kit.Text(scope, {
						Style = "Title",
						Name = "Label",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, nameStart, 0.5, 0),
						Size = UDim2.new(1, -nameStart, 1, 0),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextTransparency = fade,
						Text = heldCommand,
						TextColor3 = tree.Text.Primary.Color,
					}),
				},
			}),
			kit.Hairline(scope, {
				name = "Rule",
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
			}),
		},
	} :: fusion.PropertyTable)
end
