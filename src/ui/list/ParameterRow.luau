--!strict
--!optimize 2

--[[
	ParameterRow

	The scalar-step body, the current parameter as one standard row in the one
	row system. The tile carries the command's icon, the title the parameter's
	name, the description its constraint in plain language, and the trailing
	slot its validity once there is text, exactly where a pick shows its
	current-value checkmark. The row rests, no pill and no fill, and it is
	deliberately non-interactive, no hover, no press, no activation, because it
	labels the form rather than offering a choice. On commit its content swaps
	in place to the next parameter.
]]

local Store = require("@palette/Store")
local arguments = require("@core/arguments")
local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local tokens = require("@design/tokens")
local typography = require("@design/typography")

local Children = fusion.Children

type Scope = fusion.Scope
type Use = fusion.Use

local MUTED = typography.Muted.Transparency or 0

export type Props = {
	entry: fusion.UsedAs<Store.EntryState?>,
	validity: fusion.UsedAs<Store.Validity>,
	-- The live field text, deciding whether the validity glyph shows at all.
	query: fusion.UsedAs<string>,
	--[[
		The store's springing list height, the same one the list consumes, so
		the two bodies trade places through one continuous height motion.
	]]
	height: fusion.UsedAs<number>,
	visible: fusion.UsedAs<boolean>,
	layoutOrder: number,
}

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()

	local icon = scope:Computed(function(use: Use): string | number
		local current = use(props.entry)
		return if current ~= nil then current.icon else tokens.Defaults.CommandIcon
	end)
	local title = scope:Computed(function(use: Use): string
		local current = use(props.entry)
		return if current ~= nil then arguments.displayName(current.arg.Name) else ""
	end)

	--[[
		One description, one appearance per fact. The plain-language constraint
		leads, the optional affordance follows, and the resolution joins when a
		valid value will fold to something other than what was typed. A standing
		constraint is never replaced. Only an argument with nothing to say for
		itself shows the error message here instead.
	]]
	local description = scope:Computed(function(use: Use): string
		local current = use(props.entry)
		if current == nil then
			return ""
		end
		local parts: { string } = {}
		local hint = arguments.hint(current.arg)
		if hint ~= "" then
			table.insert(parts, hint)
		end
		if current.arg.Optional then
			table.insert(
				parts,
				if current.arg.Default ~= nil
					then `Enter for {current.arg.Default}`
					else "Enter skips"
			)
		end
		local checked = use(props.validity)
		if checked.valid and checked.resolved ~= nil then
			table.insert(parts, `becomes {checked.resolved}`)
		end
		if #parts > 0 then
			return table.concat(parts, " · ")
		end
		return checked.message
	end)
	local descriptionIsError = scope:Computed(function(use: Use): boolean
		local current = use(props.entry)
		if current == nil then
			return false
		end
		local hasConstraint = arguments.hint(current.arg) ~= "" or current.arg.Optional == true
		return not hasConstraint and use(props.validity).message ~= ""
	end)
	local descriptionColor = scope:Computed(function(use: Use): Color3
		return if use(descriptionIsError)
			then use(tree.Invalid.Color)
			else use(tree.Text.Secondary.Color)
	end)
	-- The error state drops the mute so the message reads at full strength.
	local descriptionFade = scope:Computed(function(use: Use): number
		return if use(descriptionIsError) then 0 else MUTED
	end)
	local hasDescription = scope:Computed(function(use: Use): boolean
		return use(description) ~= ""
	end)

	--[[
		Validity in the shared trailing slot, nothing while the field is empty,
		then a checkmark or an xmark as the value stands. This is the one place
		validity appears.
	]]
	local showStatus = scope:Computed(function(use: Use): boolean
		return use(props.query) ~= ""
	end)
	local statusIcon = scope:Computed(function(use: Use): string
		return if use(props.validity).valid then "checkmark" else "xmark"
	end)
	local statusColor = scope:Computed(function(use: Use): Color3
		return if use(props.validity).valid then use(tree.Valid.Color) else use(tree.Invalid.Color)
	end)

	-- The shared text column, the same inset every row uses on both sides.
	local slotInset = tokens.IconTileSize + tokens.IconGap

	return scope:New("Frame")({
		Name = "ParameterArea",
		Size = scope:Computed(function(use: Use): UDim2
			return UDim2.new(1, 0, 0, use(props.height))
		end),
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = props.visible,

		[Children] = {
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, tokens.ListPadding),
				PaddingBottom = UDim.new(0, tokens.ListPadding),
				PaddingLeft = UDim.new(0, tokens.ListInset),
				PaddingRight = UDim.new(0, tokens.ListInset),
			}),
			scope:New("Frame")({
				Name = "Parameter",
				Size = UDim2.new(1, 0, 0, tokens.RowHeight),
				BackgroundTransparency = 1,

				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, tokens.RowPadding),
						PaddingRight = UDim.new(0, tokens.RowPadding),
					}),
					kit.Tile(scope, {
						icon = icon,
						anchorPoint = Vector2.new(0, 0.5),
						position = UDim2.fromScale(0, 0.5),
					}),
					scope:New("Frame")({
						Name = "Text",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, slotInset, 0.5, 0),
						Size = UDim2.new(1, -slotInset * 2, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,

						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, tokens.RowTextGap),
							}),
							kit.Text(scope, {
								Style = "Title",
								Name = "Title",
								LayoutOrder = 1,
								Size = UDim2.new(1, 0, 0, tokens.RowTitleHeight),
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								Text = title,
								TextColor3 = tree.Text.Primary.Color,
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
								Text = description,
								TextColor3 = descriptionColor,
							}),
						},
					}),
					--[[
						The trailing slot mirrors the icon tile, the same 40px
						rail every row gives its drill and current glyphs.
					]]
					scope:New("Frame")({
						Name = "Trailing",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(tokens.IconTileSize, tokens.IconTileSize),
						BackgroundTransparency = 1,
						[Children] = kit.Icon(scope, {
							icon = statusIcon,
							color = statusColor,
							transparency = scope:Computed(function(use: Use): number
								return if use(showStatus) then 0 else 1
							end),
							size = tokens.ClearSize,
							anchorPoint = Vector2.new(0.5, 0.5),
							position = UDim2.fromScale(0.5, 0.5),
						}),
					}),
				},
			}),
		} :: { fusion.Child },
	})
end
