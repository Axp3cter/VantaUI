--!strict
--!optimize 2

--[[
	Panel

	The rounded 1px-stroke surface and its entrance motion. The crisp stroke
	lives on the outer frame while the inner CanvasGroup fades and slides the
	surface as one, because a stroke on the CanvasGroup would get its outer
	edge clipped by the render buffer. There is no drop shadow. The sharp look
	is a defined 1px edge, not a soft glow.
]]

local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local tokens = require("@design/tokens")

local Children = fusion.Children
local OnEvent = fusion.OnEvent

type Scope = fusion.Scope
type Use = fusion.Use

export type Props = {
	position: UDim2,
	anchorPoint: Vector2,
	transparency: fusion.UsedAs<number>,
	offsetY: fusion.UsedAs<number>,
	-- Entrance: the whole panel settles from a slightly smaller scale to 1.
	scale: fusion.UsedAs<number>,
	width: fusion.UsedAs<number>,
	height: fusion.UsedAs<number>,
	--[[
		Wheel input anywhere over the panel, forwarded so the list steps even
		when the cursor sits over the field or footer.
	]]
	onWheel: ((direction: number) -> ())?,
	-- The vertical sequence, built by the shell and slotted in.
	header: Instance,
	field: Instance,
	content: Instance,
}

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()

	-- Panel owns the vertical sequence: header, field, separator, content.
	local header = props.header :: GuiObject
	local field = props.field :: GuiObject
	local content = props.content :: GuiObject
	header.LayoutOrder = 1
	field.LayoutOrder = 2
	content.LayoutOrder = 4

	-- The border fades with the panel, floored at its resting subtlety.
	local function faded(base: fusion.UsedAs<number>): fusion.UsedAs<number>
		return scope:Computed(function(use: Use): number
			local rest: number = use(base)
			local fade: number = use(props.transparency)
			return rest + fade * (1 - rest)
		end)
	end

	-- Cast: mixed special keys (OnEvent + Children) must not unify value types.
	return scope:New("Frame")({
		Name = "Vanta",
		--[[
			Consume clicks on the panel's own area so they do not fall through
			to the dismiss scrim behind it. Rows are buttons and still handle
			their own clicks.
		]]
		Active = true,
		[OnEvent("InputChanged")] = function(inputObject: InputObject)
			if
				props.onWheel ~= nil
				and inputObject.UserInputType == Enum.UserInputType.MouseWheel
			then
				-- Wheel up scrolls toward the top, a smaller canvas offset.
				props.onWheel(-inputObject.Position.Z)
			end
		end,
		AnchorPoint = props.anchorPoint,
		Position = scope:Computed(function(use: Use): UDim2
			return props.position + UDim2.fromOffset(0, use(props.offsetY))
		end),
		Size = scope:Computed(function(use: Use): UDim2
			return UDim2.fromOffset(use(props.width), use(props.height))
		end),
		BackgroundTransparency = 1,

		[Children] = {
			scope:New("UIScale")({ Scale = props.scale }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0, tokens.PanelCorner) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = tokens.StrokeThickness,
				Color = tree.Border.Color,
				Transparency = faded(tree.Border.Alpha),
			}),

			scope:New("CanvasGroup")({
				Name = "Surface",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
				GroupTransparency = props.transparency,
				BackgroundColor3 = tree.Background.Color,
				BackgroundTransparency = tree.Background.Alpha,
				BorderSizePixel = 0,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, tokens.PanelCorner) }),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					header,
					field,
					kit.Hairline(scope, { name = "Separator", layoutOrder = 3 }),
					content,
				} :: { fusion.Child },
			}),
		},
	} :: fusion.PropertyTable)
end
