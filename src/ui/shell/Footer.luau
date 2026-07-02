--!strict
--!optimize 2

--[[
	Footer

	The action bar along the panel's bottom edge. Key hints with mode-aware
	labels sit on the left, and the "N of M" readout and scroll cues sit on the
	right, over a top hairline. This is where the controls prose lives, a real
	UI element rather than README text.
]]

local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local tokens = require("@design/tokens")

local Children = fusion.Children

type Scope = fusion.Scope
type Use = fusion.Use

export type Props = {
	runLabel: fusion.UsedAs<string>,
	navLabel: fusion.UsedAs<string>,
	closeLabel: fusion.UsedAs<string>,
	-- The position readout ("N of M") at the bottom-right.
	count: fusion.UsedAs<string>,
	-- Whether more rows exist above / below the fold, for the scroll cues.
	canScrollUp: fusion.UsedAs<boolean>,
	canScrollDown: fusion.UsedAs<boolean>,
	-- A transient run acknowledgment. When non-empty it replaces the hints.
	flash: fusion.UsedAs<string>,
	-- Whether the acknowledged run succeeded or its callback threw.
	flashValid: fusion.UsedAs<boolean>,
	--[[
		Whether a navigable list is visible above. The navigation hints hide
		with it, since there is nothing to navigate. The divider is not gated
		on it, because every mode has a body above the footer, the list, the
		empty state, or the parameter row.
	]]
	listVisible: fusion.UsedAs<boolean>,
	layoutOrder: number,
}

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()

	local function label(
		order: number,
		text: fusion.UsedAs<string>,
		visible: fusion.UsedAs<boolean>?
	): Instance
		return kit.Text(scope, {
			Name = "Label",
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, tokens.KeyCapHeight),
			Visible = if visible == nil then true else visible,
			Text = text,
			TextColor3 = tree.Text.Tertiary.Color,
		})
	end

	-- A scroll cue: a chevron shown only when rows exist off the fold that way.
	local function cue(order: number, icon: string, visible: fusion.UsedAs<boolean>): Instance
		return scope:New("Frame")({
			Name = "Cue",
			LayoutOrder = order,
			Size = UDim2.fromOffset(tokens.KeyCapIconSize, tokens.KeyCapHeight),
			BackgroundTransparency = 1,
			Visible = visible,
			[Children] = kit.Icon(scope, {
				icon = icon,
				style = "Secondary",
				size = tokens.KeyCapIconSize,
				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
			}),
		})
	end

	return scope:New("Frame")({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, tokens.FooterHeight),
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,

		[Children] = {
			kit.Hairline(scope, { name = "Divider" }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, tokens.FooterPadding),
				PaddingRight = UDim.new(0, tokens.FooterPadding),
			}),

			scope:New("Frame")({
				Name = "Hints",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, tokens.KeyCapHeight),
				BackgroundTransparency = 1,
				-- The run acknowledgment takes over the hint row while it shows.
				Visible = scope:Computed(function(use: Use): boolean
					return use(props.flash) == ""
				end),

				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, tokens.KeyCapGap),
					}),
					--[[
						There is no back key. Esc already cancels, and stepping
						back a parameter lives on the breadcrumb's chevron.
					]]
					kit.KeyCap(scope, { key = "Enter", layoutOrder = 1 }),
					label(2, props.runLabel),
					kit.KeyCap(scope, {
						icon = "arrowUp",
						layoutOrder = 3,
						visible = props.listVisible,
					}),
					kit.KeyCap(scope, {
						icon = "arrowDown",
						layoutOrder = 4,
						visible = props.listVisible,
					}),
					label(5, props.navLabel, props.listVisible),
					kit.KeyCap(scope, { key = "Esc", layoutOrder = 6 }),
					label(7, props.closeLabel),
				},
			}),

			--[[
				The run acknowledgment, shown in the hint row's place for a
				moment. A checkmark and "Ran X" in the Valid colour on success,
				an xmark and "X failed" in the Invalid colour when the callback
				threw. The frame's width stops short of the count readout on the
				right and the label truncates inside it, so a long command name
				can never collide with "N of M".
			]]
			scope:New("Frame")({
				Name = "Flash",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, -tokens.FooterCountReserve, 0, tokens.KeyCapHeight),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use: Use): boolean
					return use(props.flash) ~= ""
				end),

				[Children] = {
					kit.Icon(scope, {
						icon = scope:Computed(function(use: Use): string
							return if use(props.flashValid) then "checkmark" else "xmark"
						end),
						color = scope:Computed(function(use: Use): Color3
							return if use(props.flashValid)
								then use(tree.Valid.Color)
								else use(tree.Invalid.Color)
						end),
						size = tokens.KeyCapIconSize,
						anchorPoint = Vector2.new(0, 0.5),
						position = UDim2.fromScale(0, 0.5),
					}),
					kit.Text(scope, {
						Name = "Label",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, tokens.KeyCapIconSize + tokens.Spacing.XS, 0.5, 0),
						Size = UDim2.new(
							1,
							-(tokens.KeyCapIconSize + tokens.Spacing.XS),
							0,
							tokens.KeyCapHeight
						),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Text = scope:Computed(function(use: Use): string
							local flashText: string = use(props.flash)
							if flashText == "" then
								return ""
							end
							return if use(props.flashValid)
								then `Ran {flashText}`
								else `{flashText} failed`
						end),
						TextColor3 = scope:Computed(function(use: Use): Color3
							return if use(props.flashValid)
								then use(tree.Valid.Color)
								else use(tree.Invalid.Color)
						end),
					}),
				},
			}),

			--[[
				Position readout with scroll cues, "N of M" plus a chevron when
				rows sit off the fold, so you always know where you are and that
				there is more.
			]]
			scope:New("Frame")({
				Name = "Position",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, tokens.KeyCapHeight),
				BackgroundTransparency = 1,

				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, tokens.Spacing.XS),
					}),
					kit.Text(scope, {
						Name = "Count",
						LayoutOrder = 1,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, tokens.KeyCapHeight),
						TextXAlignment = Enum.TextXAlignment.Right,
						Text = props.count,
						TextColor3 = tree.Text.Tertiary.Color,
					}),
					cue(2, "chevronUp", props.canScrollUp),
					cue(3, "chevronDown", props.canScrollDown),
				},
			}),
		},
	})
end
