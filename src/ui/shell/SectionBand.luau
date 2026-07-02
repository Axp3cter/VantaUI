--!strict
--!optimize 2

--[[
	SectionBand

	The browse view's section context, one quiet labeled strip between the
	field and the list naming the selected row's section, swapping sharply as
	the selection crosses a cluster boundary. This is the accepted design for
	sections. Cluster boundaries inside the list get no markers of their own,
	no rules and no extra gap, ordering plus this live label are the section
	signal, and the list stays a uniform row grid. The band exists only over
	the browse view. Filtered search is flat, and picks and scalar entry are
	self-labeled. Only the strip's height ever animates, on the reveal it is
	handed, and the label itself never fades or slides.
]]

local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local tokens = require("@design/tokens")

local Children = fusion.Children

type Scope = fusion.Scope
type Use = fusion.Use

export type Props = {
	label: fusion.UsedAs<string>,
	reveal: fusion.UsedAs<number>,
	layoutOrder: number,
}

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()

	return scope:New("Frame")({
		Name = "SectionBand",
		LayoutOrder = props.layoutOrder,
		Size = scope:Computed(function(use: Use): UDim2
			local reveal: number = use(props.reveal)
			return UDim2.new(1, 0, 0, reveal * tokens.SectionBandHeight)
		end),
		BackgroundTransparency = 1,
		ClipsDescendants = true,

		[Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, tokens.FieldPadding),
				PaddingRight = UDim.new(0, tokens.FieldPadding),
			}),
			kit.Text(scope, {
				Style = "Caption",
				Name = "Label",
				Size = UDim2.new(1, 0, 0, tokens.SectionBandHeight),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use: Use): string
					return use(props.label):upper()
				end),
				TextColor3 = tree.Text.Tertiary.Color,
			}),
		},
	})
end
