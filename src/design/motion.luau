--!strict
--!optimize 2

--[[
	motion

	Every animation timing, the spring speed and damping pairs and the deferred
	delays. Motion is sharp. Every spring is critically damped (damping of 1 or
	more) at high speed, so nothing overshoots or bounces, ever. There is
	deliberately no under-damping anywhere in this file.
]]

return table.freeze({
	--[[
		Panel show/hide. Fade, slide, scale and the backdrop frost all ride
		this one speed, so the panel arrives as one motion, not staggered
		channels.
	]]
	OpenSpeed = 44,
	SlideOffset = 12,
	--[[
		The panel settles from this scale to 1 on entrance, on the same spring,
		so the whole entrance reads as one coordinated motion.
	]]
	EntranceScale = 0.985,

	-- Content fades, the scroll indicator and the mode-cut crossfades.
	FadeSpeed = 44,
	FadeDamping = 1,

	--[[
		Within-mode list height changes, the fold tracking the match count as
		you type. Mode changes snap this spring, so only typing rides it, and
		it is fast enough to track keystrokes rather than trail them.
	]]
	HeightSpeed = 50,

	-- Selection tint (the per-row text/tile crossfade) settling into the row.
	SelectionSpeed = 44,

	--[[
		The single selection pill tracking the selected row, quick and
		critically damped, so it snaps between rows with no bounce as you
		arrow through fast.
	]]
	SelectionSlideSpeed = 50,
	SelectionSlideDamping = 1,

	-- Selection scrolled/snapped into view over this time, rather than jumped.
	ScrollTweenTime = 0.1,
	-- How long the scroll indicator stays after a step settles, before fading.
	IndicatorLinger = 0.2,

	-- Held arrow keys start repeating after the delay, then step per interval.
	RepeatDelay = 0.35,
	RepeatInterval = 0.05,

	-- Row press: the icon tile dips to this scale and springs straight back.
	PressScale = 0.97,
	PressSpeed = 50,
	PressDamping = 1,

	--[[
		The argument-entry reveal spring. Mode changes snap it, so it only ever
		glides if a future within-mode reveal change appears. The header and
		field content soften mode cuts on FadeSpeed instead.
	]]
	EntryHeaderSpeed = 42,

	--[[
		Hold the query and selection through the fade so the panel does not
		flash its full state on the way out, cleared once it settles closed.
	]]
	ResetDelay = 0.18,

	--[[
		How long the "Ran X" acknowledgment shows in the footer after a command
		runs and the palette stays open.
	]]
	FlashDuration = 1.4,
})
