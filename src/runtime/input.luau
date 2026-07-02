--!strict
--!optimize 2

--[[
	input

	Keyboard and shortcut handling behind a callback interface. Backspace is
	deliberately not bound to step-back. It must only edit the field, because
	overloading it raced the field's async text update. Back lives on the
	breadcrumb chevron and Esc cancels. Click-outside dismissal is the scrim's
	job through native hit-testing, never coordinate math here.
]]

local motion = require("@design/motion")
local services = require("@runtime/services")

-- The Fusion scope's task list, used only to register connections for cleanup.
type CleanupTasks = { unknown }

-- Jump targets for the non-cycling navigation keys.
export type JumpAction = "first" | "last" | "pageUp" | "pageDown"

export type Config = {
	shortcut: { Enum.KeyCode },
	isOpen: () -> boolean,
	onToggle: () -> (),
	onNavigate: (delta: number) -> (),
	onJump: (action: JumpAction) -> (),
	onConfirm: () -> (),
	onDismiss: () -> (),
}

local JUMP_KEYS: { [Enum.KeyCode]: JumpAction } = {
	[Enum.KeyCode.Home] = "first",
	[Enum.KeyCode.End] = "last",
	[Enum.KeyCode.PageUp] = "pageUp",
	[Enum.KeyCode.PageDown] = "pageDown",
}

local input = {}

--[[
	The toggle respects already-consumed input. The in-panel navigation keys
	below deliberately do not, so they keep working while the palette's own
	field is focused. Held arrow keys repeat, driven by Heartbeat, cancelled on
	release or close.
]]
function input.attach(tasks: CleanupTasks, config: Config): ()
	local userInput = services.UserInputService

	local heldDelta: number? = nil
	local heldSince = 0
	local lastRepeat = 0

	local function shortcutHeld(): boolean
		for _, key in config.shortcut do
			if not userInput:IsKeyDown(key) then
				return false
			end
		end
		return true
	end

	table.insert(
		tasks,
		userInput.InputBegan:Connect(function(inputObject: InputObject, gameProcessed: boolean)
			local keyCode = inputObject.KeyCode
			if
				not gameProcessed
				and keyCode ~= Enum.KeyCode.Unknown
				and table.find(config.shortcut, keyCode)
				and shortcutHeld()
			then
				config.onToggle()
				return
			end

			if not config.isOpen() then
				return
			end

			if keyCode == Enum.KeyCode.Down or keyCode == Enum.KeyCode.Up then
				local delta = if keyCode == Enum.KeyCode.Down then 1 else -1
				config.onNavigate(delta)
				heldDelta = delta
				heldSince = os.clock()
				lastRepeat = heldSince
			elseif JUMP_KEYS[keyCode] ~= nil then
				config.onJump(JUMP_KEYS[keyCode])
			elseif keyCode == Enum.KeyCode.Escape then
				config.onDismiss()
			elseif
				keyCode == Enum.KeyCode.Return
				or keyCode == Enum.KeyCode.KeypadEnter
				or keyCode == Enum.KeyCode.Tab
			then
				config.onConfirm()
			end
		end)
	)

	table.insert(
		tasks,
		userInput.InputEnded:Connect(function(inputObject: InputObject)
			local keyCode = inputObject.KeyCode
			if keyCode == Enum.KeyCode.Down or keyCode == Enum.KeyCode.Up then
				heldDelta = nil
			end
		end)
	)

	table.insert(
		tasks,
		services.RunService.Heartbeat:Connect(function()
			if heldDelta == nil then
				return
			end
			if not config.isOpen() then
				heldDelta = nil
				return
			end
			local now = os.clock()
			if now - heldSince < motion.RepeatDelay then
				return
			end
			if now - lastRepeat >= motion.RepeatInterval then
				lastRepeat = now
				config.onNavigate(heldDelta)
			end
		end)
	)
end

return table.freeze(input)
