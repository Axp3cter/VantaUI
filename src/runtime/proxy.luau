--!strict
--!optimize 2

--[[
	proxy

	The one assignment-API factory. Reads go through a getter and writes through
	a setter, and command and palette handles share this shape. This is the
	single place the metatable and the dynamic any boundary live. A new property
	is one accessor row, and no any leaks anywhere else.
]]

export type Accessor = {
	get: () -> unknown,
	set: ((value: unknown) -> ())?,
}

export type Accessors = { [string]: Accessor }

local proxy = {}

-- `name` is used only to phrase the error on an illegal write.
function proxy.new<T>(name: string, accessors: Accessors): T
	local handle = setmetatable({}, {
		__index = function(_, key: string): unknown
			local accessor = accessors[key]
			return if accessor then accessor.get() else nil
		end,

		__newindex = function(_, key: string, value: unknown): ()
			local accessor = accessors[key]
			if accessor == nil or accessor.set == nil then
				error(`{name}: "{key}" is not a writable property`, 3)
			end
			accessor.set(value)
		end,
	})

	return (handle :: any) :: T
end

return table.freeze(proxy)
