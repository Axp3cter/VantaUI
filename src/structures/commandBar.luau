return function()
	--// Imports
	local create = require("@creator").create
	local functions = require("@modules/functions")

	--// References
	local runService = game:GetService("RunService")
	local players = game:GetService("Players")

	--// Variables
	local commandBar = {}

	--// UI
	commandBar.container = create("ScreenGui")({
		Enabled = false,
		Name = "Vanta",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		create("Frame")({
			Name = "View",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(600, 450),

			__themeKeys = {
				BackgroundColor3 = "Background",
			},

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0, 15),
			}),

			create("Frame")({
				Name = "Margins",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -4, 1, -4),

				create("UICorner")({
					Name = "UICorner",
					CornerRadius = UDim.new(0, 13),
				}),

				create("UIStroke")({
					Name = "UIStroke",
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					
					__themeKeys = {
						Color = "Border",
					},
				}),

				create("UIPadding")({
					Name = "UIPadding",
					PaddingBottom = UDim.new(0, 20),
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
					PaddingTop = UDim.new(0, 20),
				}),

				create("Frame")({
					Name = "Topbar",
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 0),

					create("UIListLayout")({
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 25),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					create("ImageLabel")({
						Name = "Icon",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						ImageContent = Content.fromAssetId(111377759265608),
						Size = UDim2.fromOffset(16, 16),

						__themeKeys = {
							ImageColor3 = "Text.Quaternary",
						},
					}),

					create("TextBox")({
						Name = "CommandBar",
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						ClipsDescendants = true,
						CursorPosition = -1,
						FontFace = Font.new("rbxassetid://12187365364"),
						PlaceholderText = "Enter a command...",
						Size = UDim2.new(1, -25, 0, 0),
						Text = "",
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						ClearTextOnFocus = false,

						__themeKeys = {
							PlaceholderColor3 = "Text.Quaternary",
							TextColor3 = "Text.Secondary"
						},

						create("UIPadding")({
							Name = "UIPadding",
							PaddingBottom = UDim.new(0, 1),
							PaddingTop = UDim.new(0, 1),
						}),
					}),

					create("UIPadding")({
						Name = "UIPadding",
						PaddingBottom = UDim.new(0, 5),
					}),
				}),

				create("Frame")({
					Name = "ContentDiv",
					AnchorPoint = Vector2.new(0.5, 0),
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.new(1, 30, 0, 1),

					__themeKeys = {
						BackgroundColor3 = "Border",
					},
				}),

				create("UIListLayout")({
					Name = "UIListLayout",
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 15),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				create("ScrollingFrame")({
					Name = "Content",
					Active = true,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					ScrollBarThickness = 0,
					Selectable = false,
					Size = UDim2.new(1, 30, 1, -58),
					AutomaticCanvasSize = Enum.AutomaticSize.XY,
					CanvasSize = UDim2.new(0, 0, 0, 0),

					create("UIListLayout")({
						Name = "UIListLayout",
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 5),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				}),
			}),
		}),
	}) :: ScreenGui

	--// Initialize
	commandBar.view = commandBar.container.View :: Frame
	commandBar.margins = commandBar.view.Margins :: Frame
	commandBar.content = commandBar.margins.Content :: ScrollingFrame
	commandBar.topbar = commandBar.margins.Topbar :: Frame
	commandBar.commandBar = commandBar.topbar.CommandBar :: TextBox

	if runService:IsStudio() then
		commandBar.container.Parent = players.LocalPlayer.PlayerGui
	else
		functions.protectGui(commandBar.container)
	end

	return commandBar
end
