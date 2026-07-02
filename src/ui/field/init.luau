--!strict
--!optimize 2

--[[
	field

	The entry row on the panel's one grid. The glyph rail and the text column
	sit at the same x in every mode, so nothing ever moves. The input is one
	vertically centred line everywhere. Search and pick keep the magnifier,
	since filtering is the action, and a pick's placeholder names the parameter
	because there the placeholder is its one appearance. Scalar entry swaps the
	magnifier for a pencil and prompts generically, the parameter row below
	names the parameter and carries its constraint and validity, so the field
	holds none of that. Nothing here measures anything.
]]

local Store = require("@palette/Store")
local arguments = require("@core/arguments")
local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local motion = require("@design/motion")
local tokens = require("@design/tokens")

local Children = fusion.Children
local OnChange = fusion.OnChange
local OnEvent = fusion.OnEvent

type Scope = fusion.Scope
type Use = fusion.Use

export type Props = {
	text: fusion.Value<string>,
	entry: fusion.UsedAs<Store.EntryState?>,
	searchPlaceholder: string,
	onReady: (textBox: TextBox) -> (),
}

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()

	local isScalar = scope:Computed(function(use: Use): boolean
		local current = use(props.entry)
		return current ~= nil and current.arg.Type ~= "enum" and current.arg.Type ~= "boolean"
	end)

	local placeholder = scope:Computed(function(use: Use): string
		local current = use(props.entry)
		if current then
			-- An authored placeholder is explicit intent and wins over the rules.
			if current.arg.Placeholder then
				return current.arg.Placeholder
			end
			--[[
				A pick's placeholder is the parameter name's one appearance. A
				scalar prompt stays generic, because the parameter row below is
				where the name appears.
			]]
			return if current.arg.Type == "enum" or current.arg.Type == "boolean"
				then `{arguments.displayName(current.arg.Name)}…`
				else "Type a value…"
		end
		return props.searchPlaceholder
	end)

	-- The one grid. The text column is a constant in every mode.
	local textColumn = tokens.IconTileSize + tokens.IconGap

	--[[
		The rail crossfades between the magnifier and the pencil on the fast
		fade, its own spring rather than the mode reveal, so a mode change
		reads as a crisp cut with a short softening.
	]]
	local pencilFade = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(isScalar) then 0 else 1
		end),
		motion.FadeSpeed,
		motion.FadeDamping
	)

	-- The clear affordance appears once there is text, outside scalar entry.
	local isClearHovered = scope:Value(false)
	local clearColor = scope:Computed(function(use: Use): Color3
		return if use(isClearHovered)
			then use(tree.Text.Primary.Color)
			else use(tree.Text.Secondary.Color)
	end)
	local showClear = scope:Computed(function(use: Use): boolean
		return use(props.text) ~= "" and not use(isScalar)
	end)
	local trailingReserve = scope:Computed(function(use: Use): number
		return if use(showClear) then tokens.ClearSize + tokens.IconGap else 0
	end)

	local textBox = kit.Text(scope, {
		Style = "Input",
		As = "TextBox",
		Name = "Input",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, textColumn, 0.5, 0),
		Size = scope:Computed(function(use: Use): UDim2
			return UDim2.new(1, -(textColumn + use(trailingReserve)), 1, 0)
		end),
		ClearTextOnFocus = false,
		Text = "",
		PlaceholderText = placeholder,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = tree.Text.Primary.Color,
		PlaceholderColor3 = tree.Text.Placeholder.Color,

		[OnChange("Text")] = function(text: string)
			props.text:set(text)
		end,
	}) :: TextBox

	props.onReady(textBox)

	return scope:New("Frame")({
		Name = "Field",
		Size = UDim2.new(1, 0, 0, tokens.FieldHeight),
		BackgroundTransparency = 1,

		[Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, tokens.FieldPadding),
				PaddingRight = UDim.new(0, tokens.FieldPadding),
			}),
			scope:New("Frame")({
				Name = "Leading",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(0, tokens.IconTileSize, 1, 0),
				BackgroundTransparency = 1,
				[Children] = {
					--[[
						A bare glyph, because a field's icon must not read as a
						button. The magnifier serves search and pick, where
						filtering is the action, and the pencil serves scalar
						entry, where typing is, each centred on the shared rail.
					]]
					kit.Icon(scope, {
						icon = "magnifyingglass",
						style = "Primary",
						transparency = scope:Computed(function(use: Use): number
							local pencil: number = use(pencilFade)
							return 1 - pencil
						end),
						size = tokens.IconSize,
						anchorPoint = Vector2.new(0.5, 0.5),
						position = UDim2.new(0, tokens.IconTileSize / 2, 0.5, 0),
					}),
					kit.Icon(scope, {
						icon = "pencil",
						style = "Primary",
						transparency = pencilFade,
						size = tokens.IconSize,
						anchorPoint = Vector2.new(0.5, 0.5),
						position = UDim2.new(0, tokens.IconTileSize / 2, 0.5, 0),
					}),
				},
			}),
			textBox,
			-- Cast: mixed special keys (OnEvent + Children) must not unify value types.
			scope:New("ImageButton")({
				Name = "Clear",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(tokens.ClearSize, tokens.ClearSize),
				BackgroundTransparency = 1,
				Image = "",
				Visible = showClear,
				[OnEvent("Activated")] = function()
					props.text:set("")
					textBox.Text = ""
					--[[
						Keep the field live after clearing, so typing continues
						without a second click to refocus.
					]]
					textBox:CaptureFocus()
				end,
				[OnEvent("MouseEnter")] = function()
					isClearHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					isClearHovered:set(false)
				end,
				[Children] = kit.Icon(scope, {
					icon = "xmark",
					color = clearColor,
					size = tokens.ClearSize,
				}),
			} :: fusion.PropertyTable),
		},
	})
end
