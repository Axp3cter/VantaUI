--!strict
--!optimize 2

--[[
	Tile

	The 40px rounded Surface container, either a glyph on a faint fill or an
	opaque colour swatch. Swatch mode stays fully opaque so the colour reads
	true even over the selection pill. Glyph mode exposes its surface
	transparency so a row can fade the tile out under the selection tint.
]]

local Icon = require("@ui/kit/Icon")
local fusion = require("@runtime/fusion")
local theme = require("@ui/kit/theme")
local tokens = require("@design/tokens")

type Scope = fusion.Scope

export type Props = {
	-- When set, the tile IS the colour: an opaque filled swatch, no glyph.
	swatch: Color3?,
	icon: fusion.UsedAs<string | number>?,
	iconColor: fusion.UsedAs<Color3>?,
	iconTransparency: fusion.UsedAs<number>?,
	-- The row passes its springing selection alpha so the tile fades under the pill.
	surfaceTransparency: fusion.UsedAs<number>?,
	--[[
		Ring colour and transparency for swatch mode. The colour defaults to
		the theme border, which keeps contrast in both palettes.
	]]
	swatchRingColor: fusion.UsedAs<Color3>?,
	swatchRingTransparency: fusion.UsedAs<number>?,
	-- Press micro-interaction: dips the whole tile via a UIScale when provided.
	scale: fusion.UsedAs<number>?,
	size: number?,
	iconSize: number?,
	-- Corner rounding override for smaller tiles. Defaults to the 40px tile's.
	corner: number?,
	name: string?,
	layoutOrder: number?,
	anchorPoint: Vector2?,
	position: UDim2?,
}

return function(scope: Scope, props: Props): Instance
	local tree = theme.now()
	local size = props.size or tokens.IconTileSize

	local children: { fusion.Child } = {
		scope:New("UICorner")({
			CornerRadius = UDim.new(0, props.corner or tokens.IconTileCorner),
		}),
	}
	if props.scale ~= nil then
		table.insert(children, scope:New("UIScale")({ Scale = props.scale }))
	end
	--[[
		A swatch gets a faint 1px ring, so a swatch the same colour as whatever
		sits behind it (the selection pill, the panel) stays a defined tile.
	]]
	if props.swatch ~= nil then
		table.insert(
			children,
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = tokens.StrokeThickness,
				Color = props.swatchRingColor or tree.Border.Color,
				Transparency = props.swatchRingTransparency or tokens.SwatchRingRest,
			})
		)
	end
	if props.swatch == nil and props.icon ~= nil then
		table.insert(
			children,
			Icon(scope, {
				icon = props.icon,
				color = props.iconColor,
				transparency = props.iconTransparency,
				size = props.iconSize or tokens.IconSize,
				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
			})
		)
	end

	return scope:New("Frame")({
		Name = props.name or (if props.swatch then "Swatch" else "Tile"),
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(size, size),
		BorderSizePixel = 0,
		BackgroundColor3 = props.swatch or tree.Surface.Color,
		BackgroundTransparency = if props.swatch
			then 0
			else props.surfaceTransparency or tree.Surface.Alpha,

		[fusion.Children] = children,
	})
end
