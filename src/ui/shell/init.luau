--!strict
--!optimize 2

--[[
	shell

	The chrome that frames the regions and the one place they compose. It owns
	the ScreenGui, the dismiss scrim, the scene BlurEffect and the panel
	assembly. Regions never import each other. This file is where they meet,
	each bound to the store's state.
]]

local EntryHeader = require("@ui/field/EntryHeader")
local Footer = require("@ui/shell/Footer")
local Panel = require("@ui/shell/Panel")
local ParameterRow = require("@ui/list/ParameterRow")
local SectionBand = require("@ui/shell/SectionBand")
local Store = require("@palette/Store")
local field = require("@ui/field")
local fusion = require("@runtime/fusion")
local list = require("@ui/list")
local services = require("@runtime/services")
local tokens = require("@design/tokens")

local Children = fusion.Children
local OnEvent = fusion.OnEvent

type Scope = fusion.Scope
type Use = fusion.Use

export type Props = {
	store: Store.Store,
	position: UDim2,
	anchorPoint: Vector2,
	placeholder: string,
}

return function(scope: Scope, props: Props): ScreenGui
	local store = props.store

	local header = EntryHeader(scope, {
		entry = store.entry,
		reveal = store.headerReveal,
		onBack = function()
			store:stepBack()
		end,
		layoutOrder = 1,
	})

	local fieldRow = field(scope, {
		text = store.query,
		entry = store.entry,
		searchPlaceholder = props.placeholder,
		onReady = function(textBox: TextBox)
			store:bindField(textBox)
		end,
	})

	-- The list hands its step function up, and the panel's wheel drives it.
	local listStepper: ((direction: number) -> ())? = nil

	local content = scope:New("Frame")({
		Name = "Content",
		Size = scope:Computed(function(use: Use): UDim2
			return UDim2.new(1, 0, 0, use(store.contentHeight))
		end),
		BackgroundTransparency = 1,

		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			--[[
				The browse view's section context, above the list and outside
				its scroll flow, so cluster boundaries in the flow need no
				markers of their own.
			]]
			SectionBand(scope, {
				label = store.sectionLabel,
				reveal = store.bandReveal,
				layoutOrder = 1,
			}),
			list(scope, {
				evaluation = store.evaluation,
				selectedIndex = store.selectedIndex,
				viewKey = store.viewKey,
				listHeight = store.listHeight,
				layoutOrder = 2,
				emptyText = store.emptyText,
				visible = store.showList,
				canScrollUp = store.canScrollUp,
				canScrollDown = store.canScrollDown,
				onStepperReady = function(step: (direction: number) -> ())
					listStepper = step
				end,
				onFollowReady = function(follow: () -> ())
					store:bindFollower(follow)
				end,
			}),
			--[[
				The scalar-step body, one standard row for the current
				parameter. It shares the list's height spring and exactly one
				of the two bodies is visible at a time, so the panel keeps the
				same anatomy in every mode.
			]]
			ParameterRow(scope, {
				entry = store.entry,
				validity = store.validity,
				query = store.query,
				height = store.listHeight,
				visible = store.showParameter,
				layoutOrder = 3,
			}),
			Footer(scope, {
				runLabel = store.footerRun,
				navLabel = "navigate",
				closeLabel = store.footerClose,
				count = store.footerCount,
				canScrollUp = store.footerScrollUp,
				canScrollDown = store.footerScrollDown,
				flash = store.flash,
				flashValid = store.flashValid,
				listVisible = store.showList,
				layoutOrder = 4,
			}),
		} :: { fusion.Child },
	})

	local panel = Panel(scope, {
		position = props.position,
		anchorPoint = props.anchorPoint,
		transparency = store.transparency,
		offsetY = store.offsetY,
		scale = store.scale,
		onWheel = function(direction: number)
			if listStepper ~= nil and fusion.peek(store.showList) then
				listStepper(direction)
			end
		end,
		width = store.panelWidth,
		height = store.panelHeight,
		header = header,
		field = fieldRow,
		content = content,
	}) :: GuiObject

	--[[
		Frosted backdrop, a scene BlurEffect while the palette is open and Blur
		is on. Its size springs in and out, so the frost fades rather than snaps.
	]]
	scope:New("BlurEffect")({
		Size = store.blurSize,
		Parent = services.Lighting,
	})

	--[[
		A native, fully transparent dismiss scrim beneath the panel. Its only
		job is catching outside clicks with Roblox hit-testing, no coordinate
		math anywhere.
	]]
	local scrim = scope:New("TextButton")({
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 0,
		Visible = store.shown,
		[OnEvent("Activated")] = function()
			store:onDismiss()
		end,
	})

	return scope:New("ScreenGui")({
		Name = "VantaUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = tokens.Defaults.DisplayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		[Children] = { scrim, panel } :: { fusion.Child },
	}) :: ScreenGui
end
