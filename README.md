# VantaUI

A Spotlight-style command palette for Roblox, built on [Fusion](https://elttob.uk/Fusion).

Register commands, press `Ctrl` `K`, and run them by name — with guided argument
entry, constraints, live theming, and an optional frosted backdrop. Bundles to a
single self-contained file with nothing to install.

## Features

- **Command palette** — fuzzy, prefix and alias matching, fully keyboard-driven,
  with the matched characters highlighted in each result.
- **Groups and recents** — commands can declare a `Group`; the empty-query view
  shows your recently run commands first, then each group under a muted header.
- **Argument entry** — activating a command with parameters opens a guided,
  Raycast-style entry mode: a breadcrumb header naming the command, one prompt per
  parameter, and a hint bar with live validation. Boolean parameters present as a
  two-option pick; enum parameters mark the current value when you provide one.
- **Constraints** — bound a number to a range (reject or silently clamp), snap it
  to a step, limit string length or match a pattern, offer enum options, or supply
  a custom validator.
- **Theming** — Dark and Light bases with eight macOS accents, swappable at runtime.
- **Reactive** — assign a property (a theme, an accent, a command's description) and
  the panel updates live.
- **Self-contained** — one file, no dependencies to install.

## Quick start

```luau
local Vanta = loadstring(game:HttpGet(BUNDLE_URL))()

local palette = Vanta.new({ Accent = Vanta.Accents.Purple })

palette.Register({
	Name = "Walk Speed",
	Description = "Set your character's walk speed",
	Icon = "bolt",
	Aliases = { "ws", "speed" },
	Arguments = { { Name = "studs/s", Type = "number", Min = 1, Max = 100 } },
	Callback = function(speed: number?)
		local humanoid = game.Players.LocalPlayer.Character.Humanoid
		humanoid.WalkSpeed = speed or 16
	end,
})
```

The default toggle is `Ctrl` `K` (pass `Shortcut` to change it). Once open, `↑` / `↓`
move the selection, `Enter` runs the highlighted command, and `Esc` closes.

### Palette API

`Vanta.new(props)` returns a handle. Props (`Theme`, `Accent`, `Shortcut`,
`Position`, `AnchorPoint`, `Placeholder`, `Blur`) are all optional.

| Member | Description |
| --- | --- |
| `Register(props)` | Register a command; returns a command handle. |
| `Show()` / `Hide()` / `Toggle()` | Open or close the palette. |
| `IsOpen` | Whether the palette is shown. |
| `Theme` / `Accent` / `Blur` | Read or assign to swap live. |
| `Destroy()` | Hide and release everything the palette owns. |

A command handle exposes live `Name`, `Description` and `Icon` (assigning updates the
row in place) and `Remove()`.

### Commands and arguments

`Register` takes `Name`, `Description`, `Icon` (a glyph name, asset id, or content
URL), `Group`, `Aliases`, `Arguments`, and `Callback`. Matching weights name over
aliases over description.

An argument is `{ Name, Type, ... }` where `Type` is `"number"`, `"string"`,
`"boolean"` or `"enum"`. Constraints by type:

- **number** — `Min` / `Max` (out of range is rejected, unless `Clamp = true` folds
  it in), `Step` (snap to a multiple).
- **string** — `MaxLength`, `Pattern`.
- **boolean** — presented as a Yes / No pick; typed `y`/`n`/`true`/`false` filter it.
- **enum** — `Options` (`{ Value, Label, Icon?, Color? }`); the list renders them for
  pick. `Current` (a getter) marks the option that is active right now.
- **any** — `Optional` + `Default`, `Placeholder`, and `Validate(value) -> (ok, msg?)`
  as an escape hatch.

In entry mode, `Enter`/`Tab` commit a field (invalid input is refused with a
message), the `‹` breadcrumb steps back a parameter, and `Esc` returns to search.
Typing `ws 50` and activating fills the argument inline.

## Building

The pipeline composes the source into a single bundle with
[ProCMP](https://github.com/Proton-Utilities/ProCMP) and
[darklua](https://github.com/seaofvoices/darklua). Install the toolchain with
[Rokit](https://github.com/rojo-rbx/rokit), then build the two entrypoints:

```sh
rokit install

# Library → dist/vanta.luau
pcmp build -n Library -i src/init.luau -o dist/vanta.luau \
	-f pipeline/frames/stable.luau -c pipeline/darklua/stable.json

# Example (self-contained control panel) → dist/example.luau
pcmp build -n Example -i src/example.luau -o dist/example.luau \
	-f pipeline/frames/stable.luau -c pipeline/darklua/stable.json
```

Both bundles are fully self-contained (zero `require` calls). `pipeline/.pcmp.json`
holds the same two configs for interactive use; swap `stable.json` for
`unminified.json` to build a readable bundle. `src/example.luau` is a control panel
that drives the whole public API — build it, then `loadstring` the bundle in an
executor.

The icon catalog (`src/design/icons/catalog.luau`) is generated, not hand-edited — it
is most of the bundle's size. Regenerate it, or ship a curated subset, with:

```sh
lune run pipeline/tools/gen-icons.luau                          # full glyph set
lune run pipeline/tools/gen-icons.luau pipeline/tools/icons/subset.txt   # only listed names
```

`.globals/` holds the executor + Roblox type definitions used by `luau-lsp` and the
workspace. The toolchain is pinned in `rokit.toml`; CI runs format → typecheck →
build on every push.

## License

MIT — see [LICENSE](LICENSE).
