--!strict
--!optimize 2

--[[
	Session

	Drives argument entry for one activated command. It owns the parameter
	cursor, the values collected so far, and stepping. It is pure, with no
	Fusion and no instances, and the palette mirrors its progress into reactive
	state for the view.
]]

local arguments = require("@core/arguments")
local result = require("@core/result")
local types = require("@vanta/types")

type Result<T> = result.Result<T>

-- Types -----------------------------------------------------------------------------

--[[
	One committed parameter, its name and the text the user entered, for the
	hint bar's breadcrumb of a multi-step command's progress.
]]
export type CollectedArg = {
	name: string,
	value: string,
}

-- Public ----------------------------------------------------------------------------

local Session = {}
Session.__index = Session

export type Session = typeof(setmetatable(
	{} :: {
		_args: { types.CommandArgument },
		_values: { unknown },
		--[[
			The raw token entered for each committed value, kept for display.
			The coerced value can be an opaque enum payload, but the typed text
			is always legible.
		]]
		_displays: { string },
		_count: number,
		_index: number,
	},
	{} :: typeof(Session)
))

function Session.new(args: { types.CommandArgument }): Session
	return setmetatable({
		_args = args,
		_values = {},
		_displays = {},
		_count = 0,
		_index = 1,
	}, Session)
end

function Session.current(self: Session): types.CommandArgument?
	return self._args[self._index]
end

function Session.index(self: Session): number
	return self._index
end

function Session.total(self: Session): number
	return #self._args
end

function Session.isComplete(self: Session): boolean
	return self._index > #self._args
end

--[[
	Commit the current field. Store the value, advance, and return whether that
	was the last parameter. On failure return the error without moving, so an
	invalid field cannot be stepped past.
]]
function Session.submit(self: Session, raw: string): Result<boolean>
	local arg = self:current()
	if arg == nil then
		return result.ok(true)
	end

	local validated = arguments.validate(arg, raw)
	if not validated.ok then
		return result.err(validated.error)
	end

	self._count += 1
	self._values[self._count] = validated.value
	self._displays[self._count] = raw
	self._index += 1

	return result.ok(self:isComplete())
end

--[[
	Step back one parameter, dropping the value collected for it. Returns false
	when already at the first parameter, in which case the caller returns to
	search.
]]
function Session.back(self: Session): boolean
	if self._index <= 1 then
		return false
	end
	self._index -= 1
	if self._count >= self._index then
		self._values[self._count] = nil
		self._displays[self._count] = nil
		self._count -= 1
	end
	return true
end

--[[
	The values committed so far, each with its parameter name and the text
	entered for it, for the breadcrumb of a multi-step command's progress.
]]
function Session.collected(self: Session): { CollectedArg }
	local out = table.create(self._count)
	for i = 1, self._count do
		out[i] = table.freeze({ name = self._args[i].Name, value = self._displays[i] })
	end
	return out
end

--[[
	The collected values and their count, kept separate so a legitimately nil
	value survives table.unpack into the command callback.
]]
function Session.values(self: Session): ({ unknown }, number)
	return self._values, self._count
end

return table.freeze(Session)
