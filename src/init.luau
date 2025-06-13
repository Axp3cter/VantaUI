--// Imports
local types = require("@types")
local service = require("@modules/services")
local creator = require("@modules/creator")

--// Structures
local commandBar = require("@structures/commandBar")
local command = require("@structures/command")

--// References
local runService = service.RunService
local userInputService = service.UserInputService

--// Variables
local searchAutocomplete = false
local selectedCommand = nil
local commands = {}
local visibleCommands = {}

local vanta = {
	Themes = {
		Monochrome = require("@themes/Monochrome"),
		Peach = require("@themes/Peach"),
		Gold = require("@themes/Gold"),
		Forest = require("@themes/Forest"),
		Sapphire = require("@themes/Sapphire"),
		Royal = require("@themes/Royal"),
	},
}

--// Utility
function vanta:callback(callbackFunction, ...)
	assert(
		typeof(callbackFunction) == "function",
		debug.traceback(`'callback' expects type 'function' for Argument #1, got '{typeof(callbackFunction)}'`, 2)
	)

	task.spawn(function(...)
		local success, err = pcall(callbackFunction, ...)
		if not success then
			task.defer(warn, debug.traceback(err, 2))
		end
	end, ...)
end

local function selectedCallback()
	if not selectedCommand then
		return
	end
	local args = vanta.container.commandBar.Text:split(" ")

	table.remove(args, 1)

	local rawArgs = {}

	for i, arg in ipairs(args) do
		local parsed

		if arg == "true" then
			parsed = true
		elseif arg == "false" then
			parsed = false
		elseif arg == "nil" then
			parsed = nil
		else
			local num = tonumber(arg)

			if num then
				parsed = num
			else
				parsed = arg
			end
		end

		rawArgs[i] = parsed
	end

	local expectedArgCount = selectedCommand.properties.Arguments and #selectedCommand.properties.Arguments

	vanta:callback(
		selectedCommand.properties.Callback,
		selectedCommand.properties,
		unpack(rawArgs, 1, expectedArgCount)
	)
end

--// Initialize
vanta.Initialize = function(properties: types.CommandBarProperties?): types.commandBar
	local appliedProperties = {
		Theme = {},
		Position = properties and properties.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = properties and properties.AnchorPoint or Vector2.new(0.5, 0.5),
		Shortcut = properties and properties.Shortcut or { Enum.KeyCode.F2 },
	}

	local fallbackTheme = vanta.Themes.Peach
	local userTheme = properties and properties.Theme or {}

	appliedProperties.Theme.Accent = userTheme.Accent or fallbackTheme.Accent
	appliedProperties.Theme.Background = userTheme.Background or fallbackTheme.Background
	appliedProperties.Theme.Border = userTheme.Border or fallbackTheme.Border

	appliedProperties.Theme.Text = {}
	local userText = userTheme.Text or {}
	local fallbackText = fallbackTheme.Text

	appliedProperties.Theme.Text.Primary = userText.Primary or fallbackText.Primary
	appliedProperties.Theme.Text.Secondary = userText.Secondary or fallbackText.Secondary
	appliedProperties.Theme.Text.Tertiary = userText.Tertiary or fallbackText.Tertiary
	appliedProperties.Theme.Text.Quaternary = userText.Quaternary or fallbackText.Quaternary
	appliedProperties.Theme.Text.Quinary = userText.Quinary or fallbackText.Quinary
	appliedProperties.Theme.Text.Senary = userText.Senary or fallbackText.Senary

	creator.setTheme(appliedProperties.Theme)

	vanta.container = commandBar()

	vanta.container.view.AnchorPoint = appliedProperties.AnchorPoint
	vanta.container.view.Position = appliedProperties.Position

	local function resetView()
		vanta.container.container.Enabled = false
		vanta.container.commandBar:ReleaseFocus()
	end

	local function select(command)
		if selectedCommand then
			selectedCommand.command.name.TextColor3 = appliedProperties.Theme.Text.Secondary
			selectedCommand.command.description.TextColor3 = appliedProperties.Theme.Text.Tertiary
			selectedCommand.command.command.BackgroundColor3 = appliedProperties.Theme.Text.Primary
			selectedCommand.command.command.BackgroundTransparency = 1
			selectedCommand.command.icon.BackgroundTransparency = 1
			selectedCommand.command.image.ImageColor3 = appliedProperties.Theme.Text.Primary

			for i, v in pairs(selectedCommand.command.arguments:GetChildren()) do
				if v:IsA("TextLabel") then
					v.TextColor3 = appliedProperties.Theme.Text.Secondary
				end
			end
		end

		if not command then
			return
		end

		selectedCommand = command

		command.command.name.TextColor3 = appliedProperties.Theme.Text.Primary
		command.command.description.TextColor3 = appliedProperties.Theme.Text.Senary
		command.command.command.BackgroundColor3 = appliedProperties.Theme.Accent
		command.command.command.BackgroundTransparency = 0
		command.command.icon.BackgroundTransparency = 0
		command.command.image.ImageColor3 = appliedProperties.Theme.Text.Quinary

		for i, v in pairs(command.command.arguments:GetChildren()) do
			if v:IsA("TextLabel") then
				v.TextColor3 = appliedProperties.Theme.Text.Primary
			end
		end
	end

	userInputService.InputBegan:Connect(function(input: InputObject, gpe)
		if not vanta.container.container.Enabled then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape then
			resetView()

			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mousePos = input.Position
			local view = vanta.container.view
			local absPos = view.AbsolutePosition
			local absSize = view.AbsoluteSize

			local inside = mousePos.X >= absPos.X
				and mousePos.X <= absPos.X + absSize.X
				and mousePos.Y >= absPos.Y
				and mousePos.Y <= absPos.Y + absSize.Y

			if not inside then
				resetView()
			end

			return
		end

		if input.KeyCode == Enum.KeyCode.Down then
			if #visibleCommands == 0 then
				return
			end

			local currentIndex = selectedCommand and table.find(visibleCommands, selectedCommand) or 0

			if currentIndex then
				local nextIndex = (currentIndex % #visibleCommands) + 1

				select(visibleCommands[nextIndex])
				searchAutocomplete = true
				vanta.container.commandBar.Text = visibleCommands[nextIndex].properties.Name
				vanta.container.commandBar.CursorPosition = #vanta.container.commandBar.Text + 1

				local cmdFrame = visibleCommands[nextIndex].command.command
				local content = vanta.container.content
				local frameTop = cmdFrame.AbsolutePosition.Y
				local frameBottom = frameTop + cmdFrame.AbsoluteSize.Y
				local contentTop = content.AbsolutePosition.Y
				local contentBottom = contentTop + content.AbsoluteWindowSize.Y

				if frameTop < contentTop then
					content.CanvasPosition = Vector2.new(0, content.CanvasPosition.Y - (contentTop - frameTop))
				elseif frameBottom > contentBottom then
					content.CanvasPosition = Vector2.new(0, content.CanvasPosition.Y + (frameBottom - contentBottom))
				end
			end

			return
		elseif input.KeyCode == Enum.KeyCode.Up then
			if #visibleCommands == 0 then
				return
			end

			local currentIndex = selectedCommand and table.find(visibleCommands, selectedCommand) or 0

			if currentIndex then
				local prevIndex = currentIndex - 1

				if prevIndex < 1 then
					prevIndex = #visibleCommands
				end

				select(visibleCommands[prevIndex])
				searchAutocomplete = true
				vanta.container.commandBar.Text = visibleCommands[prevIndex].properties.Name
				vanta.container.commandBar.CursorPosition = #vanta.container.commandBar.Text + 1

				local cmdFrame = visibleCommands[prevIndex].command.command
				local content = vanta.container.content
				local frameTop = cmdFrame.AbsolutePosition.Y
				local frameBottom = frameTop + cmdFrame.AbsoluteSize.Y
				local contentTop = content.AbsolutePosition.Y
				local contentBottom = contentTop + content.AbsoluteWindowSize.Y

				if frameTop < contentTop then
					content.CanvasPosition = Vector2.new(0, content.CanvasPosition.Y - (contentTop - frameTop))
				elseif frameBottom > contentBottom then
					content.CanvasPosition = Vector2.new(0, content.CanvasPosition.Y + (frameBottom - contentBottom))
				end
			end

			return
		end

		return
	end)

	vanta.container.commandBar.FocusLost:Connect(function(fromEnter)
		if fromEnter then
			if selectedCommand and #visibleCommands ~= 0 then
				local enteredText = vanta.container.commandBar.Text:lower():split(" ")[1] or ""
				local commandToExecute = selectedCommand
				local exactMatchFound = nil
				
				for _, cmd in ipairs(visibleCommands) do
					if cmd.properties.Name:lower() == enteredText then
						exactMatchFound = cmd
						break
					end
					
					if cmd.properties.Aliases then
						for _, alias in ipairs(cmd.properties.Aliases) do
							if alias:lower() == enteredText then
								exactMatchFound = cmd

								break
							end
						end

						if exactMatchFound then
							break
						end
					end
				end

				if exactMatchFound then
					commandToExecute = exactMatchFound
				end

				selectedCommand = commandToExecute
				selectedCallback()
			end

			resetView()

			return
		end

		if vanta.container.container.Enabled then
			vanta.container.commandBar:CaptureFocus()
		end
	end)

	vanta.container.commandBar:GetPropertyChangedSignal("Text"):Connect(function()
        if searchAutocomplete then
            searchAutocomplete = false

            return
        end

        local query = vanta.container.commandBar.Text:lower():split(" ")[1] or ""
        visibleCommands = {}

        for i, cmd in ipairs(commands) do
            local nameMatch = cmd.properties.Name:lower():find(query, 1, true) == 1
            local aliasMatch = false

            if not nameMatch and cmd.properties.Aliases then
                for _, alias in ipairs(cmd.properties.Aliases) do
                    if alias:lower():find(query, 1, true) == 1 then
                        aliasMatch = true

                        break
                    end
                end
            end

            local isVisible = query == "" or nameMatch or aliasMatch

            cmd.command.command.Visible = isVisible

            if isVisible then
                table.insert(visibleCommands, cmd)
            end
        end

        -- Only sort if there is a query (or index's get reordered)
        if query ~= "" then
            local scoredCommands = {}
            local queryLower = query:lower()

            for _, cmd in ipairs(visibleCommands) do
                local score
                local name = cmd.properties.Name:lower()

                if name == queryLower then
                    score = 0
                else
                    score = #name
                end

                table.insert(scoredCommands, { command = cmd, score = score })
            end

            table.sort(scoredCommands, function(a, b)
                return a.score < b.score
            end)

            visibleCommands = {}
            for _, item in ipairs(scoredCommands) do
                table.insert(visibleCommands, item.command)
            end
        end

        if #visibleCommands > 0 then
            select(visibleCommands[1])
        else
            select(nil)
        end
    end)

	do
		local complete = false

		runService.RenderStepped:Connect(function()
			local len = #appliedProperties.Shortcut
			local keysDown = 0

			for _, keyCode in pairs(appliedProperties.Shortcut) do
				if userInputService:IsKeyDown(keyCode) then
					keysDown += 1
				end
			end

			if not complete and keysDown == len then
				complete = true
				vanta.container.container.Enabled = not vanta.container.container.Enabled
				
				if vanta.container.container.Enabled then
					vanta.container.commandBar:CaptureFocus()
				else
					vanta.container.commandBar:ReleaseFocus()
				end
			elseif keysDown < len then
				complete = false
			end
		end)
	end

	local api = {
		Register = function(properties: types.CommandProperties)
			properties = properties or {}

			local command = command(
				properties.Name or "Command",
				properties.Description or "Description",
				properties.Icon or 75764141026163,
				properties.Arguments or {}
			)

			local proxy = {}

			setmetatable(proxy, {
				__index = properties,
				__newindex = function(_, key, value)
					if key == "Name" then
						command.name.Text = value
					elseif key == "Description" then
						command.description.Text = value
					elseif key == "Icon" then
						command.image = Content.fromAssetId(value)
					elseif key == "Arguments" then
						command.updateArguments(value)
					end

					properties[key] = value
				end,
			})

			if properties.Name and properties.Name:find(" ") then
				error("vanta.Register: property 'Name' cannot contain spaces")
			end

			command.command.Parent = vanta.container.content

			command.command.MouseEnter:Connect(function()
				if not selectedCommand or (selectedCommand and selectedCommand.command ~= command) then
					command.command.BackgroundTransparency = 0.95
					command.icon.BackgroundTransparency = 0.95
				end
			end)

			command.command.MouseLeave:Connect(function()
				if not selectedCommand or (selectedCommand and selectedCommand.command ~= command) then
					command.command.BackgroundTransparency = 1
					command.icon.BackgroundTransparency = 1
				end
			end)

			command.command.MouseButton1Click:Connect(function()
				select({ command = command, properties = proxy })
				selectedCallback()
				resetView()
			end)

			table.insert(commands, { command = command, properties = proxy })
			table.insert(visibleCommands, { command = command, properties = proxy })

			return proxy
		end,
	}

	for key, value in pairs(api) do
		vanta.container[key] = value
	end

	setmetatable(vanta.container, {
		__newindex = function(_, key, value)
			if key == "Theme" and type(value) == "table" then
				appliedProperties.Theme = value
				creator.setTheme(value)
			elseif key == "Position" and typeof(value) == "UDim2" then
				appliedProperties.Position = value
				vanta.container.view.Position = value
			elseif key == "AnchorPoint" and typeof(value) == "Vector2" then
				appliedProperties.AnchorPoint = value
				vanta.container.view.AnchorPoint = value
			elseif key == "Shortcut" and type(value) == "table" then
				appliedProperties.Shortcut = value
			else
				rawset(vanta.container, key, value)
			end
		end,

		__index = function(_, key)
			return api[key] or rawget(vanta.container, key)
		end,
	})

	return vanta.container
end

return vanta
