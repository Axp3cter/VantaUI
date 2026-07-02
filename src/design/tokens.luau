--!strict
--!optimize 2

--[[
	tokens

	Every layout dimension, stroke, chrome opacity and behaviour default. It
	owns the Radius and Spacing scales, all named metrics, and the palette
	defaults. Components never declare a size inline. Every dimension resolves
	to a scale step or a named token, and derived values are computed from
	their parts.
]]

-- Constants -------------------------------------------------------------------------

-- The rounding language: small pills/key-caps, medium content containers, the panel.
local Radius = table.freeze({
	Small = 6,
	Medium = 12,
	Large = 16,
})

-- The 4px spacing rhythm.
local Spacing = table.freeze({
	XS = 4,
	SM = 8,
	MD = 12,
	LG = 16,
	XL = 20,
	XXL = 24,
})

local ROW_HEIGHT = 60
local ROW_GAP = Spacing.XS
local LIST_PADDING = Spacing.SM
local MAX_VISIBLE_ROWS = 7

local ROW_PITCH = ROW_HEIGHT + ROW_GAP
--[[
	N whole rows span N pitches minus one gap (there are N minus 1 gaps, not N),
	plus the top and bottom list padding. Using N whole pitches would over-count
	by one gap and let the next row peek at the bottom.
]]
local LIST_MAX_HEIGHT = MAX_VISIBLE_ROWS * ROW_PITCH - ROW_GAP + LIST_PADDING * 2

-- Behaviour defaults applied when a caller omits the matching PaletteProps field.
local Defaults = table.freeze({
	Shortcut = { Enum.KeyCode.LeftControl, Enum.KeyCode.K } :: { Enum.KeyCode },
	Placeholder = "Search commands…",
	Position = UDim2.fromScale(0.5, 0.4),
	AnchorPoint = Vector2.new(0.5, 0.5),
	DisplayOrder = 1_000_000,
	Blur = false,

	-- Fallbacks for a command that omits them.
	CommandName = "Command",
	CommandDescription = "",
	CommandIcon = "command",
	CommandCallback = function() end,
})

-- Public ----------------------------------------------------------------------------

return table.freeze({
	--[[
		The scales, exported so a component can reach for a step directly when
		it needs one that has no dedicated token yet, but never a raw number.
	]]
	Radius = Radius,
	Spacing = Spacing,

	Defaults = Defaults,

	--[[
		Panel size clamps to the viewport, a fraction of the width and height,
		bounded so it never overflows a phone or looks lost on a large screen.
	]]
	PanelMinWidth = 420,
	PanelMaxWidth = 620,
	PanelWidthScale = 0.42,
	PanelHeightScale = 0.6,
	PanelCorner = Radius.Large,
	StrokeThickness = 1,
	BlurSize = 24, -- frosted backdrop strength while Blur is on

	FieldHeight = ROW_HEIGHT,
	FieldPadding = Spacing.XL,

	SeparatorHeight = 1,

	RowHeight = ROW_HEIGHT,
	RowGap = ROW_GAP,
	RowPitch = ROW_PITCH,
	RowCorner = Radius.Medium,
	--[[
		The content gutter. ListInset plus RowPadding must equal FieldPadding
		and FooterPadding, so the command column lines up with the search glyph
		and the footer keys on both walls. That is 8 plus 12, giving 20.
	]]
	RowPadding = Spacing.MD,
	RowTitleHeight = 20,
	RowDescriptionHeight = 18,
	RowTextGap = Spacing.XS,
	--[[
		The selection pill's horizontal inset sits just inside the content
		gutter, so the content clears the pill's rounded corners. The pill edge
		lands at ListInset plus SelectionPadX (8 plus 4, giving 12) with content
		at 20, leaving an even 8px on both sides.
	]]
	SelectionPadX = Spacing.XS,
	SelectionPadY = Spacing.XS,

	IconSize = 26,
	IconGap = Spacing.LG,
	--[[
		The 1px ring on swatch tiles, so a swatch the same colour as the
		selection pill stays a defined tile instead of vanishing into it. It
		firms up when the row is selected.
	]]
	SwatchRingRest = 0.75,
	SwatchRingActive = 0.35,
	--[[
		How much a hovered row's Surface tile lifts, as a transparency decrease.
		One visible step, pointer only, never on keyboard selection.
	]]
	SurfaceHoverLift = 0.08,
	--[[
		Each glyph sits on a faint rounded Surface tile, building a structured
		left rail. The tile fades out under the selection tint so a picked row
		reads clean.
	]]
	IconTileSize = 40,
	IconTileCorner = Radius.Medium,
	ClearSize = 16, -- the clear-query affordance at the field's right edge

	MaxVisibleRows = MAX_VISIBLE_ROWS,
	ListPadding = LIST_PADDING,
	ListInset = Spacing.SM,
	ListMaxHeight = LIST_MAX_HEIGHT,
	EmptyHeight = 64,
	--[[
		The browse view's section context, a fixed strip between the field and
		the list naming the selected row's section. Sections live here, out of
		the scroll flow entirely, so clusters in the list are separated by
		nothing but the standard row gap.
	]]
	SectionBandHeight = 28,

	--[[
		The footer is scaled to the rows at four fifths of a row, not left as a
		cramped strip. Its chips share the small-container rounding and spacing.
	]]
	FooterHeight = 48,
	FooterPadding = Spacing.XL,
	KeyCapHeight = 24,
	KeyCapMinWidth = 24,
	KeyCapPadding = Spacing.SM,
	KeyCapCorner = Radius.Small,
	KeyCapGap = Spacing.SM,
	KeyCapIconSize = 14,
	-- Width the flash keeps clear for the count readout and its scroll cues.
	FooterCountReserve = 120,

	-- The custom scroll indicator at the list's right edge (native bar stays off).
	ScrollIndicatorThickness = 2,
	ScrollIndicatorInset = Spacing.XS,
	ScrollIndicatorMinHeight = 16,

	--[[
		Argument-entry chrome, a plain title bar with the back chevron and the
		command name. The parameter itself renders as a standard row, so entry
		needs no other dimensions of its own.
	]]
	EntryHeaderHeight = 44,
})
