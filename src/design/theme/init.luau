--!strict
--!optimize 2

--[[
	Theme

	Owns the live colour tree, a mirror tree of Fusion Values built once from a
	static palette. Swapping the palette or accent resets the same Values in
	place, so the palette schema is written down once and the reactive tree has
	one owner.
]]

local fusion = require("@runtime/fusion")
local types = require("@vanta/types")

type Scope = fusion.Scope

-- Types -----------------------------------------------------------------------------

-- A reactive colour + transparency, bindable straight into instance properties.
export type Token = {
	Color: fusion.Value<Color3>,
	Alpha: fusion.Value<number>,
}

export type ThemeText = {
	Primary: Token,
	Secondary: Token,
	Tertiary: Token,
	Placeholder: Token,
}

-- The built, reactive theme tree that components bind against.
export type ThemeTree = {
	_id: string,
	Background: Token,
	Border: Token,
	Separator: Token,
	Surface: Token,
	Selection: Token,
	SelectionText: Token,
	Icon: Token,
	IconSelected: Token,
	Valid: Token,
	Invalid: Token,
	Text: ThemeText,
}

-- A node in either the spec tree or the reactive tree. The walk narrows leaves.
type Node = { [string]: unknown }

-- Private ---------------------------------------------------------------------------

local function isColorSpec(value: unknown): boolean
	return typeof(value) == "table"
		and typeof((value :: Node).Hex) == "string"
		and typeof((value :: Node).Alpha) == "number"
end

local function toColor(spec: types.ColorSpec): Color3
	return Color3.fromHex(spec.Hex)
end

--[[
	Palette opacity is a friendly percent where 100 is opaque. Instances want a
	0 to 1 transparency, so it inverts here once.
]]
local function toAlpha(spec: types.ColorSpec): number
	return 1 - spec.Alpha / 100
end

--[[
	One recursive walk shared by build and reset. For each colour spec it calls
	sink(container, key, spec), so the tree's shape is described exactly once.
]]
local function walk(specs: Node, container: Node, sink: (Node, string, types.ColorSpec) -> ()): ()
	for key, value in specs do
		if key == "_id" then
			container[key] = value
		elseif isColorSpec(value) then
			sink(container, key, value :: types.ColorSpec)
		elseif typeof(value) == "table" then
			local child = (container[key] or {}) :: Node
			container[key] = child
			walk(value :: Node, child, sink)
		end
	end
end

-- Public ----------------------------------------------------------------------------

local Theme = {}
Theme.__index = Theme

export type Theme = typeof(setmetatable(
	{} :: {
		tree: ThemeTree,
		_palette: types.PaletteData,
		_accent: types.AccentData,
	},
	{} :: typeof(Theme)
))

function Theme.new(scope: Scope, palette: types.PaletteData, accent: types.AccentData): Theme
	local tree: Node = {}
	walk((palette :: unknown) :: Node, tree, function(container, key, spec)
		container[key] = table.freeze({
			Color = scope:Value(toColor(spec)),
			Alpha = scope:Value(toAlpha(spec)),
		})
	end)

	local self = setmetatable({
		tree = (tree :: unknown) :: ThemeTree,
		_palette = palette,
		_accent = accent,
	}, Theme)
	self:_applyAccent()
	return self
end

--[[
	Picks the light or dark accent variant for the palette currently in the
	tree. An accent may override the selection-text colour. When it does not,
	the base palette's stands.
]]
function Theme._applyAccent(self: Theme): ()
	local variant = if self.tree._id == "Light" then self._accent.Light else self._accent.Dark
	self.tree.Selection.Color:set(variant.Selection)
	if variant.SelectionText then
		self.tree.SelectionText.Color:set(variant.SelectionText)
	end
end

function Theme.setPalette(self: Theme, palette: types.PaletteData): ()
	self._palette = palette
	walk(
		(palette :: unknown) :: Node,
		(self.tree :: unknown) :: Node,
		function(container, key, spec)
			local token = container[key] :: Token
			token.Color:set(toColor(spec))
			token.Alpha:set(toAlpha(spec))
		end
	)
	self:_applyAccent()
end

function Theme.setAccent(self: Theme, accent: types.AccentData): ()
	self._accent = accent
	self:_applyAccent()
end

function Theme.palette(self: Theme): types.PaletteData
	return self._palette
end

function Theme.accent(self: Theme): types.AccentData
	return self._accent
end

return table.freeze(Theme)
