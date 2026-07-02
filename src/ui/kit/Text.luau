--!strict
--!optimize 2

--[[
	Text

	The single place font and size reach a Roblox instance. A typography role is
	applied as one unit, so a role can never drift onto the wrong weight. The
	caller's props are cloned, never mutated, and an explicit caller value
	always wins over a default.
]]

local fusion = require("@runtime/fusion")
local theme = require("@ui/kit/theme")
local typography = require("@design/typography")

type Scope = fusion.Scope

export type StyleName = "Input" | "Title" | "Body" | "Muted" | "Caption"

--[[
	A plain property table plus two pseudo-props consumed here. Style is a
	typography role defaulting to Body, and As picks TextLabel or TextBox.
	Every other field is a plain instance property and is forwarded untouched.
]]
export type Props = fusion.PropertyTable

return function(scope: Scope, props: Props): Instance
	local styleName: StyleName = (props.Style :: StyleName?) or "Body"
	local style = typography[styleName]
	local className: string = (props.As :: string?) or "TextLabel"
	local tree = theme.now()

	local forwarded = table.clone(props) :: fusion.PropertyTable
	forwarded.Style = nil
	forwarded.As = nil
	forwarded.Font = style.Font
	forwarded.TextSize = style.Size
	if style.Transparency ~= nil and forwarded.TextTransparency == nil then
		forwarded.TextTransparency = style.Transparency
	end
	if forwarded.TextColor3 == nil then
		forwarded.TextColor3 = tree.Text.Primary.Color
	end
	if forwarded.BackgroundTransparency == nil then
		forwarded.BackgroundTransparency = 1
	end

	return scope:New(className)(forwarded)
end
