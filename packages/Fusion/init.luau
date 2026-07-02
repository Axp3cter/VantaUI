--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler
--[[
	The entry point for the Fusion library.
]]

local Types = require("@packages/Fusion/Types")
local External = require("@packages/Fusion/External")

type Fusion = Types.Fusion

export type Animatable = Types.Animatable
export type UsedAs<T> = Types.UsedAs<T>
export type Child = Types.Child
export type Computed<T> = Types.Computed<T>
export type Contextual<T> = Types.Contextual<T>
export type GraphObject = Types.GraphObject
export type For<KO, VO> = Types.For<KO, VO>
export type Observer = Types.Observer
export type PropertyTable = Types.PropertyTable
export type Scope<Constructors = Fusion> = Types.Scope<Constructors>
export type ScopedObject = Types.ScopedObject
export type SpecialKey = Types.SpecialKey
export type Spring<T> = Types.Spring<T>
export type StateObject<T> = Types.StateObject<T>
export type Task = Types.Task
export type Tween<T> = Types.Tween<T>
export type Use = Types.Use
export type Value<T, S = T> = Types.Value<T, S>
export type Version = Types.Version

-- Down the line, this will be conditional based on whether Fusion is being
-- compiled for Roblox.
do
	local RobloxExternal = require("@packages/Fusion/RobloxExternal")
	External.setExternalProvider(RobloxExternal)
end

local Fusion: Fusion = table.freeze {
	-- General
	version = {major = 0, minor = 3, isRelease = true},
	Contextual = require("@packages/Fusion/Utility/Contextual"),
	Safe = require("@packages/Fusion/Utility/Safe"),

	-- Memory
	cleanup = require("@packages/Fusion/Memory/legacyCleanup"),
	deriveScope = require("@packages/Fusion/Memory/deriveScope"),
	doCleanup = require("@packages/Fusion/Memory/doCleanup"),
	innerScope = require("@packages/Fusion/Memory/innerScope"),
	scoped = require("@packages/Fusion/Memory/scoped"),
	
	-- Graph
	Observer = require("@packages/Fusion/Graph/Observer"),

	-- State
	Computed = require("@packages/Fusion/State/Computed"),
	ForKeys = require("@packages/Fusion/State/ForKeys") :: Types.ForKeysConstructor,
	ForPairs = require("@packages/Fusion/State/ForPairs") :: Types.ForPairsConstructor,
	ForValues = require("@packages/Fusion/State/ForValues") :: Types.ForValuesConstructor,
	peek = require("@packages/Fusion/State/peek"),
	Value = require("@packages/Fusion/State/Value"),

	-- Roblox API
	Attribute = require("@packages/Fusion/Instances/Attribute"),
	AttributeChange = require("@packages/Fusion/Instances/AttributeChange"),
	AttributeOut = require("@packages/Fusion/Instances/AttributeOut"),
	Child = require("@packages/Fusion/Instances/Child"),
	Children = require("@packages/Fusion/Instances/Children"),
	Hydrate = require("@packages/Fusion/Instances/Hydrate"),
	New = require("@packages/Fusion/Instances/New"),
	OnChange = require("@packages/Fusion/Instances/OnChange"),
	OnEvent = require("@packages/Fusion/Instances/OnEvent"),
	Out = require("@packages/Fusion/Instances/Out"),

	-- Animation
	Tween = require("@packages/Fusion/Animation/Tween"),
	Spring = require("@packages/Fusion/Animation/Spring"),
} :: Fusion

return Fusion
