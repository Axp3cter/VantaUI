--!strict
--!optimize 2

--[[
	Palette

	The application, construction and the public proxy, wiring only. The root
	scope owns the Registry and Theme, so a command's reactive fields provably
	outlive the inner view scope that reads them. Destroy releases the root and
	the view with it.
]]

local Flow = require("@palette/Flow")
local Registry = require("@palette/Registry")
local Store = require("@palette/Store")
local Theme = require("@design/theme")
local fusion = require("@runtime/fusion")
local input = require("@runtime/input")
local kit = require("@ui/kit")
local palettes = require("@design/theme/palettes")
local protect = require("@runtime/protect")
local proxy = require("@runtime/proxy")
local shell = require("@ui/shell")
local tokens = require("@design/tokens")
local types = require("@vanta/types")

local Palette = {}

export type Palette = {
	Theme: types.PaletteData,
	Accent: types.AccentData,
	Blur: boolean,
	IsOpen: boolean,
	Register: (props: types.CommandProps) -> Registry.Handle,
	Show: () -> (),
	Hide: () -> (),
	Toggle: () -> (),
	Destroy: () -> (),
}

function Palette.new(props: types.PaletteProps): Palette
	local scope = fusion.scoped(fusion.constructors, kit)

	local theme =
		Theme.new(scope, props.Theme or palettes.Dark, props.Accent or palettes.Accents.Blue)
	local registry = Registry.new(scope)

	--[[
		The view scope owns everything visual and reactive-derived. The root
		owns it, so Destroy releases both in order.
	]]
	local view = fusion.innerScope(scope, fusion.constructors, kit)

	local store = Store.new(view, registry, props)
	local flow = Flow.new(store)
	--[[
		Cast because a metatable class does not structurally subtype the
		FlowLike record under the old solver. The method set matches by
		construction.
	]]
	store:attachFlow((flow :: unknown) :: Store.FlowLike)

	local screenGui = kit.theme:is(theme.tree):during(function(): ScreenGui
		return shell(view, {
			store = store,
			position = props.Position or tokens.Defaults.Position,
			anchorPoint = props.AnchorPoint or tokens.Defaults.AnchorPoint,
			placeholder = props.Placeholder or tokens.Defaults.Placeholder,
		})
	end)

	protect.take(screenGui)

	input.attach(view, {
		shortcut = props.Shortcut or tokens.Defaults.Shortcut,
		isOpen = function(): boolean
			return fusion.peek(store.shown)
		end,
		onToggle = function()
			store:toggle()
		end,
		onNavigate = function(delta: number)
			store:moveSelection(delta)
		end,
		onJump = function(action: input.JumpAction)
			store:jumpSelection(action)
		end,
		onConfirm = function()
			store:onConfirm()
		end,
		onDismiss = function()
			store:onDismiss()
		end,
	})

	return proxy.new("VantaUI palette", {
		Register = {
			get = function(): unknown
				return function(commandProps: types.CommandProps): Registry.Handle
					return registry:register(commandProps)
				end
			end,
		},
		Show = {
			get = function(): unknown
				return function()
					store:show()
				end
			end,
		},
		Hide = {
			get = function(): unknown
				return function()
					store:hide()
				end
			end,
		},
		Toggle = {
			get = function(): unknown
				return function()
					store:toggle()
				end
			end,
		},
		Destroy = {
			get = function(): unknown
				return function()
					--[[
						No animated hide here. Cleanup destroys the panel
						outright, and hide's delayed reset would race the
						destroyed Values.
					]]
					store:releaseFocus()
					fusion.doCleanup(scope)
				end
			end,
		},
		IsOpen = {
			get = function(): unknown
				return fusion.peek(store.shown)
			end,
		},
		Theme = {
			get = function(): unknown
				return theme:palette()
			end,
			set = function(value: unknown)
				theme:setPalette(value :: types.PaletteData)
			end,
		},
		Accent = {
			get = function(): unknown
				return theme:accent()
			end,
			set = function(value: unknown)
				theme:setAccent(value :: types.AccentData)
			end,
		},
		Blur = {
			get = function(): unknown
				return fusion.peek(store.blurEnabled)
			end,
			set = function(value: unknown)
				store.blurEnabled:set(value :: boolean)
			end,
		},
	})
end

return table.freeze(Palette)
