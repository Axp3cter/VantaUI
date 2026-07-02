--!strict
--!optimize 2

--[[
	Registry

	The reactive command collection and the commands it mints. Register and
	remove replace the records array rather than mutating it, so dependents (the
	matcher, the list) see the change. A command's mutable fields are Fusion
	Values, so a bound row updates live on handle assignment.
]]

local fusion = require("@runtime/fusion")
local proxy = require("@runtime/proxy")
local tokens = require("@design/tokens")
local types = require("@vanta/types")

type Scope = fusion.Scope

-- Types -----------------------------------------------------------------------------

-- The public, assignable handle returned from Register.
export type Handle = {
	Name: string,
	Description: string,
	Icon: string | number,
	Remove: () -> (),
}

-- Private ---------------------------------------------------------------------------

local Command = {}
Command.__index = Command

export type Command = typeof(setmetatable(
	{} :: {
		name: fusion.Value<string>,
		description: fusion.Value<string>,
		icon: fusion.Value<string | number>,
		group: string?,
		aliases: { string },
		arguments: { types.CommandArgument },
		callback: (...any) -> (),
		closeAfter: boolean,
	},
	{} :: typeof(Command)
))

function Command.new(scope: Scope, props: types.CommandProps): Command
	return setmetatable({
		name = scope:Value(props.Name or tokens.Defaults.CommandName),
		description = scope:Value(props.Description or tokens.Defaults.CommandDescription),
		icon = scope:Value((props.Icon or tokens.Defaults.CommandIcon) :: string | number),
		group = props.Group,
		aliases = props.Aliases or {},
		arguments = props.Arguments or {},
		callback = props.Callback or tokens.Defaults.CommandCallback,
		closeAfter = props.CloseAfter == true,
	}, Command)
end

--[[
	The public face, a proxy that reads the Values on get and writes them on
	set. This is the handle assignment API, with no bespoke metatable here.
]]
function Command.handle(self: Command, onRemove: () -> ()): Handle
	return proxy.new("VantaUI command", {
		Name = {
			get = function(): unknown
				return fusion.peek(self.name)
			end,
			set = function(value: unknown)
				self.name:set(value :: string)
			end,
		},
		Description = {
			get = function(): unknown
				return fusion.peek(self.description)
			end,
			set = function(value: unknown)
				self.description:set(value :: string)
			end,
		},
		Icon = {
			get = function(): unknown
				return fusion.peek(self.icon)
			end,
			set = function(value: unknown)
				self.icon:set(value :: string | number)
			end,
		},
		Remove = {
			get = function(): unknown
				return onRemove
			end,
		},
	})
end

-- Public ----------------------------------------------------------------------------

local Registry = {}
Registry.__index = Registry

export type Registry = typeof(setmetatable(
	{} :: {
		records: fusion.Value<{ Command }>,
		_scope: Scope,
		_scopes: { [Command]: Scope },
	},
	{} :: typeof(Registry)
))

--[[
	Commands are created on inner scopes of the registry's scope, which the
	palette guarantees outlives the view that reads them.
]]
function Registry.new(scope: Scope): Registry
	return setmetatable({
		records = scope:Value({} :: { Command }),
		_scope = scope,
		_scopes = {},
	}, Registry)
end

function Registry.register(self: Registry, props: types.CommandProps): Handle
	--[[
		Each command gets its own inner scope, so removing it can release its
		Values instead of leaking them until the palette is destroyed.
	]]
	local commandScope = fusion.innerScope(self._scope)
	local record = Command.new(commandScope, props)
	self._scopes[record] = commandScope

	local handle = record:handle(function()
		self:remove(record)
	end)

	local updated = table.clone(fusion.peek(self.records))
	table.insert(updated, record)
	self.records:set(updated)

	return handle
end

function Registry.remove(self: Registry, record: Command): ()
	local current = fusion.peek(self.records)
	local index = table.find(current, record)
	if index == nil then
		return
	end

	local updated = table.clone(current)
	table.remove(updated, index)
	self.records:set(updated)

	--[[
		The record left the collection above, so the evaluation and its rows
		re-project without it. The scope cleanup is deferred one resumption so
		every listener re-evaluates and unbinds from the record's Values before
		those Values are destroyed.
	]]
	local commandScope = self._scopes[record]
	self._scopes[record] = nil
	if commandScope ~= nil then
		task.defer(function()
			fusion.doCleanup(commandScope)
		end)
	end
end

return table.freeze(Registry)
