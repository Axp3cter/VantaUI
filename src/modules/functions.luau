local functions = {}

functions.protectGui = function(gui: ScreenGui): ScreenGui | string
	local _game = cloneref and cloneref(game) or game
	local success, returned = pcall(function()
		gui.Parent = gethui and gethui()
			or cloneref and cloneref(_game:GetService("CoreGui"))
			or _game:GetService("CoreGui")
	end)

	return success and gui or returned
end

--// Initialize
functions.protectGui = newcclosure and newcclosure(functions.protectGui) or functions.protectGui

return functions
