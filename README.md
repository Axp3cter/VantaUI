<!-- markdownlint-disable MD010 -->

# VantaUI

The offical repository for Vanta's user interface.

## Documentation

### Initializing the UI

```lua
type Theme = {
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

type CommandBarProperties = {
    Shortcut: { Enum.KeyCode }?, -- Some modifier keys will pause input such as control.

    Theme: Theme?,

    AnchorPoint: Vector2?,
    Position: UDim2?,
}

type commandBar = {
	Register: (Properties: CommandProperties) -> CommandProperties, -- Follow up with the "Registering commands" section for this type.
}

function vanta.Initialize(Properties: CommandBarProperties) : commandBar | CommandBarProperties
```

#### Using themes

| Enum       | Accent  |
|------------|---------|
| Monochrome | Gray    |
| Peach      | Peach   |
| Sapphire   | Blue    |
| Royal      | Purple  |
| Gold       | Gold    |
| Forest     | Green   |

```lua
vanta.Themes[theme]
```

### Registering commands

```lua
type CommandArgument = {
	Name: string,
	Type: string,
	Optional: boolean?,
}

type CommandProperties = {
	Name: string?,
	Description: string?,
	Icon: number?,
	Aliases: { string }?,
	Arguments: { CommandArgument }?,
	Callback: (() -> any)?,
}

function commandBar.Register(Properties: CommandProperties): CommandProperties
```

### Updating properties

You can update properties by simply assigning them a new key. They will dynamically update.

```lua
commandBar.Theme = vanta.Themes.Sapphire

----------------------------

flyCommand.Description = `Allows you to move freely. {enabled and "<DISABLED>" or "<ENABLED>}`
```
