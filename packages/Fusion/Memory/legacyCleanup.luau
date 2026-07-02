--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler
local Types = require("@packages/Fusion/Types")
local External = require("@packages/Fusion/External")
local doCleanup = require("@packages/Fusion/Memory/doCleanup")

local function legacyCleanup(
	value: Types.Task
)
	External.logWarn("cleanupWasRenamed")
	return doCleanup(value)
end

return legacyCleanup