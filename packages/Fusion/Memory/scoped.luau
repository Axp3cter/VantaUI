--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Creates cleanup tables with access to constructors as methods.
]]
local Types = require("@packages/Fusion/Types")
local ExternalDebug = require("@packages/Fusion/ExternalDebug")
local merge = require("@packages/Fusion/Utility/merge")
local scopePool = require("@packages/Fusion/Memory/scopePool")

local function scoped(
	...: {[unknown]: unknown}
): any
	local scope = setmetatable(
		scopePool.reuseAny() :: any or {},
		{__index = merge(false, {}, ...)}
	) :: any
	ExternalDebug.trackScope(scope)
	return scope
end

return (scoped :: any) :: Types.ScopedConstructor