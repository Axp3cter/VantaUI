--!strict

export type CommandArgument = {
	Name: string,
	Type: string,
	Optional: boolean?,
}

export type CommandProperties = {
	Name: string?,
	Description: string?,
	Icon: number?,
	Aliases: { string }?,
	Arguments: { CommandArgument }?,
	Callback: (() -> any)?,
}

export type Theme = {
	Accent: Color3,
	Background: Color3,
	Border: Color3,
	Text: {
		Primary: Color3,
		Secondary: Color3,
		Tertiary: Color3,
		Quaternary: Color3,
		Quinary: Color3,
		Senary: Color3,
	}
}

export type CommandBarProperties = {
	Shortcut: { Enum.KeyCode }?,

	Theme: Theme?,

	AnchorPoint: Vector2?,
	Position: UDim2?,
}

export type commandBar = {
	Register: (commandProperties: CommandProperties) -> any,
}

export type command = { command: any, properties: CommandProperties }

return 1