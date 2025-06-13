local function cast(service: string): any
	return game:GetService(service)
end

return {
	TweenService = cast("TweenService") :: TweenService,
	RunService = cast("RunService") :: RunService,
	UserInputService = cast("UserInputService") :: UserInputService,
	Players = cast("Players") :: Players,
}
