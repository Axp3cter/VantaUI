--!strict
--!optimize 2

--[[
	typography

	Named text styles, each a font, a size and an optional de-emphasis applied
	as one unit. Only ui/kit/Text applies them, so a role can never pair with
	the wrong weight. Colour stays a theme concern and is never part of a style.
]]

export type Style = {
	Font: Enum.Font,
	Size: number,
	Transparency: number?,
}

local Regular = Enum.Font.Gotham
local Medium = Enum.Font.GothamMedium

local function style(font: Enum.Font, size: number, transparency: number?): Style
	return table.freeze({ Font = font, Size = size, Transparency = transparency })
end

return table.freeze({
	Input = style(Medium, 17), -- the search field
	Title = style(Medium, 16), -- a row's primary line
	Body = style(Regular, 14), -- hints, labels, breadcrumb
	Muted = style(Regular, 14, 0.22), -- de-emphasised body (a row's description)
	Caption = style(Regular, 12), -- trailing hints, progress, section headers
})
