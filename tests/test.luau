--// Imports
local vanta = require("../src/init")
local create = require("@creator").create
local services = require("@modules/services")

--// References
local localPlayer = game.Players.localPlayer

local tweenService = services.TweenService
local runService = services.RunService
local userInputService = services.UserInputService
local players = services.Players

--// Variables
local keycodeCharacters = {}
local waypoints = {}

--// UI
local commands = vanta.Initialize({
	Shortcut = { Enum.KeyCode.Semicolon },
	Theme = vanta.Themes.Peach,
})

commands.Register({
	Icon = 70678191702687,
	Name = "Theme",
	Description = "Changes the theme of the interface.",
	Aliases = { "style" },
	Arguments = {
		{
			Name = "Theme",
			Type = "string",
			Optional = false,
		},
	},
	Callback = function(self, theme: string)
		if not theme then
			warn("Vanta: No theme was provided.")

			return
		end

		theme = theme:lower()

		for key, value in pairs(vanta.Themes) do
			if key:lower() == theme then
				commands.Theme = value

				return
			end
		end

		warn("Vanta: Unable to find the theme provided.")
	end,
})

commands.Register({
	Icon = 131267934081723,
	Name = "ThemeList",
	Description = "Prints the available themes into the console",
	Aliases = { "listthemes" },
	Callback = function(self)
		for i in pairs(vanta.Themes) do
			print(i)
		end
	end,
})

commands.Register({
	Name = "Shortcut",
	Description = "Changes the interface shortcut key.",
	Aliases = { "hotkey" },
	Arguments = {
		{
			Name = "Hotkey",
			Type = "string",
			Optional = false,
		}
	},
	Callback = function(self, shortcut: string)
		local key = keycodeCharacters[shortcut]

		if not key then
			warn("Vanta: Invalid shortcut key: " .. shortcut)

			return
		end

		commands.Shortcut = { key }
	end,
})

commands.Register({
	Icon = 109835673401964,
	Name = "Flight",
	Description = "Allows you to move freely in air.",
	Aliases = { "fly" },
	Arguments = {
		{
			Name = "Speed",
			Type = "number",
			Optional = true,
		},
	},
	Callback = function(self, speed: number?)
		local player = players.LocalPlayer
		local character = player.Character

		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not humanoidRootPart then
			return
		end

		if self._enabled and speed and self._speed ~= speed then

			self._speed = speed

			return
		end

		if not speed or self._speed == speed then
			self._enabled = not self._enabled
		else
			self._enabled = true
			self._speed = speed
		end

		if not self._enabled then
			if self._connection then
				self._connection:Disconnect()
				self._connection = nil
			end

			if self._gyro then
				self._gyro:Destroy()
				self._gyro = nil
			end

			if self._velocity then
				self._velocity:Destroy()
				self._velocity = nil
			end

			humanoid.PlatformStand = false

			return
		end

		self._speed = self._speed or speed or 50

		self._gyro = create("BodyGyro")({
			P = 9e4,
			MaxTorque = Vector3.new(9e9, 9e9, 9e9),
			CFrame = humanoidRootPart.CFrame,
			Parent = humanoidRootPart,
		})

		self._velocity = create("BodyVelocity")({
			MaxForce = Vector3.new(9e9, 9e9, 9e9),
			Velocity = Vector3.new(0, 0, 0),
			Parent = humanoidRootPart,
		})

		humanoid.PlatformStand = true

		self._connection = runService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera

			if not self._gyro or not self._velocity or not camera then
				return
			end

			local moveDirection = Vector3.zero

			if userInputService:IsKeyDown(Enum.KeyCode.W) then
				moveDirection += camera.CFrame.LookVector
			end

			if userInputService:IsKeyDown(Enum.KeyCode.S) then
				moveDirection -= camera.CFrame.LookVector
			end

			if userInputService:IsKeyDown(Enum.KeyCode.D) then
				moveDirection += camera.CFrame.RightVector
			end

			if userInputService:IsKeyDown(Enum.KeyCode.A) then
				moveDirection -= camera.CFrame.RightVector
			end

			if userInputService:IsKeyDown(Enum.KeyCode.E) then
				moveDirection += Vector3.new(0, 1, 0)
			end

			if userInputService:IsKeyDown(Enum.KeyCode.Q) then
				moveDirection -= Vector3.new(0, 1, 0)
			end

			self._gyro.CFrame = camera.CFrame

			if moveDirection.Magnitude > 0 then
				self._velocity.Velocity = moveDirection.Unit * self._speed
			else
				self._velocity.Velocity = Vector3.zero
			end
		end)
	end,
})

commands.Register({
	Icon = 128152706364831,
	Name = "WalkSpeed",
	Description = "Adjusts your walking speed to the desired amount.",
	Aliases = {
		"ws",
		"walkingspeed",
		"speed",
	},
	Arguments = {
		{
			Name = "Speed",
			Type = "number",
			Optional = true,
		},
	},
	Callback = function(self, speed: number?)
		local character = game.Players.LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				humanoid.WalkSpeed = speed or 16
			end
		end
	end,
})

commands.Register({
	Icon = 107741815779771,
	Name = "JumpPower",
	Description = "Adjusts your jumping power to the desired amount.",
	Aliases = {
		"jp",
		"jh",
		"jumpingpower",
		"jumpheight",
	},
	Arguments = {
		{
			Name = "Power",
			Type = "number",
			Optional = true,
		},
	},
	Callback = function(self, power: number)
		local character = game.Players.LocalPlayer.Character

		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if not humanoid then
			return
		end

		power = power or 50

		if humanoid.UseJumpPower then
			humanoid.JumpPower = power
		else
			local gravity = workspace.Gravity
			humanoid.JumpHeight = (power ^ 2) / (2 * gravity)
		end
	end,
})

commands.Register({
	Icon = 73233822792957,
	Name = "Noclip",
	Description = "Allows you to move through collidable objects.",
	Arguments = {},
	Callback = function(self)
		self._enabled = not self._enabled
		self._originalProperties = self._originalProperties or {}

		if self._connection then
			self._connection:Disconnect()
			self._connection = nil
		end

		local character = players.LocalPlayer.Character

		if not character then
			return
		end

		if not self._enabled then
			for _, v in pairs(character:GetChildren()) do
				if v:IsA("BasePart") then
					if self._originalProperties[v] then
						v.CanCollide = self._originalProperties[v]
					end
				end
			end

			return
		end

		self._connection = runService.RenderStepped:Connect(function()
			for _, v in pairs(character:GetChildren()) do
				if v:IsA("BasePart") then
					if not self._originalProperties[v] then
						self._originalProperties[v] = v.CanCollide
					end

					v.CanCollide = false
				end
			end
		end)
	end,
})

commands.Register({
	Icon = 86590563551160,
	Name = "Gravity",
	Description = "Changes the game's gravity.",
	Aliases = { "grav" },
	Arguments = {
		{
			Name = "Gravity",
			Type = "number",
			Optional = true,
		},
	},
	Callback = function(self, value: number?)
		if not self._original then
			self._original = workspace.gravity
		end

		workspace.Gravity = value or self._original
	end,
})

commands.Register({
	Icon = 135513779702498,
	Name = "FOV",
	Description = "Adjusts the camera's field of view in radius.",
	Aliases = { "fieldofview" },
	Arguments = {
		{
			Name = "Radius",
			Type = "number",
			Optional = false,
		},
	},
	Callback = function(self, value: number)
		local camera = workspace.CurrentCamera

		if not camera then
			return
		end

		camera.FieldOfView = math.clamp(value, 1, 120)
	end,
})

commands.Register({
	Icon = 102914549959534,
	Name = "Reset",
	Description = "Resets your character.",
	Aliases = { "respawn", "re" },
	Callback = function(self)
		local player = players.LocalPlayer

		if player and player.Character then
			player.Character:BreakJoints()
		end
	end,
})

commands.Register({
	Icon = 76373975196682,
	Name = "Teleport",
	Description = "Teleports you to another player.",
	Aliases = { "tp", "goto" },
	Arguments = {
		{
			Name = "Player",
			Type = "string",
			Optional = false,
		},
	},
	Callback = function(self, playerName: string)
		local targetPlayer = nil

		for _, player in pairs(players:GetPlayers()) do
			if player ~= localPlayer and player.Name:lower():sub(1, #playerName) == playerName:lower() then
				targetPlayer = player

				break
			end
		end

		if not targetPlayer or not targetPlayer.Character then
			warn("Vanta: Player not found.")

			return
		end

		local root = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

		if root and localRoot then
			localRoot.CFrame = root.CFrame + Vector3.new(0, 3, 0)
		end
	end,
})

commands.Register({
	Icon = 76373975196682,
	Name = "TweenTeleport",
	Description = "Tweens your character to another player.",
	Aliases = { "ttp", "tweengoto" },
	Arguments = {
		{
			Name = "Player",
			Type = "string",
			Optional = false,
		},
		{
			Name = "Speed",
			Type = "number",
			Optional = true,
		},
	},
	Callback = function(self, playerName: string, speed: number?)
		speed = speed or 50

		local target = nil

		for _, p in ipairs(players:GetPlayers()) do
			if p ~= localPlayer and p.Name:lower():sub(1, #playerName) == playerName:lower() then
				target = p

				break
			end
		end

		if not target or not target.Character then
			warn("Vanta: Player not found.")

			return
		end

		local root = target.Character:FindFirstChild("HumanoidRootPart")
		local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

		if root and localRoot then
			local distance = (root.Position - localRoot.Position).Magnitude
			local time = math.clamp(distance / speed, 0.05, 10)
			tweenService:Create(localRoot, TweenInfo.new(time), { CFrame = root.CFrame + Vector3.new(0, 3, 0) }):Play()
		end
	end,
})

commands.Register({
	Icon = 83719401271160,
	Name = "Waypoints",
	Description = "Lists all current waypoints.",
	Aliases = { "wpts" },
	Callback = function()
		for name, pos in pairs(waypoints) do
			print(name, pos)
		end
	end,
})

commands.Register({
	Icon = 72217464657812,
	Name = "SetWaypoint",
	Description = "Sets a waypoint at your current position.",
	Aliases = { "AddWaypoint", "swpt" },
	Arguments = {
		{
			Name = "Name",
			Type = "string",
			Optional = false,
		},
	},
	Callback = function(_, name: string)
		local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

		if localRoot then
			waypoints[name] = localRoot.Position
		end
	end,
})

commands.Register({
	Icon = 73401183523058,
	Name = "DeleteWaypoint",
	Description = "Deletes a waypoint by name.",
	Aliases = { "DelWaypoint", "dwpt" },
	Arguments = {
		{
			Name = "Name",
			Type = "string",
			Optional = false,
		},
	},
	Callback = function(_, name: string)
		if waypoints[name] then
			waypoints[name] = nil
		else
			warn("Waypoint not found.")
		end
	end,
})

commands.Register({
	Icon = 101074123820038,
	Name = "GotoWaypoint",
	Description = "Teleports you to a saved waypoint.",
	Aliases = { "teleportwaypoint", "tpwaypoint", "wpt" },
	Arguments = {
		{
			Name = "Name",
			Type = "string",
			Optional = false,
		},
	},
	Callback = function(_, name: string)
		local position = waypoints[name]
		local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

		if position and localRoot then
			localRoot.CFrame = CFrame.new(position)
		else
			warn("Waypoint not found or character missing.")
		end
	end,
})

commands.Register({
	Icon = 136666701157035,
	Name = "ClearWaypoints",
	Description = "Clears all saved waypoints.",
	Aliases = { "cwpts" },
	Callback = function()
		waypoints = {}
	end,
})

--// Initialize
for _, keycode in ipairs(Enum.KeyCode:GetEnumItems()) do
	local name = keycode.Name

	if #name == 1 then
		keycodeCharacters[string.lower(name)] = keycode
		keycodeCharacters[string.upper(name)] = keycode
	elseif name == "LeftBracket" then
		keycodeCharacters["["] = keycode
	elseif name == "RightBracket" then
		keycodeCharacters["]"] = keycode
	elseif name == "Semicolon" then
		keycodeCharacters[";"] = keycode
	elseif name == "Quote" then
		keycodeCharacters["'"] = keycode
	elseif name == "Comma" then
		keycodeCharacters[","] = keycode
	elseif name == "Period" then
		keycodeCharacters["."] = keycode
	elseif name == "Slash" then
		keycodeCharacters["/"] = keycode
	elseif name == "BackSlash" then
		keycodeCharacters["\\"] = keycode
	elseif name == "Minus" then
		keycodeCharacters["-"] = keycode
	elseif name == "Equals" then
		keycodeCharacters["="] = keycode
	elseif name == "Backquote" then
		keycodeCharacters["`"] = keycode
	elseif name:match("^%d$") then
		keycodeCharacters[name] = keycode
	end
end