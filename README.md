# PaladinComms

**PaladinComms** is a World of Warcraft: Midnight addon that provides an addon-only paladin chat network and random Light/paladin flavor lines for immersive brotherly roleplay — all invisible to non-addon users.

---

## Features

- **Addon-only chat** — messages are delivered exclusively through `CHAT_MSG_ADDON` and never appear in any player's chat window. Non-addon users cannot see the traffic even if they manually join the same channel.
- **Server-wide reach** — the addon silently joins a hidden custom channel (`PaladinCommsNet`) scoped to your realm/connected-realm cluster. Falls back to group/guild channels when partied cross-realm.
- **Live online roster** — track which fellow paladins are currently running the addon with `/pc who`.
- **Random flavor lines** — Light-brother one-liners triggered automatically by gameplay events (combat, kills, looting, mounting, levelling). Configurable chance and cooldown.
- **Minimap button** — left-click to open the Settings panel; right-click to channel a random Light line. Draggable, position persisted across sessions.
- **In-game Settings panel** — full GUI for all toggles, the flavor channel, chance slider, and cooldown slider. No slash commands required.
- **Slash commands** — full `/pc` command tree for power users.

---

## How the Addon-Only Chat Works

WoW addon messages (`C_ChatInfo.SendAddonMessage`) are delivered to the `CHAT_MSG_ADDON` event **only**. They are not rendered in any chat window — they are addon-to-addon data packets completely invisible to non-addon users.

The addon does the following on login (after a short delay to let the chat system settle):

1. Calls `JoinTemporaryChannel("PaladinCommsNet")` to silently join a hidden custom channel.
2. Removes the channel from every chat frame's subscribed list so no join notices or text appear in your UI (`ChatFrame_RemoveChannel`).
3. Installs chat filters (`ChatFrame_AddMessageEventFilter`) to suppress any stray `CHAT_MSG_CHANNEL` or `CHAT_MSG_CHANNEL_NOTICE` events for that channel.
4. Sends addon messages over the channel index with:
   ```lua
   C_ChatInfo.SendAddonMessage(prefix, body, "CHANNEL", channelIndex)
   ```
5. Announces itself to the network (`HELLO`) and begins a heartbeat ping every 60 seconds to maintain the roster.

**Result:** paladin-to-paladin messages travel over the custom channel as addon packets. Outsiders — even players who manually type `/join PaladinCommsNet` — cannot intercept the addon message traffic.

### Realistic caveats

| Caveat | Details |
|---|---|
| **Realm-scoped** | Custom channels are per-realm (or connected-realm cluster). This is not a true global cross-realm channel. |
| **Cross-realm groups** | When you are partied cross-realm the addon falls back to `PARTY` / `RAID` / `INSTANCE_CHAT` addon messages, which do work cross-realm. |
| **Both must be online** | Both paladins must be logged in and running PaladinComms for the channel handshake to succeed. |
| **Startup delay** | Allow a few seconds after login for the channel join and `HELLO` handshake before expecting to see each other. |

---

## Installation

1. Download or clone this repository so you have the `PaladinComms/` folder.
2. Place it inside your AddOns directory. The folder **must** be named `PaladinComms` (matching the `.toc` filename).

   **Windows:**
   ```
   C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\PaladinComms\
   ```

   **macOS:**
   ```
   /Applications/World of Warcraft/_retail_/Interface/AddOns/PaladinComms/
   ```

3. Launch (or `/reload`) World of Warcraft.
4. Click **AddOns** on the character select screen, find **PaladinComms**, and tick its checkbox.
   - If the addon does not appear, tick **"Load out of date AddOns"** at the top of the AddOns list.

---

## Usage & Slash Commands

Type `/pc` or `/paladincomms` followed by a subcommand.

| Command | Description |
|---|---|
| `/pc <message>` | Broadcast a message to all online paladins running the addon. |
| `/pc who` | List paladins currently detected on the network. |
| `/pc light [context]` | Channel a random Light line right now. Optional context: `combat`, `kill`, `loot`, `levelup`, `mount`. |
| `/pc flavor on\|off` | Toggle random flavor lines on or off. |
| `/pc channel say\|emote\|self` | Set where flavor lines are output: `/say`, `/emote`, or local chat frame only. |
| `/pc chance <1-100>` | Set the per-event chance (in percent) that a flavor line fires. |
| `/pc toggle` | Enable or disable the whole addon. |
| `/pc status` | Show all current settings. |
| `/pc config` | Open the in-game Settings panel (alias: `/pc options`). |
| `/pc minimap show\|hide` | Show or hide the minimap button. |
| `/pc help` | Print this command list. |

### Examples

```
/pc For the Light, brothers! (custom message to all paladins)
/pc who
/pc light combat
/pc flavor on
/pc channel emote
/pc chance 10
/pc config
/pc minimap hide
```

### Minimap Button

- **Left-click** — open the Settings panel.
- **Right-click** — channel a random Light line immediately.
- **Drag** — reposition the button around the minimap edge. Position is saved across sessions.

---

## Interface Version

The `.toc` file declares:

```
## Interface: 120000
```

This corresponds to **WoW: Midnight 12.0.0**. To confirm the live build number for your client, run this in-game:

```lua
/run print((select(4, GetBuildInfo())))
```

For example, if the output is `120005`, update the `.toc` line to:

```
## Interface: 120005
```

Then reload the UI (`/reload`).

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Addon doesn't appear in AddOns list | Tick **"Load out of date AddOns"** on the character select screen. |
| Comms / flavor silent | Only paladins participate. Non-paladin characters load the addon but stay silent. |
| Can't see other paladins | Wait ~5 seconds after login for the network handshake. Both players must be online and running the addon. |
| Cross-realm paladin | If you're in different realms, join a party or raid together — the fallback transport uses group channels which work cross-realm. |
| Interface version mismatch | Run `/run print((select(4, GetBuildInfo())))` and bump `## Interface:` in the `.toc` to match. |
| Settings panel doesn't open | Try `/pc config`. If it still fails, use slash commands to configure the addon. |
| Minimap button missing | Type `/pc minimap show` to restore it. |

---

## License

MIT — see repository root for details.
