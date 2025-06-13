local creator = {}

local themeInstances = {}
local currentTheme = {}

local function applyThemeToInstance(instance, themeMap, theme)
	for instanceProp, themeKey in pairs(themeMap) do
		local value = theme
		for segment in string.gmatch(themeKey, "[^%.]+") do
			value = value and value[segment]
		end

		if value ~= nil then
			pcall(function()
				instance[instanceProp] = value
			end)
		end
	end
end

local function applyProps(instance, props)
	for key, value in pairs(props) do
		if key == "__marker" or key == "__themeKeys" then
			continue
		end

		if typeof(key) == "number" then
			if typeof(value) == "Instance" then
				value.Parent = instance
			elseif typeof(value) == "table" and value.__marker then
				value.Parent = instance
			end
		else
			pcall(function()
				instance[key] = value
			end)
		end
	end
end

function creator.create(className)
	return function(props)
		props = props or {}
		local instance = Instance.new(className)
		local themeKeys = props.__themeKeys

		if themeKeys then
			themeInstances[instance] = themeKeys
			applyThemeToInstance(instance, themeKeys, currentTheme)
		end

		applyProps(instance, props)

		local proxy = {}
		proxy.__marker = true

		return setmetatable(proxy, {
			__metatable = instance,

			__tostring = function()
				return tostring(instance)
			end,

			__index = function(self, key)
				local value = instance[key]
				if typeof(value) == "function" then
					return function(_, ...)
						return value(instance, ...)
					end
				else
					return value
				end
			end,

			__newindex = function(self, key, value)
				instance[key] = value
			end,
		})
	end
end

function creator.setTheme(theme: {})
	currentTheme = theme

	for instance, themeMap in pairs(themeInstances) do
		applyThemeToInstance(instance, themeMap, currentTheme)
	end
end

return creator