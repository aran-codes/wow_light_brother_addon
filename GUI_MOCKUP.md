# PaladinComms GUI mock-up

> This is what you will see when you click the **PaladinComms minimap button** or type **`/pc config`** in-game.

```text
+----------------------------------------------------------------------------------+
| PaladinComms                                                                     |
| Configure addon-only paladin chat, Light flavor, and quick actions.              |
|                                                                                  |
| [x] Enable addon                                                                 |
|     Tooltip: Turns PaladinComms on or off for this character.                    |
|                                                                                  |
| [x] Enable random flavor lines                                                   |
|     Tooltip: Lets combat, loot, mount, and level-up events speak automatically.  |
|                                                                                  |
| [x] Announce paladins joining the network                                        |
|     Tooltip: Prints a notice when another paladin running the addon joins.       |
|                                                                                  |
| Flavor channel                                                                   |
| [ EMOTE v ]                                                                      |
|     Tooltip: Choose where automatic Light flavor goes: EMOTE / SAY / SELF.       |
|                                                                                  |
| Flavor chance (%)                                                                |
| 1                        [------------------|------------------]              100 |
|                           current value: 15%                                     |
|     Tooltip: Chance per eligible event; stored internally as 0.15.               |
|                                                                                  |
| Flavor cooldown (seconds)                                                        |
| 10                       [------|-------------------------------------]       300 |
|                           current value: 45s                                     |
|     Tooltip: Minimum time between automatic Light lines.                         |
|                                                                                  |
| [ Channel the Light now ]   [ Who's online ]                                     |
|     Tooltip: Speak a random Light line now.                                      |
|     Tooltip: Print the paladin roster currently visible on the addon network.    |
+----------------------------------------------------------------------------------+
```

## Control summary

- **Panel title:** `PaladinComms`
- **Checkboxes:**
  - `Enable addon`
  - `Enable random flavor lines`
  - `Announce paladins joining the network`
- **Dropdown:** `Flavor channel` with `EMOTE`, `SAY`, and `SELF`
- **Sliders:**
  - `Flavor chance (%)` — range `1..100`, step `1`, default `15%`
  - `Flavor cooldown (seconds)` — range `10..300`, step `5`, default `45s`
- **Buttons:**
  - `Channel the Light now`
  - `Who's online`

## Minimap button behavior

- **Left-click:** opens this settings panel
- **Right-click:** immediately channels a Light line
- **Drag:** repositions the button around the minimap
