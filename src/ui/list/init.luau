--!strict
--!optimize 2

--[[
	list

	The scrolling results and the sliding selection pill on one uniform row
	grid. Every formula is the whole-row math, so every rest in every view
	lands with whole rows flush at both edges, top and bottom, and no rest can
	show a partial row, by construction. Rests are re-derived from the real
	canvas as each wheel notch lands, so no input sequence can drift off the
	grid. Sections are the context band's job above the list, the flow renders
	no markers for them. It owns the single selection pill, so exactly one
	highlight ever exists. Native scrolling is off and the panel forwards
	wheel input through onStepperReady.
]]

local EmptyState = require("@ui/list/EmptyState")
local Row = require("@ui/list/Row")
local Store = require("@palette/Store")
local fusion = require("@runtime/fusion")
local kit = require("@ui/kit")
local motion = require("@design/motion")
local services = require("@runtime/services")
local tokens = require("@design/tokens")

local Children = fusion.Children

type Scope = fusion.Scope
type Use = fusion.Use

export type Props = {
	evaluation: fusion.UsedAs<Store.Evaluation>,
	selectedIndex: fusion.Value<number>,
	--[[
		The store's view identity. It changes exactly when the body's content
		is replaced wholesale, and the list cuts with it, cancelling any
		in-flight tween and snapping the pill.
	]]
	viewKey: fusion.UsedAs<string>,
	listHeight: fusion.UsedAs<number>,
	layoutOrder: number,
	emptyText: fusion.UsedAs<string>,
	visible: fusion.UsedAs<boolean>,
	-- Set from the scroll state so the footer can cue "more above/below".
	canScrollUp: fusion.Value<boolean>,
	canScrollDown: fusion.Value<boolean>,
	--[[
		Receives the list's step function at build time, so the shell can drive
		the list from wheel input caught anywhere over the panel.
	]]
	onStepperReady: (step: (direction: number) -> ()) -> (),
	--[[
		Receives the keep-visible follow at build time. Only the keyboard paths
		call it, because the pointer never scrolls the list, so hovering a
		partially visible row can never start a scroll that slides more rows
		under the cursor.
	]]
	onFollowReady: (follow: () -> ()) -> (),
}

-- Canvas-relative top of a row on the uniform grid.
local function rowTop(index: number): number
	return (index - 1) * tokens.RowPitch
end

return function(scope: Scope, props: Props): Instance
	local tree = kit.useTheme()

	local rows = scope:Computed(function(use: Use): { Store.RowModel }
		return use(props.evaluation).rows
	end)
	local isEmpty = scope:Computed(function(use: Use): boolean
		return #use(rows) == 0
	end)

	-- The sliding selection pill's top, springing between rows on the row grid.
	local highlightY = scope:Spring(
		scope:Computed(function(use: Use): number
			return rowTop(use(props.selectedIndex)) + tokens.SelectionPadY
		end),
		motion.SelectionSlideSpeed,
		motion.SelectionSlideDamping
	)

	--[[
		The pill snaps with the pointer and with mode changes, and glides for
		keyboard motion. This is the shared snap path.
	]]
	local function snapPill(): ()
		local target = rowTop(fusion.peek(props.selectedIndex)) + tokens.SelectionPadY
		highlightY:setPosition(target)
		highlightY:setVelocity(0)
	end

	--[[
		True while a scroll tween is running, declared up here because the
		hover path below must consult it. Micro mouse movements while rows
		slide under the cursor must not select, or every scroll would fight a
		stream of hover selections. Hovering resumes on the first MouseMoved
		after the tween settles.
	]]
	local tweenActive = false

	--[[
		Pointer hover selects and snaps the pill, and does nothing else, the
		pointer never scrolls the list. The cursor is its own animation, so the
		pill must sit under it instantly, where a spring would read as lag.
		Keyboard selection keeps the tracked glide. MouseMoved streams while
		the pointer rests on a row, so an already-selected rank returns before
		touching any state, otherwise every pixel of pointer motion would
		restart the pill and the hover tint mid-animation.
	]]
	local function hoverSelect(rank: number): ()
		if tweenActive then
			return
		end
		if fusion.peek(props.selectedIndex) == rank then
			return
		end
		props.selectedIndex:set(rank)
		snapPill()
	end

	local highlight = scope:New("Frame")({
		Name = "Selection",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = scope:Computed(function(use: Use): UDim2
			return UDim2.new(0.5, 0, 0, use(highlightY))
		end),
		Size = UDim2.new(
			1,
			-tokens.SelectionPadX * 2,
			0,
			tokens.RowHeight - tokens.SelectionPadY * 2
		),
		ZIndex = 1,
		BorderSizePixel = 0,
		BackgroundColor3 = tree.Selection.Color,
		BackgroundTransparency = tree.Selection.Alpha,
		Visible = scope:Computed(function(use: Use): boolean
			return not use(isEmpty)
		end),

		[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, tokens.RowCorner) }),
	})

	local rowsHolder = scope:New("Frame")({
		Name = "Rows",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		BackgroundTransparency = 1,

		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, tokens.RowGap),
			}),

			--[[
				Later evaluations construct new rows outside the palette's
				theme during() window, so each build re-enters the context
				with the tree captured above.
			]]
			scope:ForValues(rows, function(_, rowScope: Scope, model: Store.RowModel): Instance
				return kit.theme:is(tree):during(function(): Instance
					return Row(rowScope, {
						model = model,
						evaluation = props.evaluation,
						selectedIndex = props.selectedIndex,
						onHover = hoverSelect,
					})
				end)
			end),
		} :: { fusion.Child },
	})

	--[[
		Live scroll geometry, published by updateCues for the indicator to
		derive from, and whether the canvas is currently stepping. The indicator
		only shows while the canvas moves. There are no edge fades, ever.
	]]
	local canvasY = scope:Value(0)
	local canvasTravel = scope:Value(0)
	local windowHeight = scope:Value(0)
	local isScrolling = scope:Value(false)
	local scrollToken = 0

	--[[
		Flipped by scope cleanup so the indicator timeout below cannot touch a
		destroyed Value if the palette dies within a step of a scroll.
	]]
	local destroyed = false
	table.insert(scope, function()
		destroyed = true
	end)

	--[[
		Scroll control, forward-declared so the step function defined below can
		reach the scroller. tweenTo is the single place the canvas moves.
	]]
	local scroller: ScrollingFrame
	local scrollTween: Tween? = nil

	local function tweenTo(target: number): ()
		if scrollTween then
			scrollTween:Cancel()
		end
		local tween = services.TweenService:Create(
			scroller,
			TweenInfo.new(motion.ScrollTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CanvasPosition = Vector2.new(0, math.max(0, target)) }
		)
		scrollTween = tween
		tweenActive = true
		--[[
			Completed fires on natural finish and on Cancel alike, so a tween
			superseded by a newer one must not clear the newer one's flag. The
			identity check makes only the current tween's ending count.
		]]
		tween.Completed:Once(function()
			if scrollTween == tween then
				tweenActive = false
			end
		end)
		tween:Play()
		--[[
			Wake the indicator for the step. The token guards rapid steps so an
			earlier timeout cannot hide it mid-motion.
		]]
		isScrolling:set(true)
		scrollToken += 1
		local token = scrollToken
		task.delay(motion.ScrollTweenTime + motion.IndicatorLinger, function()
			if destroyed then
				return
			end
			if token == scrollToken then
				isScrolling:set(false)
			end
		end)
	end

	--[[
		Rests are re-derived from the real canvas at the moment each notch
		lands, never remembered between gestures. A stored index desyncs the
		moment anything else moves or clamps the canvas, a mode cut cancelling
		a tween mid-flight, the engine clamping a target past the true travel,
		and then wheel notches spend themselves against phantom positions. The
		nearest-rest rounding keeps rapid notches accumulating, since by the
		next notch the canvas has already progressed toward the previous
		target, and every tween lands on index times the pitch, so no input
		sequence can park the canvas off the grid. The deepest rest is the
		row count minus the visible rows, which puts the last row's bottom
		flush.
	]]
	local function visibleRowCount(): number
		local window = scroller.AbsoluteWindowSize.Y
		return math.max(1, math.floor((window + tokens.RowGap + 0.5) / tokens.RowPitch))
	end

	local function restTo(index: number): ()
		local count = #fusion.peek(props.evaluation).rows
		local deepest = math.max(0, count - visibleRowCount())
		local target = math.clamp(index, 0, deepest) * tokens.RowPitch
		if math.abs(target - scroller.CanvasPosition.Y) > 0.5 then
			tweenTo(target)
		end
	end

	local function stepBy(direction: number): ()
		local current = math.round(scroller.CanvasPosition.Y / tokens.RowPitch)
		restTo(current + direction)
	end

	scroller = scope:New("ScrollingFrame")({
		Name = "Scroller",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		--[[
			Native wheel scroll is off. The panel catches the wheel anywhere
			over itself and drives stepBy through onStepperReady, so there is
			exactly one wheel handler and no double stepping over the list.
		]]
		ScrollingEnabled = false,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,

		[Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, tokens.ListInset),
				PaddingRight = UDim.new(0, tokens.ListInset),
			}),
			highlight,
			rowsHolder,
		} :: { fusion.Child },
	}) :: ScrollingFrame

	--[[
		Keep the selected row visible. Scrolling up lands on the row's own
		top and scrolling down lands the row flush with the window bottom. On
		the uniform grid both targets are exact row boundaries, so they route
		through restTo. This is not an observer on the selection, because
		hover selects too and the pointer never scrolls the list. Only the
		keyboard paths call it, through the store, after they move the
		selection.
	]]
	local function followSelection(): ()
		local index = fusion.peek(props.selectedIndex)
		local top = rowTop(index)
		local bottom = top + tokens.RowHeight
		local viewTop = scroller.CanvasPosition.Y
		local window = scroller.AbsoluteWindowSize.Y

		if top < viewTop then
			restTo(index - 1)
		elseif bottom > viewTop + window then
			restTo(math.round((bottom - window) / tokens.RowPitch))
		end
	end

	--[[
		A new result set starts at the top. When the evaluation changes, whether
		from a keystroke, a cleared query, or the switch to options, the canvas
		snaps home rather than travelling, and the pill cuts to the new
		selection. Typing cuts, arrow keys glide, the pointer snaps, one rule
		for the three inputs. The pill snap is deferred so it reads the
		selection after the store's own reset observer has re-anchored it.
	]]
	scope:Observer(props.evaluation):onChange(function()
		if scrollTween then
			scrollTween:Cancel()
			scrollTween = nil
		end
		-- The snap is instantaneous, so no tween is in flight after it.
		tweenActive = false
		scroller.CanvasPosition = Vector2.zero
		task.defer(function()
			if destroyed then
				return
			end
			snapPill()
		end)
	end)

	--[[
		A mode change replaces the entire list, so any in-flight scroll motion
		is cancelled before the new content shows and the pill must not glide
		from its old position across unrelated rows.
	]]
	scope:Observer(props.viewKey):onChange(function()
		if scrollTween then
			scrollTween:Cancel()
			scrollTween = nil
		end
		tweenActive = false
		snapPill()
	end)

	--[[
		Publish whether there are rows off the fold, up and down, from the live
		scroll state (the footer readout cues "more this way"), plus the raw
		geometry the scroll indicator derives its size and position from.
	]]
	local function updateCues(): ()
		local window = scroller.AbsoluteWindowSize.Y
		local maxY = math.max(0, scroller.AbsoluteCanvasSize.Y - window)
		local y = scroller.CanvasPosition.Y
		props.canScrollUp:set(y > 1)
		props.canScrollDown:set(y < maxY - 1)
		canvasY:set(y)
		canvasTravel:set(maxY)
		windowHeight:set(window)
	end
	table.insert(scope, scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(updateCues))
	table.insert(scope, scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateCues))
	table.insert(scope, scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateCues))
	updateCues()
	props.onStepperReady(stepBy)
	props.onFollowReady(followSelection)

	--[[
		The scroll indicator, a 2px rounded bar at the right edge, sized by the
		visible fraction and placed by the scroll fraction. The window height is
		fixed per view, so its length is constant while scrolling. It exists
		only while the canvas is stepping, fading on the sharp fade spring, and
		it is never a shadowy edge fade.
	]]
	local indicatorFade = scope:Spring(
		scope:Computed(function(use: Use): number
			return if use(isScrolling) and use(canvasTravel) > 1 then 0 else 1
		end),
		motion.FadeSpeed,
		motion.FadeDamping
	)
	local indicator = scope:New("Frame")({
		Name = "ScrollIndicator",
		AnchorPoint = Vector2.new(1, 0),
		Position = scope:Computed(function(use: Use): UDim2
			local travel: number = use(canvasTravel)
			local window: number = use(windowHeight)
			local barHeight = math.max(
				tokens.ScrollIndicatorMinHeight,
				if window + travel > 0 then window * window / (window + travel) else 0
			)
			local fraction = if travel > 0 then math.clamp(use(canvasY) / travel, 0, 1) else 0
			local offset = fraction * (window - barHeight)
			return UDim2.new(1, -tokens.ScrollIndicatorInset, 0, offset)
		end),
		Size = scope:Computed(function(use: Use): UDim2
			local travel: number = use(canvasTravel)
			local window: number = use(windowHeight)
			local barHeight = math.max(
				tokens.ScrollIndicatorMinHeight,
				if window + travel > 0 then window * window / (window + travel) else 0
			)
			return UDim2.fromOffset(tokens.ScrollIndicatorThickness, barHeight)
		end),
		ZIndex = 3,
		BorderSizePixel = 0,
		BackgroundColor3 = tree.Text.Tertiary.Color,
		BackgroundTransparency = indicatorFade,
		Visible = scope:Computed(function(use: Use): boolean
			return use(canvasTravel) > 1
		end),

		[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
	})

	return scope:New("Frame")({
		Name = "List",
		Size = scope:Computed(function(use: Use): UDim2
			return UDim2.new(1, 0, 0, use(props.listHeight))
		end),
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		Visible = props.visible,

		[Children] = {
			--[[
				Top and bottom breathing lives here, outside the scroller, so the
				canvas starts at row 1 and whole-row stepping stays exact.
			]]
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, tokens.ListPadding),
				PaddingBottom = UDim.new(0, tokens.ListPadding),
			}),
			scroller,
			indicator,
			EmptyState(scope, {
				text = props.emptyText,
				visible = isEmpty,
			}),
		} :: { fusion.Child },
	})
end
