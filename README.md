# PaladinComms

PaladinComms is a lightweight World of Warcraft addon for paladin-only addon chat plus automatic “Light brother” flavor lines.

## Install it right now

This repository already has the correct addon folder inside it: `PaladinComms/`.

### 1) Copy the addon folder into World of Warcraft

Copy **the inner `PaladinComms` folder** so your final install looks like this:

```text
World of Warcraft/
└─ _retail_/
   └─ Interface/
      └─ AddOns/
         └─ PaladinComms/
            ├─ PaladinComms.toc
            ├─ Core.lua
            ├─ Config.lua
            ├─ Comms.lua
            ├─ Flavor.lua
            ├─ Options.lua
            └─ Minimap.lua
```

Do **not** place the repository root itself inside `AddOns`; the game needs the folder that contains `PaladinComms.toc`.

### 2) Common install paths

#### Windows

```text
C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\PaladinComms
```

#### macOS

```text
/Applications/World of Warcraft/_retail_/Interface/AddOns/PaladinComms
```

### 3) Enable it in-game

1. Start or restart WoW.
2. At the character select screen, click **AddOns**.
3. Make sure **PaladinComms** is enabled.
4. If your client build is newer than the `.toc` interface version, also enable **Load out of date AddOns**.
5. Enter the world.
6. If you copied files while the game was already open, run `/reload`.

### 4) Open the GUI

Once loaded, you can open the settings panel in either of these ways:

- Click the **PaladinComms minimap button**.
- Type **`/pc config`**.

The settings panel includes toggles, a flavor channel dropdown, the new **Flavor chance (%)** slider (default **15%**), the new **Flavor cooldown (seconds)** slider (default **45s**), and quick action buttons.

If you want a preview before installing, see [GUI_MOCKUP.md](GUI_MOCKUP.md).

## Slash commands

- `/pc <message>` — send an addon-only message to paladins running PaladinComms
- `/pc who` — list paladins currently detected on the addon network
- `/pc light` — force an immediate Light line
- `/pc config` — open the settings panel
- `/pc flavor on|off` — enable or disable automatic flavor lines
- `/pc channel say|emote|self` — choose where flavor lines are spoken
- `/pc chance <1-100>` — set flavor chance per eligible event
- `/pc cooldown <10-300>` — set flavor cooldown in seconds
- `/pc minimap show|hide` — show or hide the minimap button
- `/pc toggle` — enable or disable the addon
- `/pc status` — print the current configuration

## What you will see

- **Minimap button:** left-click opens settings, right-click channels a Light line, drag moves it around the minimap.
- **Settings panel title:** `PaladinComms`
- **New defaults:** flavor chance starts at **15%** and flavor cooldown starts at **45 seconds**.

## Notes

- Flavor lines are automatic when enabled: combat entry, kills, loot, level-up, and mounting can all trigger them.
- The hidden paladin network chat is addon-only; normal players do not see those addon messages in the standard chat window.
