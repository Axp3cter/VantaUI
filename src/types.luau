--!strict
--!optimize 2

--[[
	Types

	The public API surface, every shape a consumer of the library touches.
	Internal types live with their producers, never here. This file imports
	nothing, so the public contract cannot drag internals into consumers.
]]

-- Theme data ----------------------------------------------------------------------

-- Static palette description: hex colour + opacity percent (100 = opaque).
export type ColorSpec = {
	Hex: string,
	Alpha: number,
}

export type PaletteText = {
	Primary: ColorSpec,
	Secondary: ColorSpec,
	Tertiary: ColorSpec,
	Placeholder: ColorSpec,
}

export type PaletteData = {
	_id: string,
	Background: ColorSpec,
	Border: ColorSpec,
	Separator: ColorSpec,
	--[[
		A subtle raised fill shared by every small container (icon tiles,
		key-caps), so they read as one family rather than each picking its own.
	]]
	Surface: ColorSpec,
	Selection: ColorSpec,
	SelectionText: ColorSpec,
	Icon: ColorSpec,
	IconSelected: ColorSpec,
	Valid: ColorSpec,
	Invalid: ColorSpec,
	Text: PaletteText,
}

export type AccentOverride = {
	Selection: Color3,
	SelectionText: Color3?,
}

export type AccentData = {
	_id: string,
	Dark: AccentOverride,
	Light: AccentOverride,
}

-- Commands and arguments ----------------------------------------------------------

--[[
	The closed set of argument kinds. Adding a kind here forces a matching row
	in the kind dispatch table in core/arguments, or the checker rejects the
	lookup that indexes it.
]]
export type ArgumentKind = "string" | "number" | "boolean" | "enum"

export type EnumOption = {
	Value: unknown,
	Label: string,
	-- Alternate spellings the filter also matches, such as "on" for a Yes option.
	Aliases: { string }?,
	Icon: (string | number)?,
	--[[
		A colour swatch shown in the option's tile instead of a glyph, so a
		colour choice reads as the colour itself.
	]]
	Color: Color3?,
}

--[[
	One command argument. Type selects which constraint fields apply, and
	Validate runs last, an escape hatch for anything the kinds cannot express.
]]
export type CommandArgument = {
	Name: string,
	Type: ArgumentKind,
	Optional: boolean?,
	Default: unknown?,
	Placeholder: string?,

	--[[
		Number constraints. Out-of-range input is rejected unless Clamp folds
		it in, and Step snaps the value to a multiple anchored at Min.
	]]
	Min: number?,
	Max: number?,
	Step: number?,
	Clamp: boolean?,

	-- string
	MaxLength: number?,
	Pattern: string?,

	-- enum
	Options: { EnumOption }?,
	--[[
		Reads the value that is active right now. The matching option is marked
		and sorted first, so a set command shows what it is currently set to.
	]]
	Current: (() -> unknown)?,
	--[[
		Called with the highlighted option's value while the pick list is open,
		for live preview. Exiting without committing calls it once more with
		the entry-time Current() value, restoring what was previewed over.
	]]
	Preview: ((value: unknown) -> ())?,

	Validate: ((value: unknown) -> (boolean, string?))?,
}

export type CommandProps = {
	Name: string?,
	Description: string?,
	Icon: (string | number)?,
	--[[
		Sections the command under this heading in the empty-query view. Any
		typed query flattens the list back to pure rank order.
	]]
	Group: string?,
	Aliases: { string }?,
	Arguments: { CommandArgument }?,
	Callback: ((...any) -> ())?,
	--[[
		Dismiss the palette after this command runs. The default is to stay
		open. You pick a command, it runs, and the field clears for the next.
	]]
	CloseAfter: boolean?,
}

-- Palette -------------------------------------------------------------------------

export type PaletteProps = {
	Theme: PaletteData?,
	Accent: AccentData?,
	Shortcut: { Enum.KeyCode }?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Placeholder: string?,
	Blur: boolean?,
}

return table.freeze({})
