--!strict
--!optimize 2

--[[
	Vanta

	The library entry point. Vanta.new builds a palette, and the Themes, Accents
	and Icons tables are what consumers reference by name. This is the only
	module a consumer requires, everything else is internal.
]]

local Palette = require("@palette")
local Registry = require("@palette/Registry")
local icons = require("@design/icons")
local palettes = require("@design/theme/palettes")
local types = require("@vanta/types")

export type Palette = Palette.Palette
export type Command = Registry.Handle
export type PaletteProps = types.PaletteProps
export type CommandProps = types.CommandProps
export type CommandArgument = types.CommandArgument
export type EnumOption = types.EnumOption
export type PaletteData = types.PaletteData
export type AccentData = types.AccentData

local Vanta = {
	Themes = table.freeze({ Dark = palettes.Dark, Light = palettes.Light }),
	Accents = palettes.Accents,
	Icons = icons.Icons,
}

function Vanta.new(props: types.PaletteProps?): Palette.Palette
	return Palette.new(props or {})
end

return table.freeze(Vanta)
