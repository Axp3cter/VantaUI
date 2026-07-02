--!strict
--!optimize 2

--[[
	fusion

	The single access point to Fusion. Every module binds against these
	re-exports, never against the package directly, so the framework and its
	version are named in exactly one place.
]]

local Fusion = require("@packages/Fusion")

export type Fusion = typeof(Fusion)
export type Scope<Constructors = any> = Fusion.Scope<Constructors>
export type Value<T> = Fusion.Value<T>
export type Computed<T> = Fusion.Computed<T>
export type UsedAs<T> = Fusion.UsedAs<T>
export type Use = Fusion.Use
export type Child = Fusion.Child
export type Spring<T> = Fusion.Spring<T>
export type Tween<T> = Fusion.Tween<T>
export type Observer = Fusion.Observer
export type PropertyTable = Fusion.PropertyTable
export type Contextual<T> = Fusion.Contextual<T>

local fusion = {
	Children = Fusion.Children,
	OnEvent = Fusion.OnEvent,
	OnChange = Fusion.OnChange,
	Out = Fusion.Out,

	Contextual = Fusion.Contextual,
	Safe = Fusion.Safe,
	peek = Fusion.peek,
	doCleanup = Fusion.doCleanup,

	--[[
		The constructor set, for mixing into a scope. Calling
		scoped(fusion.constructors, kit) makes every constructor and kit
		component a method on the scope.
	]]
	constructors = Fusion,
	scoped = Fusion.scoped,
	innerScope = Fusion.innerScope,
}

return table.freeze(fusion)
