--!strict
--!optimize 2

--[[
	Store

	Owns the palette's reactive state and every derivation over it. Each derived
	value is a Computed over the owned state, nothing is mirrored by hand, and no
	Roblox instances are created here.
]]

local Registry = require("@palette/Registry")
local Session = require("@core/Session")
local arguments = require("@core/arguments")
local fusion = require("@runtime/fusion")
local matcher = require("@core/matcher")
local motion = require("@design/motion")
local services = require("@runtime/services")
local tokens = require("@design/tokens")
local types = require("@vanta/types")

type Scope = fusion.Scope
type Use = fusion.Use

-- Constants -------------------------------------------------------------------------

local MAX_RECENTS = 5

--[[
	Sentinel meaning no value has been previewed yet. Distinct from every real
	value, including nil.
]]
local PREVIEW_NONE = table.freeze({})

--[[
	A boolean parameter presents as a two-option pick, exactly like an enum. The
	aliases let typed spellings (true, on, 1 and their negatives) filter-match
	the two labels, so typing works as well as picking. The options carry no
	icons so they take the bullet default, leaving the trailing checkmark as the
	only checkmark on the row, meaning current.
]]
local BOOLEAN_OPTIONS: { types.EnumOption } = table.freeze({
	table.freeze({
		Value = true,
		Label = "Yes",
		Aliases = { "true", "on", "1" },
	}),
	table.freeze({
		Value = false,
		Label = "No",
		Aliases = { "false", "off", "0" },
	}),
} :: { types.EnumOption })

-- Types -----------------------------------------------------------------------------

--[[
	The argument-entry snapshot the view derives its header, prompt and
	parameter row from. Nil while searching, so the presence of an entry is the
	mode. The Value lives here with the rest of the state and Flow keeps it in
	sync.
]]
export type CollectedArg = Session.CollectedArg

export type EntryState = {
	command: string,
	-- The command's icon. The parameter row's tile carries it through the form.
	icon: string | number,
	arg: types.CommandArgument,
	index: number,
	total: number,
	collected: { Session.CollectedArg },
}

--[[
	One list row, decoupled from what produced it. A matched command and an enum
	option both project to a RowModel, so the list renders both through one path.
	The key is the stable identity rows are reused by, and the display fields are
	UsedAs so a command's live name and description bind while a static option's
	plain strings do not.
]]
export type RowModel = {
	key: unknown,
	icon: fusion.UsedAs<string | number>,
	title: fusion.UsedAs<string>,
	description: fusion.UsedAs<string>,
	-- True when the row opens argument entry. The row then shows a chevron.
	drillIn: boolean,
	-- When set, the row's tile is filled with this colour swatch instead of a glyph.
	swatch: Color3?,
	-- The option matching the argument's Current() value shows a trailing mark.
	checked: boolean?,
	-- True when the icon is the fallback dot, drawn smaller and quieter.
	bullet: boolean?,
	activate: () -> (),
}

--[[
	The ranked rows on screen. Order maps each row to its 1-based rank, and
	positions carries the matched name characters from the ranking alignment.
	Headers are section titles keyed by the row index each one begins at,
	present only in the browse view. They are data, not layout. They drive the
	browse ordering and the context band's label, and nothing in the flow
	renders them, so the list is uniform rows in every view.
]]
export type Evaluation = {
	rows: { RowModel },
	order: { [RowModel]: number },
	positions: { [RowModel]: { number } },
	headers: { [number]: string },
}

--[[
	Live validation of the current field against the current parameter. When a
	valid value resolves to something other than what was typed, from Clamp
	folding or Step snapping, resolved carries the display of what will actually
	be submitted, so the UI can say so instead of silently confirming.
]]
export type Validity = {
	valid: boolean,
	message: string,
	resolved: string?,
}

--[[
	The slice of the Flow that store actions drive. Structural, so the store never
	requires Flow (Flow requires the store) and init binds the real Flow once.
]]
export type FlowLike = {
	isActive: (self: FlowLike) -> boolean,
	begin: (self: FlowLike, command: Registry.Command) -> (),
	submit: (self: FlowLike, raw: string) -> (),
	back: (self: FlowLike) -> boolean,
	exit: (self: FlowLike) -> (),
	pickOption: (self: FlowLike, option: types.EnumOption) -> (),
}

-- Private ---------------------------------------------------------------------------

local NO_HEADERS: { [number]: string } = table.freeze({})

local EMPTY_EVALUATION: Evaluation =
	table.freeze({ rows = {}, order = {}, positions = {}, headers = NO_HEADERS })

--[[
	Rank items against text and project the survivors into an Evaluation. One
	routine for both commands and enum options. The caller supplies how an item
	becomes a search candidate and how it becomes a memoised row.
]]
local function project<T>(
	items: { T },
	text: string,
	toCandidate: (T) -> matcher.Candidate,
	toRow: (T) -> RowModel
): Evaluation
	local candidates = table.create(#items)
	for index, item in items do
		candidates[index] = toCandidate(item)
	end

	local ranked = matcher.rank(candidates, text)
	local rows = table.create(#ranked)
	local order: { [RowModel]: number } = {}
	local positions: { [RowModel]: { number } } = {}
	for rank, match in ranked do
		local model = toRow(items[match.index])
		rows[rank] = model
		order[model] = rank
		if match.positions ~= nil then
			positions[model] = match.positions
		end
	end
	return { rows = rows, order = order, positions = positions, headers = NO_HEADERS }
end

-- Stable partition. Rows marked checked move to the front, relative order kept.
local function checkedFirst(evaluation: Evaluation): Evaluation
	local rows = table.create(#evaluation.rows)
	for _, model in evaluation.rows do
		if model.checked then
			table.insert(rows, model)
		end
	end
	if #rows == 0 then
		return evaluation
	end
	for _, model in evaluation.rows do
		if not model.checked then
			table.insert(rows, model)
		end
	end
	local order: { [RowModel]: number } = {}
	for rank, model in rows do
		order[model] = rank
	end
	return {
		rows = rows,
		order = order,
		positions = evaluation.positions,
		headers = evaluation.headers,
	}
end

-- Public ----------------------------------------------------------------------------

local Store = {}
Store.__index = Store

export type Store = typeof(setmetatable(
	{} :: {
		query: fusion.Value<string>,
		selectedIndex: fusion.Value<number>,
		shown: fusion.Value<boolean>,
		flash: fusion.Value<string>,
		-- Whether the flash acknowledges a success or reports a failed callback.
		flashValid: fusion.Value<boolean>,
		canScrollUp: fusion.Value<boolean>,
		canScrollDown: fusion.Value<boolean>,
		blurEnabled: fusion.Value<boolean>,
		viewport: fusion.Value<Vector2>,
		entry: fusion.Value<EntryState?>,
		recents: fusion.Value<{ Registry.Command }>,

		panelWidth: fusion.Computed<number>,
		commandEvaluation: fusion.Computed<Evaluation>,
		optionEvaluation: fusion.Computed<Evaluation>,
		evaluation: fusion.Computed<Evaluation>,
		isPickMode: fusion.Computed<boolean>,
		inArguments: fusion.Computed<boolean>,
		headerReveal: fusion.Spring<number>,
		emptyText: fusion.Computed<string>,
		showList: fusion.Computed<boolean>,
		showParameter: fusion.Computed<boolean>,
		viewKey: fusion.Computed<string>,
		sectionLabel: fusion.Computed<string>,
		bandReveal: fusion.Spring<number>,
		footerRun: fusion.Computed<string>,
		footerClose: fusion.Computed<string>,
		footerCount: fusion.Computed<string>,
		footerScrollUp: fusion.Computed<boolean>,
		footerScrollDown: fusion.Computed<boolean>,
		validity: fusion.Computed<Validity>,
		listCap: fusion.Computed<number>,
		listHeight: fusion.Spring<number>,
		contentHeight: fusion.Computed<number>,
		panelHeight: fusion.Computed<number>,
		transparency: fusion.Spring<number>,
		offsetY: fusion.Spring<number>,
		scale: fusion.Spring<number>,
		blurSize: fusion.Spring<number>,

		_flow: FlowLike?,
		_textBox: TextBox?,
		--[[
			The list's keep-visible scroll, bound at build time. Only the
			keyboard paths below invoke it, because the pointer never scrolls
			the list.
		]]
		_follower: (() -> ())?,
		_flashToken: number,
		--[[
			Set by scope cleanup so a pending deferred callback can tell the
			store's Values have been destroyed and must not be touched.
		]]
		_destroyed: boolean,
		-- The armed Preview session, if the current pick argument has one.
		_previewArg: types.CommandArgument?,
		_previewRestore: (() -> ())?,
		_previewLast: unknown,
		_previewCommitted: boolean,
	},
	{} :: typeof(Store)
))

function Store.new(scope: Scope, registry: Registry.Registry, props: types.PaletteProps): Store
	local self: Store

	local query = scope:Value("")
	local selectedIndex = scope:Value(1)
	local shown = scope:Value(false)
	-- A brief run acknowledgment after a stay-open run. Empty when idle.
	local flash = scope:Value("")
	local flashValid = scope:Value(true)
	--[[
		Whether the list can scroll further. The list sets these from its
		scroll state and the footer shows a cue for each.
	]]
	local canScrollUp = scope:Value(false)
	local canScrollDown = scope:Value(false)
	local blurEnabled = scope:Value(props.Blur == true)
	local viewport = scope:Value(Vector2.new(1280, 720))
	local entry = scope:Value(nil :: EntryState?)
	local recents = scope:Value({} :: { Registry.Command })

	--[[
		Panel size tracks the viewport (clamped), re-measured when the camera or
		its viewport changes, so it stays usable on a phone or a large monitor.
	]]
	local cameraConnection: RBXScriptConnection? = nil
	local function watchCamera(): ()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = services.Workspace.CurrentCamera :: Camera?
		if camera == nil then
			return
		end
		viewport:set(camera.ViewportSize)
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewport:set((camera :: Camera).ViewportSize)
		end)
	end
	watchCamera()
	table.insert(
		scope,
		services.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	)
	table.insert(scope, function()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
	end)

	--[[
		Stable RowModels per command and option, so the list reuses rows across
		keystrokes. These are plain locals, not fields, because the evaluation
		Computeds below can run during construction (a Spring evaluates its goal
		when created), which is before self exists. The activate closures do
		capture self, but they only run on a click, long after construction.
	]]
	local commandRows: { [Registry.Command]: RowModel } = {}
	local optionRows: { [types.EnumOption]: RowModel } = {}

	local function commandRow(command: Registry.Command): RowModel
		local existing = commandRows[command]
		if existing then
			return existing
		end
		local model: RowModel = {
			key = command,
			icon = command.icon,
			title = command.name,
			description = command.description,
			drillIn = #command.arguments > 0,
			swatch = nil,
			activate = function()
				self:activate(command)
			end,
		}
		commandRows[command] = model
		return model
	end

	--[[
		The option cache empties on every entry change, so Current() is read
		once per entry, never per keystroke.
	]]
	local function optionRow(option: types.EnumOption, arg: types.CommandArgument): RowModel
		local existing = optionRows[option]
		if existing then
			return existing
		end
		local isCurrent = false
		if arg.Current ~= nil then
			-- User code. A throwing getter simply marks nothing.
			local ok, currentValue = pcall(arg.Current)
			isCurrent = ok and currentValue == option.Value
		end
		local model: RowModel = {
			key = option,
			--[[
				The fallback is a small filled dot, a deliberate bullet rather
				than a hollow circle that reads as a missing asset.
			]]
			icon = option.Icon or "circleFill",
			title = option.Label,
			description = "",
			drillIn = false,
			swatch = option.Color,
			checked = isCurrent,
			bullet = option.Icon == nil and option.Color == nil,
			activate = function()
				self:_flowRef():pickOption(option)
			end,
		}
		optionRows[option] = model
		return model
	end

	--[[
		The empty-query browse view. A Recent section leads, then each group
		with members alphabetical inside and groups alphabetical, then the
		ungrouped commands, headed Commands only when named groups exist. A
		recent command appears only under Recent, keeping every RowModel unique.
	]]
	local function groupedEvaluation(use: Use): Evaluation
		local records = use(registry.records)
		local recentList = use(recents)

		local rows: { RowModel } = {}
		local order: { [RowModel]: number } = {}
		local headers: { [number]: string } = {}

		local function append(command: Registry.Command): ()
			local model = commandRow(command)
			table.insert(rows, model)
			order[model] = #rows
		end

		local inRecent: { [Registry.Command]: boolean } = {}
		if #recentList > 0 then
			headers[1] = "Recent"
			for _, command in recentList do
				inRecent[command] = true
				append(command)
			end
		end

		local lowerName: { [Registry.Command]: string } = {}
		local groupNames: { string } = {}
		local groups: { [string]: { Registry.Command } } = {}
		local ungrouped: { Registry.Command } = {}
		for _, command in records do
			if inRecent[command] then
				continue
			end
			lowerName[command] = use(command.name):lower()
			local group = command.group
			if group == nil then
				table.insert(ungrouped, command)
			elseif groups[group] == nil then
				groups[group] = { command }
				table.insert(groupNames, group)
			else
				table.insert(groups[group], command)
			end
		end
		local function byName(a: Registry.Command, b: Registry.Command): boolean
			return lowerName[a] < lowerName[b]
		end

		table.sort(groupNames)
		for _, groupName in groupNames do
			local members = groups[groupName]
			table.sort(members, byName)
			headers[#rows + 1] = groupName
			for _, command in members do
				append(command)
			end
		end
		table.sort(ungrouped, byName)
		if #ungrouped > 0 then
			if #groupNames > 0 then
				headers[#rows + 1] = "Commands"
			end
			for _, command in ungrouped do
				append(command)
			end
		end

		return { rows = rows, order = order, positions = {}, headers = headers }
	end

	local commandEvaluation = scope:Computed(function(use: Use): Evaluation
		local text = use(query)
		-- An empty query is the browse view, recents first and then clusters.
		if text:match("^%s*$") ~= nil then
			return groupedEvaluation(use)
		end
		-- A typed query flattens to the pure ranked list, headerless.
		return project(use(registry.records), text, function(command): matcher.Candidate
			return {
				name = use(command.name),
				description = use(command.description),
				aliases = command.aliases,
			}
		end, commandRow)
	end)

	local optionEvaluation = scope:Computed(function(use: Use): Evaluation
		local current = use(entry)
		if current == nil then
			return EMPTY_EVALUATION
		end
		local options: { types.EnumOption }? = nil
		if current.arg.Type == "enum" then
			options = current.arg.Options
		elseif current.arg.Type == "boolean" then
			options = BOOLEAN_OPTIONS
		end
		if options == nil then
			return EMPTY_EVALUATION
		end

		local text = use(query)
		local isBlank = text:match("^%s*$") ~= nil
		--[[
			A blank boolean filter keeps author order, Yes before No. The
			matcher's empty-query alphabetical order would flip them.
		]]
		if isBlank and current.arg.Type == "boolean" then
			local rows: { RowModel } = {}
			local order: { [RowModel]: number } = {}
			for _, option in options do
				local model = optionRow(option, current.arg)
				table.insert(rows, model)
				order[model] = #rows
			end
			return checkedFirst({
				rows = rows,
				order = order,
				positions = {},
				headers = NO_HEADERS,
			})
		end

		local projected = project(options, text, function(option): matcher.Candidate
			return { name = option.Label, description = "", aliases = option.Aliases or {} }
		end, function(option): RowModel
			return optionRow(option, current.arg)
		end)
		--[[
			On an empty filter the current value leads the list, so a set
			command opens on what it is currently set to.
		]]
		if isBlank then
			return checkedFirst(projected)
		end
		return projected
	end)

	--[[
		Whether the list is showing pick options rather than command results.
		The list snaps its selection pill when this flips, instead of gliding.
	]]
	local isPickMode = scope:Computed(function(use: Use): boolean
		local current = use(entry)
		return current ~= nil and (current.arg.Type == "enum" or current.arg.Type == "boolean")
	end)

	local evaluation = scope:Computed(function(use: Use): Evaluation
		return if use(isPickMode) then use(optionEvaluation) else use(commandEvaluation)
	end)

	local inArguments = scope:Computed(function(use: Use): boolean
		return use(entry) ~= nil
	end)
	--[[
		One reveal spring drives everything argument entry shows, the header
		above the field and the field's own leading-slot crossfade.
	]]
	local revealTarget = scope:Computed(function(use: Use): number
		return if use(inArguments) then 1 else 0
	end)
	local headerReveal = scope:Spring(revealTarget, motion.EntryHeaderSpeed)

	--[[
		The empty state echoes what was searched for, capped so a pasted essay
		cannot flood the label. A blank query falls back to plain mode text.
	]]
	local emptyText = scope:Computed(function(use: Use): string
		local noun = if use(inArguments) then "options" else "commands"
		local text = use(query):match("^%s*(.-)%s*$") or ""
		if text == "" then
			return `No matching {noun}`
		end
		if #text > 24 then
			text = `{text:sub(1, 24)}…`
		end
		return `No {noun} for "{text}"`
	end)
	local showList = scope:Computed(function(use: Use): boolean
		local current = use(entry)
		if current == nil then
			return true
		end
		return current.arg.Type == "enum" or current.arg.Type == "boolean"
	end)
	--[[
		Scalar steps show the current parameter as one standard row in the body,
		so argument entry keeps the same anatomy as search, header, field, rows,
		footer. Exactly one of the two body views is ever visible.
	]]
	local showParameter = scope:Computed(function(use: Use): boolean
		local current = use(entry)
		return current ~= nil and current.arg.Type ~= "enum" and current.arg.Type ~= "boolean"
	end)

	--[[
		The identity of the current view. It changes exactly when the body's
		content is replaced wholesale, search to entry, step to step, pick to
		scalar, entry back to search, and never while one view refines itself,
		typing, filtering, the fold tracking the count. Mode transitions are
		cuts and within-mode changes are glides, so everything that must cut,
		the panel-height springs and the list's pill and tween, keys off this
		one value.
	]]
	local viewKey = scope:Computed(function(use: Use): string
		local current = use(entry)
		if current == nil then
			return "search"
		end
		local kind = if current.arg.Type == "enum" or current.arg.Type == "boolean"
			then "pick"
			else "scalar"
		return `{kind}:{current.index}`
	end)

	--[[
		The context band's text, the last section title at or before the
		selected row, so arrowing or hovering across a cluster boundary swaps
		the label. Empty outside the browse view, which is also how the band
		knows to hide. Filtered search is flat, and picks and scalar entry are
		self-labeled.
	]]
	local sectionLabel = scope:Computed(function(use: Use): string
		if use(inArguments) then
			return ""
		end
		local headers = use(evaluation).headers
		if next(headers) == nil then
			return ""
		end
		local label = ""
		for index = 1, use(selectedIndex) do
			local title = headers[index]
			if title ~= nil then
				label = title
			end
		end
		return label
	end)
	--[[
		The band's height reveal, the same pattern as the entry header. Within
		a mode it glides, browse to filtered as you type, and mode transitions
		snap it below with the other height springs. The label itself swaps
		sharply, only the strip's height ever animates.
	]]
	local bandTarget = scope:Computed(function(use: Use): number
		return if use(sectionLabel) ~= "" then 1 else 0
	end)
	local bandReveal = scope:Spring(bandTarget, motion.EntryHeaderSpeed)
	local footerRun = scope:Computed(function(use: Use): string
		return if use(inArguments) then "next" else "run"
	end)
	local footerClose = scope:Computed(function(use: Use): string
		return if use(inArguments) then "cancel" else "close"
	end)
	--[[
		Where you are out of how many, named by what is shown, commands in
		search, options over a pick, parameters through a scalar form. A
		single-parameter form shows nothing, because 1 of 1 is noise.
	]]
	local footerCount = scope:Computed(function(use: Use): string
		if use(showParameter) then
			local current = use(entry) :: EntryState
			return if current.total > 1 then `{current.index} of {current.total} parameters` else ""
		end
		local total = #use(evaluation).rows
		if total == 0 then
			return ""
		end
		local noun = if use(inArguments) then "options" else "commands"
		return `{use(selectedIndex)} of {total} {noun}`
	end)
	-- The scroll cues follow the same rule, only over a real list.
	local footerScrollUp = scope:Computed(function(use: Use): boolean
		return use(showList) and use(canScrollUp)
	end)
	local footerScrollDown = scope:Computed(function(use: Use): boolean
		return use(showList) and use(canScrollDown)
	end)

	local validity = scope:Computed(function(use: Use): Validity
		local current = use(entry)
		local raw = use(query)
		if current == nil or raw == "" then
			return { valid = false, message = "" }
		end
		--[[
			In a pick mode (enum, boolean) the field filters the option list.
			It is not the value, so it must never read as invalid.
		]]
		if current.arg.Type == "enum" or current.arg.Type == "boolean" then
			return { valid = false, message = "" }
		end
		local checked = arguments.validate(current.arg, raw)
		if checked.ok then
			local display = tostring(checked.value)
			local trimmed = raw:match("^%s*(.-)%s*$") or raw
			return {
				valid = true,
				message = "",
				resolved = if display ~= trimmed then display else nil,
			}
		end
		return { valid = false, message = checked.error }
	end)

	local panelWidth = scope:Computed(function(use: Use): number
		return math.clamp(
			use(viewport).X * tokens.PanelWidthScale,
			tokens.PanelMinWidth,
			tokens.PanelMaxWidth
		)
	end)

	--[[
		The visible list area is capped by the viewport fraction (minus the fixed
		chrome) as well as the row-count maximum, then snapped to a whole number
		of rows so the bottom row is never sliced. N rows span N times the pitch
		minus one gap plus the two paddings. The floor inverts that, adding the
		gap back, to find how many rows fit.
	]]
	local listCap = scope:Computed(function(use: Use): number
		local available = use(viewport).Y * tokens.PanelHeightScale
			- tokens.FieldHeight
			- tokens.SeparatorHeight
			- tokens.FooterHeight
		available = math.clamp(available, tokens.EmptyHeight, tokens.ListMaxHeight)
		local visibleRows = math.max(
			1,
			math.floor((available - tokens.ListPadding * 2 + tokens.RowGap) / tokens.RowPitch)
		)
		return visibleRows * tokens.RowPitch - tokens.RowGap + tokens.ListPadding * 2
	end)
	local listHeightGoal = scope:Computed(function(use: Use): number
		-- The scalar body is exactly one standard row with the shared paddings.
		if use(showParameter) then
			return tokens.RowHeight + tokens.ListPadding * 2
		end
		if not use(showList) then
			return 0
		end
		local currentEvaluation = use(evaluation)
		if #currentEvaluation.rows == 0 then
			return tokens.EmptyHeight
		end
		--[[
			The uniform formula, whole rows only, so the window is flush at
			both edges in every view. N rows span N pitches minus the final
			gap, plus the two paddings.
		]]
		local capContent = use(listCap) - tokens.ListPadding * 2
		local visibleRows = math.max(1, math.floor((capContent + tokens.RowGap) / tokens.RowPitch))
		return math.min(#currentEvaluation.rows, visibleRows) * tokens.RowPitch
			- tokens.RowGap
			+ tokens.ListPadding * 2
	end)
	local listHeight = scope:Spring(listHeightGoal, motion.HeightSpeed)

	--[[
		Mode changes cut. When the view is replaced wholesale the two springs
		that shape the panel's height snap to their new targets in one frame,
		so fresh content never rattles inside a still-moving box. Within a
		mode both keep their glide.
	]]
	scope:Observer(viewKey):onChange(function()
		local goal: number = fusion.peek(listHeightGoal)
		listHeight:setPosition(goal)
		listHeight:setVelocity(0)
		local reveal: number = fusion.peek(revealTarget)
		headerReveal:setPosition(reveal)
		headerReveal:setVelocity(0)
		local band: number = fusion.peek(bandTarget)
		bandReveal:setPosition(band)
		bandReveal:setVelocity(0)
	end)
	local contentHeight = scope:Computed(function(use: Use): number
		local band: number = use(bandReveal)
		return band * tokens.SectionBandHeight + use(listHeight) + tokens.FooterHeight
	end)
	--[[
		The breadcrumb header reveals above the field, so its springing height
		is part of the panel's, keeping the entrance one coordinated growth.
	]]
	local panelHeight = scope:Computed(function(use: Use): number
		return use(headerReveal) * tokens.EntryHeaderHeight
			+ tokens.FieldHeight
			+ tokens.SeparatorHeight
			+ use(contentHeight)
	end)

	--[[
		The entrance, fade, slide, scale and the backdrop frost, all on the one
		open speed and critically damped, so the panel arrives as one motion.
	]]
	local transparency = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(shown) then 0 else 1
		end),
		motion.OpenSpeed
	)
	local offsetY = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(shown) then 0 else motion.SlideOffset
		end),
		motion.OpenSpeed
	)
	local scale = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(shown) then 1 else motion.EntranceScale
		end),
		motion.OpenSpeed
	)
	local blurSize = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(shown) and use(blurEnabled) then tokens.BlurSize else 0
		end),
		motion.OpenSpeed
	)

	self = setmetatable({
		query = query,
		selectedIndex = selectedIndex,
		shown = shown,
		flash = flash,
		flashValid = flashValid,
		canScrollUp = canScrollUp,
		canScrollDown = canScrollDown,
		blurEnabled = blurEnabled,
		viewport = viewport,
		entry = entry,
		recents = recents,

		panelWidth = panelWidth,
		commandEvaluation = commandEvaluation,
		optionEvaluation = optionEvaluation,
		evaluation = evaluation,
		isPickMode = isPickMode,
		inArguments = inArguments,
		headerReveal = headerReveal,
		emptyText = emptyText,
		showList = showList,
		showParameter = showParameter,
		viewKey = viewKey,
		sectionLabel = sectionLabel,
		bandReveal = bandReveal,
		footerRun = footerRun,
		footerClose = footerClose,
		footerCount = footerCount,
		footerScrollUp = footerScrollUp,
		footerScrollDown = footerScrollDown,
		validity = validity,
		listCap = listCap,
		listHeight = listHeight,
		contentHeight = contentHeight,
		panelHeight = panelHeight,
		transparency = transparency,
		offsetY = offsetY,
		scale = scale,
		blurSize = blurSize,

		_flow = nil,
		_textBox = nil,
		_follower = nil,
		_flashToken = 0,
		_destroyed = false,
		_previewArg = nil,
		_previewRestore = nil,
		_previewLast = PREVIEW_NONE,
		_previewCommitted = false,
	}, Store) :: Store

	--[[
		Cleanup runs this when the palette is destroyed. Pending task.delay and
		task.defer callbacks check the flag and stand down instead of touching
		destroyed Values or a destroyed TextBox. An uncommitted preview restores
		its baseline on the way out.
	]]
	table.insert(scope, function()
		self._destroyed = true
		if not self._previewCommitted and self._previewRestore ~= nil then
			self._previewRestore()
		end
	end)

	-- Typing re-anchors the selection. A shrinking result set clamps it in range.
	scope:Observer(query):onChange(function()
		selectedIndex:set(1)
	end)
	scope:Observer(evaluation):onChange(function()
		local count = #fusion.peek(evaluation).rows
		if fusion.peek(selectedIndex) > count then
			selectedIndex:set(math.max(1, count))
		end
	end)

	--[[
		Cache hygiene. A removed command's row model (and its closures) must not
		outlive it, in the cache or in recents. Stale option rows go with their
		entry, which also makes Current() re-read on the next entry.
	]]
	scope:Observer(registry.records):onChange(function()
		local live: { [Registry.Command]: boolean } = {}
		for _, record in fusion.peek(registry.records) do
			live[record] = true
		end
		for key in commandRows do
			if not live[key] then
				commandRows[key] = nil
			end
		end
		local kept = {}
		for _, record in fusion.peek(recents) do
			if live[record] then
				table.insert(kept, record)
			end
		end
		recents:set(kept)
	end)
	scope:Observer(entry):onChange(function()
		table.clear(optionRows)
		self:_syncPreview()
	end)

	--[[
		Live preview follows the highlighted pick option. Deduplicated against
		the last previewed value, so hovering in place or reordering cannot
		re-fire user code with the same value.
	]]
	local function previewSelection(): ()
		local currentArg = self._previewArg
		if currentArg == nil or currentArg.Preview == nil then
			return
		end
		if not fusion.peek(isPickMode) then
			return
		end
		local row = fusion.peek(evaluation).rows[fusion.peek(selectedIndex)]
		if row == nil then
			return
		end
		local option = row.key :: types.EnumOption
		if option.Value == self._previewLast then
			return
		end
		self._previewLast = option.Value
		pcall(currentArg.Preview :: (unknown) -> (), option.Value)
	end
	--[[
		Preview is user code, so it comes off the navigation path. The deferred
		call reads the selection as it stands at the end of the frame, so a
		burst of arrow steps fires once for the final row, and the value-level
		dedupe above absorbs the extra wakeups.
	]]
	local function deferPreview(): ()
		task.defer(function()
			if self._destroyed then
				return
			end
			previewSelection()
		end)
	end
	scope:Observer(selectedIndex):onChange(deferPreview)
	scope:Observer(evaluation):onChange(deferPreview)

	return self
end

--[[
	Wires the argument flow after construction. The flow cannot be constructed
	first because Flow requires the store. Every flow-driven action asserts
	this happened.
]]
function Store.attachFlow(self: Store, flow: FlowLike): ()
	self._flow = flow
end

--[[
	Wires the list's keep-visible scroll after construction, the same pattern
	as attachFlow. Selection changes never scroll by themselves. The keyboard
	movers request the follow explicitly, so hover selection can never start
	the hover, scroll, hover feedback loop.
]]
function Store.bindFollower(self: Store, follow: () -> ()): ()
	self._follower = follow
end

function Store._requestFollow(self: Store): ()
	local follow = self._follower
	if follow ~= nil then
		follow()
	end
end

function Store._flowRef(self: Store): FlowLike
	return assert(self._flow, "Store used before attachFlow")
end

--[[
	Preview lifecycle, run on every entry change. Entering a pick whose argument
	has a Preview arms a session, seeding the dedupe with the entry-time value
	so arming alone fires nothing. Leaving that argument without a commit
	restores the entry-time value.
]]
function Store._syncPreview(self: Store): ()
	local current = fusion.peek(self.entry)
	local currentArg = if current ~= nil then current.arg else nil
	if self._previewArg ~= nil and self._previewArg ~= currentArg then
		if not self._previewCommitted and self._previewRestore ~= nil then
			self._previewRestore()
		end
		self._previewArg = nil
		self._previewRestore = nil
	end
	if currentArg ~= nil and currentArg.Preview ~= nil and self._previewArg == nil then
		self._previewArg = currentArg
		self._previewCommitted = false
		self._previewLast = PREVIEW_NONE
		local getCurrent = currentArg.Current
		local preview = currentArg.Preview
		if getCurrent ~= nil and preview ~= nil then
			-- User code. A throwing getter simply arms without a baseline.
			local ok, baseline = pcall(getCurrent)
			if ok then
				self._previewLast = baseline
				self._previewRestore = function()
					pcall(preview, baseline)
				end
			end
		end
	end
end

-- Flow reports a committed pick, so leaving the argument keeps the new value.
function Store.notePickCommitted(self: Store): ()
	self._previewCommitted = true
end

--[[
	The field region hands its TextBox here so clear, refocus and release can
	reach it.
]]
function Store.bindField(self: Store, box: TextBox): ()
	self._textBox = box
end

function Store.clearField(self: Store): ()
	self.query:set("")
	if self._textBox then
		self._textBox.Text = ""
	end
end

-- Used by Destroy, which skips the animated hide entirely.
function Store.releaseFocus(self: Store): ()
	if self._textBox then
		self._textBox:ReleaseFocus()
	end
end

--[[
	Recapture keyboard focus on the field. Used on open, on entering argument
	mode, after a stay-open run, and on every mid-flow path, so the next input
	starts immediately. Synchronous when the field already exists and the
	palette is shown, so no frame of keyboard input is dead, and deferred only
	as the fallback for the not-yet-built field on first open. With selectAll
	the text is selected after the capture, so a correction replaces the bad
	input instead of appending to it.
]]
function Store.refocus(self: Store, selectAll: boolean?): ()
	local function capture(): ()
		local box = self._textBox
		if fusion.peek(self.shown) and box then
			box:CaptureFocus()
			--[[
				SelectionStart and CursorPosition are the TextBox selection
				API, set after the capture so the capture cannot reset them.
			]]
			if selectAll == true and box.Text ~= "" then
				box.SelectionStart = 1
				box.CursorPosition = #box.Text + 1
			end
		end
	end
	if self._textBox ~= nil and fusion.peek(self.shown) then
		capture()
		return
	end
	task.defer(function()
		if self._destroyed then
			return
		end
		capture()
	end)
end

function Store.run(self: Store, command: Registry.Command, values: { unknown }, count: number): ()
	--[[
		Deferred, not spawned. task.spawn would run the callback synchronously
		until its first yield, making a slow command block the clear, refocus
		and flash below from even rendering. Deferring lets the UI settle this
		frame and runs user code on the next resumption. The acknowledgment
		follows the callback, so a throwing command reads as failed rather than
		ran. The callback may yield or the palette may die while it runs, so
		everything after it checks the destroyed flag, and the name is captured
		up front in case the command's Values die too. The token guards rapid
		runs so an earlier timeout cannot clear a later message.
	]]
	local commandName = fusion.peek(command.name)
	task.defer(function()
		local ok = xpcall(function()
			command.callback(table.unpack(values, 1, count))
		end, function(err)
			warn(`[VantaUI] command "{commandName}" errored: {err}`)
		end)
		if self._destroyed or command.closeAfter then
			return
		end
		self.flash:set(commandName)
		self.flashValid:set(ok)
		self._flashToken += 1
		local token = self._flashToken
		task.delay(motion.FlashDuration, function()
			if self._destroyed then
				return
			end
			if token == self._flashToken then
				self.flash:set("")
			end
		end)
	end)

	self:_recordRecent(command)

	--[[
		Running keeps the palette open by default. Clear, reset to the top and
		refocus, so the next command starts clean. CloseAfter opts into
		dismissing instead.
	]]
	if command.closeAfter then
		self:hide()
		return
	end
	self:clearField()
	self.selectedIndex:set(1)
	self:refocus()
end

-- Session-only memory of the last few run commands, newest first, deduplicated.
function Store._recordRecent(self: Store, command: Registry.Command): ()
	local updated = table.clone(fusion.peek(self.recents))
	local existing = table.find(updated, command)
	if existing then
		table.remove(updated, existing)
	end
	table.insert(updated, 1, command)
	while #updated > MAX_RECENTS do
		table.remove(updated)
	end
	self.recents:set(updated)
end

function Store.activate(self: Store, command: Registry.Command): ()
	if #command.arguments == 0 then
		self:run(command, {}, 0)
	else
		self:_flowRef():begin(command)
	end
end

function Store.moveSelection(self: Store, delta: number): ()
	-- The parameter row is not navigable, so the arrows are inert during a scalar step.
	if fusion.peek(self.showParameter) then
		return
	end
	local count = #fusion.peek(self.evaluation).rows
	if count == 0 then
		return
	end
	-- Wrap top to bottom, so you can cycle past either end instead of stopping.
	local next = (fusion.peek(self.selectedIndex) - 1 + delta) % count + 1
	self.selectedIndex:set(next)
	self:_requestFollow()
end

--[[
	Wrap-free jumps for Home, End and the page keys. Pages move by the visible
	row count, clamped at the ends rather than cycling.
]]
function Store.jumpSelection(self: Store, action: "first" | "last" | "pageUp" | "pageDown"): ()
	-- The parameter row is not navigable, so the jump keys are inert during a scalar step.
	if fusion.peek(self.showParameter) then
		return
	end
	local count = #fusion.peek(self.evaluation).rows
	if count == 0 then
		return
	end
	local cap: number = fusion.peek(self.listCap)
	local pageSize =
		math.max(1, math.floor((cap - tokens.ListPadding * 2 + tokens.RowGap) / tokens.RowPitch))
	local target: number
	if action == "first" then
		target = 1
	elseif action == "last" then
		target = count
	elseif action == "pageUp" then
		target = math.max(1, fusion.peek(self.selectedIndex) - pageSize)
	else
		target = math.min(count, fusion.peek(self.selectedIndex) + pageSize)
	end
	self.selectedIndex:set(target)
	self:_requestFollow()
end

--[[
	A scalar parameter commits the field. A command row or a pick option (enum,
	boolean) runs through its own activate closure.
]]
function Store.onConfirm(self: Store): ()
	local current = fusion.peek(self.entry)
	if current ~= nil and current.arg.Type ~= "enum" and current.arg.Type ~= "boolean" then
		self:_flowRef():submit(fusion.peek(self.query))
		return
	end
	local row = fusion.peek(self.evaluation).rows[fusion.peek(self.selectedIndex)]
	if row ~= nil then
		row.activate()
	end
end

--[[
	The explicit back affordance (the breadcrumb chevron). It steps back a
	parameter regardless of field content, since the intent is unambiguous.
	Backspace is never wired to this. Overloading it raced the field's async
	text update.
]]
function Store.stepBack(self: Store): ()
	local flow = self:_flowRef()
	if flow:isActive() then
		flow:back()
	end
end

--[[
	Esc peels one layer per press. Typed text clears first, then argument mode
	exits back to search, and only then does the palette hide.
]]
function Store.onDismiss(self: Store): ()
	if fusion.peek(self.query) ~= "" then
		self:clearField()
		self:refocus()
		return
	end
	local flow = self:_flowRef()
	if flow:isActive() then
		flow:exit()
		self:refocus()
	else
		self:hide()
	end
end

function Store.show(self: Store): ()
	if fusion.peek(self.shown) then
		return
	end
	self.shown:set(true)
	self:refocus()
end

function Store.hide(self: Store): ()
	if not fusion.peek(self.shown) then
		return
	end
	self.shown:set(false)
	self.flash:set("")
	self:releaseFocus()
	--[[
		Hold the state through the fade, then reset once settled closed, so the
		panel never flashes its full list on the way out.
	]]
	task.delay(motion.ResetDelay, function()
		if self._destroyed then
			return
		end
		if not fusion.peek(self.shown) then
			self:_flowRef():exit()
			self.selectedIndex:set(1)
			self:clearField()
		end
	end)
end

function Store.toggle(self: Store): ()
	if fusion.peek(self.shown) then
		self:hide()
	else
		self:show()
	end
end

return table.freeze(Store)
