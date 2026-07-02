--!strict
--!optimize 2

--[[
	services

	The services VantaUI uses, typed to their classes. This is the primary
	game:GetService entry, so no service is fetched twice. The only other
	permitted call site is runtime/protect.luau, which must fetch CoreGui
	inside a pcall at the point of use.
]]

return table.freeze({
	Players = game:GetService("Players") :: Players,
	UserInputService = game:GetService("UserInputService") :: UserInputService,
	TweenService = game:GetService("TweenService") :: TweenService,
	RunService = game:GetService("RunService") :: RunService,
	Workspace = game:GetService("Workspace") :: Workspace,
	Lighting = game:GetService("Lighting") :: Lighting,
})
