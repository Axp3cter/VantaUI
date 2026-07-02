--!strict
--!optimize 2

--[[
	palettes

	The base palettes and accents, macOS Sequoia system colours as pure data.
	Each palette is a tree of Hex and Alpha specs the Theme class turns into
	reactive Values. Opacity is a friendly percent where 100 is opaque.
]]

local types = require("@vanta/types")

-- Types -----------------------------------------------------------------------------

export type Accents = {
	Blue: types.AccentData,
	Purple: types.AccentData,
	Pink: types.AccentData,
	Red: types.AccentData,
	Orange: types.AccentData,
	Yellow: types.AccentData,
	Green: types.AccentData,
	Graphite: types.AccentData,
}

-- Private ---------------------------------------------------------------------------

local function spec(hex: string, alpha: number): types.ColorSpec
	return table.freeze({ Hex = hex, Alpha = alpha })
end

local function accent(id: string, dark: string, light: string): types.AccentData
	return table.freeze({
		_id = id,
		Dark = table.freeze({ Selection = Color3.fromHex(dark) }),
		Light = table.freeze({ Selection = Color3.fromHex(light) }),
	})
end

-- Public ----------------------------------------------------------------------------

local Dark: types.PaletteData = table.freeze({
	_id = "Dark",

	--[[
		One cohesive, opaque surface. The frosted backdrop lives behind the
		whole panel, not through it, so nothing ghosts through.
	]]
	Background = spec("1C1C1E", 100),
	Border = spec("FFFFFF", 8),
	Separator = spec("FFFFFF", 14),
	-- Subtle raised fill for small containers (icon tiles, key-caps).
	Surface = spec("FFFFFF", 16),

	-- A strong, cohesive accent fill, and the row draws no border over it.
	Selection = spec("0A84FF", 85),
	SelectionText = spec("FFFFFF", 100),

	Icon = spec("FFFFFF", 88),
	IconSelected = spec("FFFFFF", 100),

	-- Argument-validation feedback, toned to sit with the muted palette.
	Valid = spec("3FB950", 100),
	Invalid = spec("F0665C", 100),

	Text = table.freeze({
		Primary = spec("FFFFFF", 92),
		Secondary = spec("FFFFFF", 58),
		Tertiary = spec("FFFFFF", 42),
		Placeholder = spec("FFFFFF", 40),
	}),
})

local Light: types.PaletteData = table.freeze({
	_id = "Light",

	Background = spec("F2F2F4", 100),
	Border = spec("000000", 12),
	Separator = spec("000000", 14),
	Surface = spec("000000", 7),

	Selection = spec("007AFF", 85),
	SelectionText = spec("FFFFFF", 100),

	Icon = spec("000000", 78),
	IconSelected = spec("FFFFFF", 100),

	Valid = spec("34A853", 100),
	Invalid = spec("E5534B", 100),

	Text = table.freeze({
		Primary = spec("000000", 92),
		Secondary = spec("000000", 58),
		Tertiary = spec("000000", 45),
		Placeholder = spec("000000", 45),
	}),
})

--[[
	Each accent overrides only the accent-driven tokens (currently Selection),
	per light and dark base, applied on top of a base palette by the Theme class.
]]
local Accents: Accents = table.freeze({
	Blue = accent("Blue", "0A84FF", "007AFF"),
	Purple = accent("Purple", "BF5AF2", "AF52DE"),
	Pink = accent("Pink", "FF375F", "FF2D55"),
	Red = accent("Red", "FF453A", "FF3B30"),
	Orange = accent("Orange", "FF9F0A", "FF9500"),
	Yellow = accent("Yellow", "FFD60A", "FFCC00"),
	Green = accent("Green", "32D74B", "28CD41"),
	Graphite = accent("Graphite", "98989D", "8E8E93"),
})

return table.freeze({
	Dark = Dark,
	Light = Light,
	Accents = Accents,
})
