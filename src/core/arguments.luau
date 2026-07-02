--!strict
--!optimize 2

--[[
	arguments

	The single source of truth for argument kinds and validation. Each kind is a
	handler that coerces a raw token, constrains the value, and describes itself
	for the hint bar. The dispatch table is a record with one field per
	ArgumentKind, so adding a kind to types.luau refuses to compile until its
	row exists here.
]]

local result = require("@core/result")
local types = require("@vanta/types")

type Result<T> = result.Result<T>

-- Constants -------------------------------------------------------------------------

--[[
	Each spelling maps straight to its boolean. Table identity encodes truth, so
	there is no separate true and false set to keep in sync.
]]
local BOOLEANS: { [string]: boolean } = {
	["true"] = true,
	["1"] = true,
	["yes"] = true,
	["y"] = true,
	["on"] = true,
	["false"] = false,
	["0"] = false,
	["no"] = false,
	["n"] = false,
	["off"] = false,
}

-- Types -----------------------------------------------------------------------------

type KindHandler = {
	coerce: (raw: string, arg: types.CommandArgument) -> Result<unknown>,
	constrain: (value: unknown, arg: types.CommandArgument) -> Result<unknown>,
	hint: (arg: types.CommandArgument) -> string,
}

type KindTable = {
	string: KindHandler,
	number: KindHandler,
	boolean: KindHandler,
	enum: KindHandler,
}

-- Private ---------------------------------------------------------------------------

local kinds: KindTable = {
	number = {
		coerce = function(raw: string): Result<unknown>
			local n = tonumber(raw)
			if n == nil then
				return result.err("Enter a number")
			end
			return result.ok(n)
		end,

		constrain = function(value: unknown, arg: types.CommandArgument): Result<unknown>
			local n = value :: number
			--[[
				Step snaps the value onto a grid anchored at Min (or 0). It is a
				quantisation, applied before the range check.
			]]
			if arg.Step then
				local base = arg.Min or 0
				n = base + math.round((n - base) / arg.Step) * arg.Step
			end
			if arg.Clamp then
				if arg.Min then
					n = math.max(n, arg.Min)
				end
				if arg.Max then
					n = math.min(n, arg.Max)
				end
			else
				if arg.Min and n < arg.Min then
					return result.err(`Must be at least {arg.Min}`)
				end
				if arg.Max and n > arg.Max then
					return result.err(`Must be at most {arg.Max}`)
				end
			end
			return result.ok(n)
		end,

		--[[
			Plain-language constraint with no type words, phrased as a row
			description. Empty when there is nothing useful to say.
		]]
		hint = function(arg: types.CommandArgument): string
			if arg.Min and arg.Max then
				return `Between {arg.Min} and {arg.Max}`
			elseif arg.Min then
				return `At least {arg.Min}`
			elseif arg.Max then
				return `At most {arg.Max}`
			end
			return ""
		end,
	},

	string = {
		coerce = function(raw: string): Result<unknown>
			return result.ok(raw)
		end,

		constrain = function(value: unknown, arg: types.CommandArgument): Result<unknown>
			local s = value :: string
			if arg.MaxLength and #s > arg.MaxLength then
				return result.err(`Up to {arg.MaxLength} characters`)
			end
			if arg.Pattern and not string.match(s, arg.Pattern) then
				return result.err("Invalid format")
			end
			return result.ok(s)
		end,

		hint = function(arg: types.CommandArgument): string
			if arg.MaxLength then
				return `Up to {arg.MaxLength} characters`
			end
			return ""
		end,
	},

	boolean = {
		coerce = function(raw: string): Result<unknown>
			local value = BOOLEANS[raw:lower()]
			if value == nil then
				return result.err("Enter yes or no")
			end
			return result.ok(value)
		end,

		constrain = function(value: unknown): Result<unknown>
			return result.ok(value)
		end,

		hint = function(): string
			return "yes or no"
		end,
	},

	enum = {
		coerce = function(raw: string, arg: types.CommandArgument): Result<unknown>
			local options: { types.EnumOption } = arg.Options or {}
			local key = raw:lower()
			for _, option in options do
				if option.Label:lower() == key then
					return result.ok(option.Value)
				end
			end
			return result.err("Pick one of the options")
		end,

		constrain = function(value: unknown): Result<unknown>
			return result.ok(value)
		end,

		-- The options list itself is the hint, naming a count or the type is noise.
		hint = function(): string
			return ""
		end,
	},
}

-- Public ----------------------------------------------------------------------------

local arguments = {}

--[[
	Runs one raw token through its kind. Coerce, then constrain, then the
	argument's own Validate escape hatch, short-circuiting to the first error.
]]
function arguments.validate(arg: types.CommandArgument, raw: string): Result<unknown>
	-- An omitted optional argument resolves to its default (which may be nil).
	if raw == "" and arg.Optional then
		return result.ok(arg.Default)
	end

	local handler = kinds[arg.Type]

	local coerced = handler.coerce(raw, arg)
	if not coerced.ok then
		return coerced
	end

	local constrained = handler.constrain(coerced.value, arg)
	if not constrained.ok then
		return constrained
	end

	if arg.Validate then
		-- User code: a throwing validator reads as invalid, never as a crash.
		local ok, passed, message = pcall(arg.Validate, constrained.value)
		if not ok then
			return result.err("Invalid value")
		end
		if not passed then
			return result.err(message or `Invalid {arg.Name}`)
		end
	end

	return constrained
end

-- Human-readable constraint summary for the hint bar.
function arguments.hint(arg: types.CommandArgument): string
	return kinds[arg.Type].hint(arg)
end

--[[
	The parameter's presentation name, its authored name with the first letter
	uppercased. The one transform behind both the parameter row's title and a
	pick's placeholder, so the two spellings can never drift apart.
]]
function arguments.displayName(name: string): string
	return `{name:sub(1, 1):upper()}{name:sub(2)}`
end

-- Splits a query into whitespace-separated tokens (command word first).
function arguments.tokenize(query: string): { string }
	local tokens = {}
	local count = 0
	for word in query:gmatch("%S+") do
		count += 1
		tokens[count] = word
	end
	return tokens
end

return table.freeze(arguments)
