--!strict
--!optimize 2

--[[
	Row

	One list row, reused rather than rebuilt. It renders a RowModel, the common
	projection of a matched command or an enum option, so filtering only
	re-orders and re-styles a surviving row. The row owns no fill of its own.
	Selection is the single pill the list slides between rows, and rank and
	selected state derive from the shared evaluation.
]]

local Store = require("@palette/Store")
local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local motion = require("@design/motion")
local tokens = require("@design/tokens")
local typography = require("@design/typography")

local Children = fusion.Children
local OnEvent = fusion.OnEvent

type Scope = fusion.Scope
type Use = fusion.Use

local MUTED = typography.Muted.Transparency or 0

export type Props = {
	model: Store.RowModel,
	evaluation: fusion.UsedAs<Store.Evaluation>,
	selectedIndex: fusion.Value<number>,
	-- Pointer hover selects through here, so the list can snap its pill.
	onHover: (rank: number) -> (),
}

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()
	local model = props.model

	local rank = scope:Computed(function(use: Use): number
		return use(props.evaluation).order[model] or 0
	end)
	local isSelected = scope:Computed(function(use: Use): boolean
		return use(rank) == use(props.selectedIndex)
	end)
	local hasDescription = scope:Computed(function(use: Use): boolean
		return use(model.description) ~= ""
	end)
	--[[
		The trailing slot, either a drill chevron for argument entry or a
		checkmark on the option matching the argument's current value. Static
		per row.
	]]
	local trailingGlyph: string? = if model.drillIn
		then "chevronRight"
		elseif model.checked then "checkmark"
		else nil

	--[[
		Pointer state for the micro-interactions. Hover lifts the tile's Surface
		one step, and press dips the tile's scale and springs straight back.
		Both are pointer only, keyboard selection never triggers them.
	]]
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	--[[
		The icon tile is faint while the row is idle, lifts one step under the
		pointer, and fades out under the selection tint when picked, so the
		selected row reads as one clean accent fill.
	]]
	local surfaceAlpha = scope:Spring(
		scope:Computed(function(use: Use): number
			if use(isSelected) then
				return 1
			end
			local rest: number = use(tree.Surface.Alpha)
			return if use(isHovered) then math.max(0, rest - tokens.SurfaceHoverLift) else rest
		end),
		motion.SelectionSpeed
	)
	local tileScale = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(isPressed) then motion.PressScale else 1
		end),
		motion.PressSpeed,
		motion.PressDamping
	)
	--[[
		The swatch ring firms up on the selected row, riding the selection
		spring, and flips from the theme border to the selection text colour so
		it keeps contrast on the pill in both palettes.
	]]
	local swatchRing = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(isSelected) then tokens.SwatchRingActive else tokens.SwatchRingRest
		end),
		motion.SelectionSpeed
	)
	local swatchRingColor = scope:Computed(function(use: Use): Color3
		return if use(isSelected) then use(tree.SelectionText.Color) else use(tree.Border.Color)
	end)

	-- All foreground colours flip to the selection colour on the filled row.
	local primaryColor = scope:Computed(function(use: Use): Color3
		return if use(isSelected)
			then use(tree.SelectionText.Color)
			else use(tree.Text.Primary.Color)
	end)
	local secondaryColor = scope:Computed(function(use: Use): Color3
		return if use(isSelected)
			then use(tree.SelectionText.Color)
			else use(tree.Text.Secondary.Color)
	end)
	local iconColor = scope:Computed(function(use: Use): Color3
		return if use(isSelected) then use(tree.IconSelected.Color) else use(tree.Icon.Color)
	end)
	-- A fallback bullet reads as a deliberate dot, quiet until selected.
	local bulletColor = scope:Computed(function(use: Use): Color3
		return if use(isSelected)
			then use(tree.SelectionText.Color)
			else use(tree.Text.Tertiary.Color)
	end)
	--[[
		Trailing glyphs are wayfinding, not content, so they rest a step behind
		the titles and only brighten on the selected row.
	]]
	local trailingColor = scope:Computed(function(use: Use): Color3
		return if use(isSelected)
			then use(tree.SelectionText.Color)
			else use(tree.Text.Tertiary.Color)
	end)
	--[[
		The description keeps its de-emphasis only while unselected. On the
		highlight the mute would wash it out, so it goes to full strength.
	]]
	local descriptionFade = scope:Computed(function(use: Use): number
		return if use(isSelected) then 0 else MUTED
	end)

	--[[
		The title renders the matched characters of the ranking alignment,
		escaped segment by segment, with consecutive positions collapsed into
		one tag. On the accent pill the accent colour would vanish, so bold
		carries the highlight there instead.
	]]
	local title = scope:Computed(function(use: Use): string
		local raw: string = use(model.title)
		local positionList: { number }? = use(props.evaluation).positions[model]
		if positionList == nil or #positionList == 0 then
			return kit.rich.escape(raw)
		end
		local selectedNow = use(isSelected)
		local accentHex = use(tree.Selection.Color):ToHex()
		local pieces: { string } = {}
		local cursor = 1
		local i = 1
		while i <= #positionList do
			local startPos: number = positionList[i]
			local endPos: number = startPos
			while i + 1 <= #positionList and positionList[i + 1] == endPos + 1 do
				i += 1
				endPos = positionList[i]
			end
			if startPos > cursor then
				table.insert(pieces, kit.rich.escape(raw:sub(cursor, startPos - 1)))
			end
			local run = kit.rich.escape(raw:sub(startPos, endPos))
			if selectedNow then
				table.insert(pieces, `<b>{run}</b>`)
			else
				table.insert(pieces, `<font color="#{accentHex}">{run}</font>`)
			end
			cursor = endPos + 1
			i += 1
		end
		if cursor <= #raw then
			table.insert(pieces, kit.rich.escape(raw:sub(cursor)))
		end
		return table.concat(pieces)
	end)

	--[[
		The text column is inset by the icon slot on the left and by a matching
		slot on the right, reserved on every row whether or not it renders a
		trailing glyph, so the text width stays consistent top to bottom.
	]]
	local slotInset = tokens.IconTileSize + tokens.IconGap
	local textReserve = slotInset * 2

	local text = scope:New("Frame")({
		Name = "Text",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, slotInset, 0.5, 0),
		Size = UDim2.new(1, -textReserve, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, tokens.RowTextGap),
			}),

			-- Top line: just the title, centred in its fixed slot.
			scope:New("Frame")({
				Name = "TopLine",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, tokens.RowTitleHeight),
				BackgroundTransparency = 1,
				[Children] = kit.Text(scope, {
					Style = "Title",
					Name = "Title",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromScale(1, 1),
					RichText = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = title,
					TextColor3 = primaryColor,
				}),
			}),

			kit.Text(scope, {
				Name = "Description",
				LayoutOrder = 2,
				Size = scope:Computed(function(use: Use): UDim2
					return if use(hasDescription)
						then UDim2.new(1, 0, 0, tokens.RowDescriptionHeight)
						else UDim2.new(1, 0, 0, 0)
				end),
				Visible = hasDescription,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextTransparency = descriptionFade,
				Text = model.description,
				TextColor3 = secondaryColor,
			}),
		},
	})

	local contentChildren: { fusion.Child } = {
		scope:New("UIPadding")({
			PaddingLeft = UDim.new(0, tokens.RowPadding),
			PaddingRight = UDim.new(0, tokens.RowPadding),
		}),
		kit.Tile(scope, {
			swatch = model.swatch,
			icon = model.icon,
			iconColor = if model.bullet then bulletColor else iconColor,
			iconSize = if model.bullet then tokens.ClearSize else nil,
			surfaceTransparency = surfaceAlpha,
			swatchRingColor = swatchRingColor,
			swatchRingTransparency = swatchRing,
			scale = tileScale,
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.fromScale(0, 0.5),
		}),
		text,
	}
	--[[
		The trailing glyph gets a 40px slot mirroring the icon tile. Its centre
		sits the same inset from the right wall as the icon's from the left,
		balanced rather than pinned, and it is centred on the row, not the
		higher title line.
	]]
	if trailingGlyph ~= nil then
		table.insert(
			contentChildren,
			scope:New("Frame")({
				Name = "Trailing",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(tokens.IconTileSize, tokens.IconTileSize),
				BackgroundTransparency = 1,
				[Children] = kit.Icon(scope, {
					icon = trailingGlyph,
					color = trailingColor,
					size = tokens.ClearSize,
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.5),
				}),
			})
		)
	end

	-- Cast: mixed special keys (OnEvent + Children) must not unify value types.
	return scope:New("TextButton")({
		Name = "Row",
		Size = UDim2.new(1, 0, 0, tokens.RowHeight),
		LayoutOrder = rank,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",

		[OnEvent("Activated")] = function()
			model.activate()
		end,
		--[[
			MouseMoved, not MouseEnter. Rows sliding under a stationary cursor
			during keyboard navigation or scrolling must not hijack the
			selection, so only genuine pointer movement selects by hover.
			MouseEnter and MouseLeave only style the tile.
		]]
		[OnEvent("MouseMoved")] = function()
			props.onHover(fusion.peek(rank))
		end,
		[OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,
		[OnEvent("MouseButton1Down")] = function()
			isPressed:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,

		[Children] = {
			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Children] = contentChildren,
			}),
		},
	} :: fusion.PropertyTable)
end
