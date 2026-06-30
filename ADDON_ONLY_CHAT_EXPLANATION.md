# PaladinComms Addon-Only Chat: Concrete Walkthrough

If you want the short version first: **PaladinComms messages do not appear in WoW's normal chat window as real channel chat.** They travel as addon messages, and only PaladinComms clients listening for the `PALCOMMS` prefix decode and display them.

So when two paladins talk over PaladinComms, the **game chat system is just carrying invisible addon data**, and the **addon itself decides what to render** in its own display style.

---

## The simple scenario

Let's use the same two paladins all the way through:

- **Thrall-Area52**
- **Uther-Area52**

Both are on the same realm and both are running **PaladinComms**.

Thrall types:

```text
/pc Hey brother, the Light is with us!
```

Now let's walk through exactly what happens.

---

## Step-by-step: what happens when Thrall sends the message

### 1. The slash command routes the text into PaladinComms

`/pc` is handled by the addon, and the message text is passed to `PC.Comms:Broadcast(...)`.

Thrall is **not** sending normal `/say`, `/yell`, `/guild`, or `/party` text here.

He is sending **addon data**.

### 2. The addon constructs the addon payload

PaladinComms frames addon messages as:

```text
protocol version + unit separator + message type + unit separator + payload
```

So Thrall's message becomes:

```text
1\031CHAT\031Hey brother, the Light is with us!
```

That means:

- `1` = protocol version
- `CHAT` = message type
- `Hey brother, the Light is with us!` = the actual message payload
- `\031` = the unit separator character used to split the fields back apart later

### 3. The addon sends it over the hidden PaladinCommsNet channel

PaladinComms first tries to use its hidden custom channel, `PaladinCommsNet`.

Under the hood, the send looks like this shape:

```lua
C_ChatInfo.SendAddonMessage("PALCOMMS", body, "CHANNEL", channelIndex)
```

Where:

- `"PALCOMMS"` is the registered addon prefix
- `body` is `"1\031CHAT\031Hey brother, the Light is with us!"`
- `"CHANNEL"` means it is being routed over a custom chat channel transport
- `channelIndex` is the live index of the hidden `PaladinCommsNet` channel

So yes: the message is riding over a channel.

But crucially, it is **not** a normal visible chat line on that channel.

It is an **addon message** that is only delivered to clients listening for the `PALCOMMS` prefix.

### 4. What Thrall sees

Thrall still gets immediate feedback, because the addon locally echoes the message back into his chat frame.

That echo is produced by the addon itself via `DEFAULT_CHAT_FRAME:AddMessage(...)` with the styled `[Paladin]` tag.

In the current implementation, the sender echo is rendered as:

```text
[Paladin] you: Hey brother, the Light is with us!
```

So Thrall sees the message because **his own addon draws it locally**. He is not seeing a normal chat-channel line from WoW.

### 5. What Uther sees

Because Uther is online on the same realm and running PaladinComms, his client receives the addon payload through the `CHAT_MSG_ADDON` event.

His addon decodes the message, sees that it is a `CHAT` message, and renders it with `Comms:Display(...)`.

So Uther sees something like:

```text
[Paladin] Thrall-Area52: Hey brother, the Light is with us!
```

Again, that line appears because **Uther's addon chooses to display it**.

### 6. What a non-addon paladin sees

**Nothing. Zero.**

Even if another paladin manually does:

```text
/join PaladinCommsNet
```

They still do **not** see the addon traffic in their regular chat window.

Why?

Because addon-prefixed traffic is delivered to the addon event system and stripped from the visible chat UI client-side. To a non-addon player, the channel looks empty aside from ordinary server/channel notices.

### 7. What a player on a different realm sees

If they are not sharing the same realm-scoped custom channel, they see **nothing** from `PaladinCommsNet`.

Custom channels are realm-scoped.

However, if Thrall and Uther are grouped together cross-realm, PaladinComms can still work because it falls back to addon messaging over group transports such as `PARTY`, `RAID`, or `INSTANCE_CHAT` when the hidden channel is unavailable.

That fallback is still addon-only and still invisible to non-addon users.

---

## Why there are zero normal chat-window messages

This is the key distinction.

### Normal WoW chat

Traditional chat like:

- `/say`
- `/yell`
- `/guild`
- `/party`
- `/emote`

creates visible chat output that WoW renders into chat windows for everyone who can hear that channel.

### Addon messaging

PaladinComms uses `CHAT_MSG_ADDON`, which is a **separate event system**.

That means:

- the game transports the addon payload
- other clients listening for the registered prefix receive it
- normal chat rendering does **not** happen
- there is no ordinary visible channel message object being printed into chat windows

So by joining a hidden custom channel and sending **addon messages instead of normal text chat**, PaladinComms gets both of these properties at once:

1. **Only addon clients receive and decode the traffic**
2. **The traffic stays invisible to WoW's regular chat UI**

---

## What the chat windows look like

Here is the concrete effect from the player's point of view.

### Thrall's chat window

```text
+--------------------------------------------------------------+
| [Paladin] you: Hey brother, the Light is with us!            |
+--------------------------------------------------------------+
```

That line is the local PaladinComms echo.

### Uther's chat window

```text
+--------------------------------------------------------------+
| [Paladin] Thrall-Area52: Hey brother, the Light is with us!  |
+--------------------------------------------------------------+
```

That line is Uther's addon rendering the decoded addon message.

### Offline player's chat window on the same realm

```text
+--------------------------------------------------------------+
|                                                              |
|   (nothing related to the paladins' addon chat appears)      |
|                                                              |
+--------------------------------------------------------------+
```

No PaladinComms conversation appears there at all.

### Non-addon paladin who manually joined `/join PaladinCommsNet`

```text
+--------------------------------------------------------------+
| [4. PaladinCommsNet]                                         |
|                                                              |
|   (channel looks empty; no addon traffic is shown)           |
|                                                              |
+--------------------------------------------------------------+
```

They may see generic channel UI behavior, but **not** the addon conversation itself.

---

## Contrast with the fallback transports

If `JoinTemporaryChannel("PaladinCommsNet")` fails or the hidden channel is otherwise unavailable, the addon falls back to normal addon transports like:

- `INSTANCE_CHAT`
- `RAID`
- `PARTY`
- `GUILD`

That fallback changes the **network path**, but not the **visibility model**.

So even when the addon uses `GUILD` or `PARTY` as transport, the payload is still sent with `C_ChatInfo.SendAddonMessage(...)`, which means:

- addon users still receive it invisibly through `CHAT_MSG_ADDON`
- non-addon guild members or party members still do **not** see the message in their chat window

The limitation in fallback mode is scope, not privacy.

- `PaladinCommsNet` hidden channel: broader same-realm addon network
- `PARTY` / `RAID` / `GUILD` fallback: still invisible, but limited to that shared group/guild context

This is why cross-realm grouped paladins can still hear each other privately: the addon can use `PARTY` or related group transports even when the custom channel is not shared.

---

## Important caveat: the flavor lines *are* visible

This part is separate from PaladinComms network chat.

The random "Light brother" flavor lines use normal WoW chat behavior when configured that way.

For example, if the addon is set to `/emote` or `/say`, those are ordinary visible chat messages and **everyone around you can see them**.

So:

- **Paladin-only network chat** = invisible addon traffic
- **Flavor lines using `/say` or `/emote`** = normal visible WoW chat

If you want flavor lines to stay private too, set them to:

```text
/pc channel self
```

That makes the flavor lines render only in your own addon/chat frame instead of broadcasting them to nearby players.

---

## The exact code doing the work

Here are the two key pieces from `PaladinComms/Comms.lua`.

### `RawSend`

This is the low-level function that frames the message body and hands it to WoW's addon messaging API.

```lua
local function RawSend(msgType, payload, channel, target)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local body = table.concat({ PROTO, msgType, payload or "" }, SEP)
    if channel == "WHISPER" and target then
        C_ChatInfo.SendAddonMessage(PREFIX, body, "WHISPER", target)
    elseif channel == "CHANNEL" and target then
        C_ChatInfo.SendAddonMessage(PREFIX, body, "CHANNEL", target)
    elseif channel then
        C_ChatInfo.SendAddonMessage(PREFIX, body, channel)
    end
end
```

For Thrall's example message, `body` becomes:

```text
1\031CHAT\031Hey brother, the Light is with us!
```

### `OnAddonMessage`

This is the receive path. It listens for addon messages, splits the payload on the unit separator, and only displays `CHAT` traffic through the addon UI.

```lua
local function OnAddonMessage(prefix, message, _, sender)
    if prefix ~= PREFIX then return end
    if not PC.isPaladin then return end

    local proto, msgType, payload = strsplit(SEP, message, 3)
    if proto ~= PROTO then return end

    -- Ignore our own broadcasts (we already echoed locally).
    if Ambiguate(sender, "none") == Ambiguate(PC.playerName, "none") then
        TouchRoster(PC.playerName)
        return
    end

    TouchRoster(sender)

    if msgType == "CHAT" then
        Comms:Display(sender, payload, false)
    elseif msgType == "HELLO" then
        if PC.db.announceJoin then
            PC:Print(("|cff80ff80%s|r joined the paladin network."):format(Ambiguate(sender, "short")))
        end
        RawSend("HERE", "", "WHISPER", sender)
    elseif msgType == "PING" or msgType == "HERE" then
        -- presence only; roster already touched above
    end
end
```

That is the heart of the addon-only behavior:

- receive addon payload
- decode it
- if it is a `CHAT` message, draw it with the addon
- otherwise treat it as control traffic like `HELLO`, `PING`, or `HERE`

At no point does the addon rely on normal visible channel text for the conversation itself.

---

## Final mental model

A good way to picture PaladinComms is this:

- **WoW channel transport** carries the packet
- **`PALCOMMS` addon prefix** marks it as addon traffic
- **`CHAT_MSG_ADDON`** delivers it to addon clients only
- **PaladinComms** decides whether to render it as a pretty `[Paladin]` line

So when Thrall says:

```text
/pc Hey brother, the Light is with us!
```

the message is **not** showing up in open chat and then being hidden.

It is **never a normal visible chat line in the first place**.

It is invisible addon traffic that only becomes visible when another PaladinComms client chooses to display it.
