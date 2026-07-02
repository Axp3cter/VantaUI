--!strict
--!optimize 2

--[[
	Example

	The palette demonstrates itself. Every feature is a command, so there is no
	second UI. Build with the pipeline (see the README), loadstring the bundle
	in an executor, and press Ctrl+K. This file is the manual test bed, so
	groups, recents, fuzzy search, number constraints in both reject and clamp
	form, string entry, the boolean picker, enum entry with swatches and
	Current, the multi-argument flow, live Theme, Accent and Blur, and the live
	command-property API are all exercised here.
]]

local Vanta = require("@vanta")

local Lighting = game:GetService("Lighting") :: Lighting
local Players = game:GetService("Players") :: Players
local StarterGui = game:GetService("StarterGui") :: StarterGui

local player = Players.LocalPlayer

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local palette = Vanta.new({
	Accent = Vanta.Accents.Blue,
	Placeholder = "Type a command…",
})

-- Enum entry + live palette.Theme. Current marks the active theme in the list.
palette.Register({
	Name = "Set Theme",
	Description = "Switch the palette between dark and light",
	Icon = "moonFill",
	Group = "Appearance",
	Aliases = { "theme" },
	Arguments = {
		{
			Name = "theme",
			Type = "enum",
			Options = {
				{ Value = Vanta.Themes.Dark, Label = "Dark", Icon = "moonFill" },
				{ Value = Vanta.Themes.Light, Label = "Light", Icon = "sunMaxFill" },
			},
			Current = function(): unknown
				return palette.Theme
			end,
		},
	} :: { Vanta.CommandArgument },
	Callback = function(theme)
		palette.Theme = theme
	end,
})

-- Enum entry with colour swatches + live palette.Accent + Current.
palette.Register({
	Name = "Set Accent",
	Description = "Recolour the selection accent",
	Icon = "paintbrushFill",
	Group = "Appearance",
	Aliases = { "accent", "colour" },
	Arguments = {
		{
			Name = "accent",
			Type = "enum",
			Options = {
				{
					Value = Vanta.Accents.Blue,
					Label = "Blue",
					Color = Vanta.Accents.Blue.Dark.Selection,
				},
				{
					Value = Vanta.Accents.Purple,
					Label = "Purple",
					Color = Vanta.Accents.Purple.Dark.Selection,
				},
				{
					Value = Vanta.Accents.Pink,
					Label = "Pink",
					Color = Vanta.Accents.Pink.Dark.Selection,
				},
				{
					Value = Vanta.Accents.Red,
					Label = "Red",
					Color = Vanta.Accents.Red.Dark.Selection,
				},
				{
					Value = Vanta.Accents.Orange,
					Label = "Orange",
					Color = Vanta.Accents.Orange.Dark.Selection,
				},
				{
					Value = Vanta.Accents.Yellow,
					Label = "Yellow",
					Color = Vanta.Accents.Yellow.Dark.Selection,
				},
				{
					Value = Vanta.Accents.Green,
					Label = "Green",
					Color = Vanta.Accents.Green.Dark.Selection,
				},
				{
					Value = Vanta.Accents.Graphite,
					Label = "Graphite",
					Color = Vanta.Accents.Graphite.Dark.Selection,
				},
			},
			Current = function(): unknown
				return palette.Accent
			end,
			--[[
				Live preview. Arrowing through the swatches applies each accent
				immediately, and cancelling restores the one you came in with.
			]]
			Preview = function(value: unknown)
				palette.Accent = value :: Vanta.AccentData
			end,
		},
	} :: { Vanta.CommandArgument },
	Callback = function(accent)
		palette.Accent = accent
	end,
})

-- No-argument + live palette.Blur.
palette.Register({
	Name = "Toggle Blur",
	Description = "Toggle the frosted backdrop",
	Icon = "cloudFill",
	Group = "Appearance",
	Aliases = { "blur" },
	Callback = function()
		palette.Blur = not palette.Blur
	end,
})

-- Number, bounded 1–100 (out of range is rejected with a message).
palette.Register({
	Name = "Walk Speed",
	Description = "Set your character's walk speed",
	Icon = "figureWalk",
	Group = "Character",
	Aliases = { "speed", "ws" },
	Arguments = { { Name = "studs/s", Type = "number", Min = 1, Max = 100 } } :: { Vanta.CommandArgument },
	Callback = function(speed: number?)
		local h = humanoid()
		if h then
			h.WalkSpeed = speed or 16
		end
	end,
})

-- Number that clamps into range instead of rejecting.
palette.Register({
	Name = "Jump Power",
	Description = "Set jump power (clamped 0–500)",
	Icon = "arrowUpCircleFill",
	Group = "Character",
	Aliases = { "jump", "jp" },
	Arguments = {
		{ Name = "power", Type = "number", Min = 0, Max = 500, Clamp = true },
	} :: { Vanta.CommandArgument },
	Callback = function(power: number?)
		local h = humanoid()
		if h then
			h.UseJumpPower = true
			h.JumpPower = power or 50
		end
	end,
})

--[[
	CloseAfter opts out of the default stay-open. Respawning is a "leave"
	action, so the palette dismisses rather than waiting for the next command.
]]
palette.Register({
	Name = "Reset Character",
	Description = "Respawn your character",
	Icon = "arrowCounterclockwiseCircleFill",
	Group = "Character",
	Aliases = { "respawn", "reset" },
	CloseAfter = true,
	Callback = function()
		local h = humanoid()
		if h then
			h.Health = 0
		end
	end,
})

--[[
	Multi-argument entry with two parameters, so the hint bar shows a breadcrumb
	of the values already given as you move through them.
]]
palette.Register({
	Name = "Set Time",
	Description = "Set the in-game clock (hour, then minute)",
	Icon = "clockFill",
	Group = "World",
	Aliases = { "time", "clock" },
	Arguments = {
		{ Name = "hour", Type = "number", Min = 0, Max = 23, Clamp = true },
		{ Name = "minute", Type = "number", Min = 0, Max = 59, Clamp = true },
	} :: { Vanta.CommandArgument },
	Callback = function(hour: number?, minute: number?)
		Lighting.ClockTime = (hour or 0) + (minute or 0) / 60
	end,
})

-- Boolean argument: presents as a Yes / No pick (typed y/n still works).
palette.Register({
	Name = "Set Shadows",
	Description = "Turn global shadows on or off",
	Icon = "sunMaxFill",
	Group = "World",
	Aliases = { "shadows" },
	Arguments = { { Name = "enabled", Type = "boolean" } } :: { Vanta.CommandArgument },
	Callback = function(enabled: boolean?)
		Lighting.GlobalShadows = enabled == true
	end,
})

palette.Register({
	Name = "Toggle Fullbright",
	Description = "Flatten lighting for full visibility",
	Icon = "lightbulbFill",
	Group = "World",
	Aliases = { "fullbright", "fb" },
	Callback = function()
		Lighting.Brightness = if Lighting.Brightness > 1 then 1 else 5
		Lighting.GlobalShadows = not Lighting.GlobalShadows
	end,
})

-- String argument (spaces allowed via the last-argument fast path).
palette.Register({
	Name = "Notify",
	Description = "Send yourself a notification",
	Icon = "bellFill",
	Group = "Utility",
	Aliases = { "toast", "msg" },
	Arguments = { { Name = "text", Type = "string", MaxLength = 80 } } :: { Vanta.CommandArgument },
	Callback = function(...: string)
		local text = table.concat({ ... }, " ")
		StarterGui:SetCore("SendNotification", {
			Title = "VantaUI",
			Text = if text ~= "" then text else "Hello from VantaUI",
			Duration = 3,
		})
	end,
})

-- Live command-property API: this command renames itself each time it runs.
local counter = 0
local editable: Vanta.Command? = nil
editable = palette.Register({
	Name = "Editable Command",
	Description = "Run me to rename myself via command.Name / .Description",
	Icon = "pencilCircleFill",
	Group = "Utility",
	Callback = function()
		if editable == nil then
			return
		end
		counter += 1
		editable.Name = `Renamed ×{counter}`
		editable.Description = "Changed live from the command's own callback"
	end,
})

print(
	"[VantaUI] example ready. Press Ctrl+K, then try 'Set Theme', 'Walk Speed 50', or 'Notify hello'"
)

return palette
