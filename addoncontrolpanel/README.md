# AddonControlPanel

**Version:** 2.0.0  
**Platform:** Ashita v4  
**Author:** Izumi (ShiroIzumi)

AddonControlPanel is a graphical manager for a user-defined list of Ashita addons. It provides one place to load, unload, reload, and open configuration commands for the addons you use most often.

## Features

- Add and remove tracked addons.
- Assign an optional custom config command to each addon.
- Load, unload, and reload tracked addons.
- Launch an addon's config command.
- Alphabetically sort the tracked addon list.
- Save tracked addons to `config/acp_config.json`.
- Persist main-window and config-window position and size.
- Lock the main window against movement/resizing.
- Adjustable font scale.
- Configurable background color and opacity.
- Independent title-bar and border toggles.
- Custom close X when the title bar is hidden.
- Dark, compact UI styling.

## What it cannot do

- It does not automatically scan your Ashita addons directory.
- It does not automatically know whether a tracked addon is currently loaded.
- It does not verify that an addon folder exists before issuing a command.
- It does not auto-discover an addon's config command.
- It does not download, install, or update addons.
- It does not replace Ashita's built-in addon loader.

AddonControlPanel is intentionally a command launcher/manager rather than a full addon-state monitor.

## Installation

Place the addon here:

```text
Ashita/
└─ addons/
   └─ addoncontrolpanel/
      └─ addoncontrolpanel.lua
```

Then load it:

```text
/addon load addoncontrolpanel
```

## Commands

| Command | Description |
|---|---|
| `/acp` | Toggle the main AddonControlPanel window. |
| `/addoncontrolpanel` | Same as `/acp`. |
| `/acp config` | Toggle the AddonControlPanel config window. |
| `/addoncontrolpanel config` | Same as `/acp config`. |

## Adding an addon

Enter the addon's Ashita load name, for example:

```text
bluspells
```

Optionally provide its config command:

```text
bsp config
```

AddonControlPanel adds the leading slash automatically when the Config button is pressed.

If the config command is blank, the Config button defaults to:

```text
/<addonname>
```

## Main window

Each tracked addon receives four buttons:

- **Load** — queues `/addon load <name>`
- **Unload** — queues `/addon unload <name>`
- **Reload** — queues `/addon reload <name>`
- **Config** — queues the configured slash command

The Edit section lets you change a tracked addon's config command or remove the entry entirely.

## Config window

Available appearance options:

- Lock Window Position / Size
- Show Title Bar
- Show Border
- Font Scale
- Window Color
- Background Opacity
- Reset Appearance
- Reset Window Position / Size

## Persistence

Tracked addon entries are stored in:

```text
<Ashita>/config/acp_config.json
```

Appearance and window geometry are saved through Ashita's `settings` library.

## Ashita v4 compatibility

This version avoids the older `BeginChild` call signature that broke on newer Ashita v4 ImGui bindings. It also avoids `ImGuiCond_*` usage.

## Notes

A button press only confirms that AddonControlPanel queued the command through Ashita's ChatManager. If the target addon fails to load or does not recognize its config command, that error belongs to the target addon rather than AddonControlPanel.
