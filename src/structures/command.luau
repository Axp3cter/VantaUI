local types = require("@types")

return function(name: string, description: string, iconId: number?, arguments: { types.CommandArgument }?)
	--// Imports
	local create = require("@creator").create

	--// Variables
	local command = {}

	--// UI
	command.command = create("TextButton")({
		Name = "Command",
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Selectable = false,
		Size = UDim2.fromScale(1, 0),
		Text = "",

		create("Frame")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(28, 28),

			create("ImageLabel")({
				Name = "Image",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				ImageContent = Content.fromAssetId(iconId or 75764141026163),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(18, 18),

				__themeKeys = {
					ImageColor3 = "Text.Secondary",
				},
			}),

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0, 5),
			}),
		}),

		create("UICorner")({
			Name = "UICorner",
			CornerRadius = UDim.new(0, 7),
		}),

		create("UIPadding")({
			Name = "UIPadding",
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
		}),

		create("Frame")({
			Name = "Info",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			LayoutOrder = 1,

			create("TextLabel")({
				Name = "Name",
				Active = true,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxassetid://12187365364"),
				LayoutOrder = 1,
				Selectable = true,
				Text = name or "",
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = not not name,

				__themeKeys = {
					TextColor3 = "Text.Secondary",
				},
			}),

			create("UIListLayout")({
				Name = "UIListLayout",
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			create("TextLabel")({
				Name = "Description",
				Active = true,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxassetid://12187365364"),
				LayoutOrder = 1,
				Selectable = true,
				Text = description or "",
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = not not description,

				__themeKeys = {
					TextColor3 = "Text.Tertiary",
				},
			}),
		}),

		create("UIListLayout")({
			Name = "UIListLayout",
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		create("Folder")({
			Name = "Arguments",

			create("UIListLayout")({
				Name = "UIListLayout",
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}),
	}):: TextButton

	--// Initialize
	command.arguments = command.command.Arguments :: Folder
	command.info = command.command.Info :: Frame
	command.name = command.info:FindFirstChild("Name") :: TextLabel
	command.description = command.info.Description :: TextLabel
	command.icon = command.command.Icon :: Frame
	command.image = command.icon.Image :: ImageLabel

	command.updateArguments = function(arguments)
		for _, v in next, (arguments or {}) do
			create("TextLabel")({
				Name = "Argument",
				Active = true,
				AnchorPoint = Vector2.new(1, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxassetid://16658246179"),
				LayoutOrder = 1,
				Position = UDim2.fromScale(1, 0),
				RichText = true,
				Selectable = true,
				Text = `{v.Name}{v.Optional and "?" or ""}: {v.Type}`,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = command.arguments,

				__themeKeys = {
					TextColor3 = "Text.Secondary",
				},
			})
		end
	end

	command.updateArguments(arguments)

	return command
end
