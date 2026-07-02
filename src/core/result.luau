--!strict
--!optimize 2

--[[
	result

	A tagged-union success or failure value. A valid value can be nil or false,
	which a bare optional cannot tell from failure, so the tag forces callers to
	handle the error branch before reading the value.
]]

export type Result<T> = { ok: true, value: T } | { ok: false, error: string }

local result = {}

function result.ok<T>(value: T): Result<T>
	return table.freeze({ ok = true :: true, value = value })
end

function result.err<T>(message: string): Result<T>
	return table.freeze({ ok = false :: false, error = message })
end

return table.freeze(result)
