--!strict
--!optimize 2

--[[
	protect

	Executor-safe UI parenting. It hides the ScreenGui from common detection and
	drops it in the safest container, degrading to PlayerGui on a vanilla
	client. This is the one file that reaches executor globals, so their untyped
	any is quarantined here, and it is the documented second game:GetService
	entry, because CoreGui must be fetched inside a pcall at the point of use.
]]

local services = require("@runtime/services")

--[[
	Executor globals are read through the function environment so this file
	stays warning-free under strict mode and simply resolves to nil when no
	executor is present.
]]
local environment = getfenv() :: { [string]: any }

local cloneReference = environment.cloneref
local getHiddenUi = environment.gethui
local protectGui = environment.protect_gui or environment.protectgui
local setIdentity = environment.setthreadidentity or environment.setidentity

local protect = {}

local function safeCall(callback: any, ...: any): ()
	if typeof(callback) == "function" then
		pcall(callback, ...)
	end
end

--[[
	Order of preference for the parent. The host's hidden UI container first,
	then a dereferenced CoreGui, then PlayerGui.
]]
function protect.take(gui: ScreenGui): ()
	safeCall(setIdentity, 8)
	safeCall(protectGui, gui)

	local parent: Instance? = nil

	if typeof(getHiddenUi) == "function" then
		local ok, hidden = pcall(getHiddenUi)
		if ok and typeof(hidden) == "Instance" then
			parent = hidden
		end
	end

	if parent == nil then
		local ok, coreGui = pcall(function(): Instance
			return game:GetService("CoreGui")
		end)
		if ok then
			parent = if typeof(cloneReference) == "function"
				then cloneReference(coreGui)
				else coreGui
		end
	end

	if parent == nil then
		local player = services.Players.LocalPlayer
		parent = player and player:FindFirstChildOfClass("PlayerGui")
	end

	gui.Parent = parent
end

return table.freeze(protect)
