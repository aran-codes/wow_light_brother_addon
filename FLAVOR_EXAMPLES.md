# PaladinComms — Scenario-Based Flavor Lines

This document explains how the **automatic, context-triggered flavor lines** work in PaladinComms, with concrete examples and code references from `Flavor.lua`.

---

## 1. How Flavor Works: Automatic Trigger on Gameplay Events

The flavor system **requires no player action**. The addon registers listeners for gameplay events (entering combat, killing enemies, looting, leveling, mounting). When one of those events fires, the addon:

1. Checks that flavor is enabled and you are a Paladin.
2. **Rolls a random chance** (default 6%, configurable with `/pc chance 1-100`).
3. Checks that enough time has passed since the last line (**cooldown**, default 90 seconds).
4. If both the roll and the cooldown pass, it **automatically speaks a random phrase** from the matching context pool.

You do nothing — the paladin's faith in the Light just occasionally bursts out while you play.

---

## 2. Event Categories and What Triggers Them

| Context | WoW Event | When it fires |
|---------|-----------|---------------|
| **combat** | `PLAYER_REGEN_DISABLED` | You enter combat (start attacking or get attacked) |
| **kill** | `COMBAT_LOG_EVENT_UNFILTERED` (`PARTY_KILL`, you as source) | You land the killing blow on an enemy |
| **loot** | `LOOT_OPENED` | You open a loot window (corpse, chest, treasure) |
| **levelup** | `PLAYER_LEVEL_UP` | You gain a level |
| **mount** | `PLAYER_MOUNT_DISPLAY_CHANGED` (only when `IsMounted()` is true) | You mount up |
| **generic** | — | Fallback when no specific context applies |

---

## 3. Example Phrases by Context

### ⚔️ Combat Entry — when you start attacking

> *"By the Light, justice is served!"*  
> *"Feel the Light's wrath!"*  
> *"Repent, foul creature!"*  
> *"The Light shall purge you!"*  
> *"Stand and face the Light!"*  
> *"No mercy for the wicked!"*  
> *"Your darkness ends here, brother stands ready!"*

### 💀 Kill — after defeating an enemy

> *"Cleansed by the Light."*  
> *"Justice, swift and bright."*  
> *"One less shadow upon the world."*  
> *"The Light claims another, brother."*  
> *"Purged. As it should be."*

### 🎁 Loot — opening a loot window

> *"The Light provides, brother."*  
> *"A righteous reward."*  
> *"Even treasure bends to the Light."*  
> *"Spoils worthy of a paladin."*

### ✨ Level Up — gaining a level

> *"The Light makes me stronger, brother!"*  
> *"I grow ever closer to the Light!"*  
> *"Another step on the righteous path."*

### 🐴 Mount — mounting up

> *"Ride with the Light, brother!"*  
> *"My steed and I serve the Light."*  
> *"Onward, in the Light's name!"*

### 💬 Generic — fallback

> *"For the Light, brother!"*  
> *"Stay righteous, brother."*  
> *"The Light shines upon us this day."*  
> *"By the Light, justice will be served."*  
> *"Walk with the Light, brother."*  
> *"Another day in service to the Light."*  
> *"Light give me strength."*  
> *"We are but vessels of the Light, brother."*  
> *"Hold the line -- the Light is with us."*  
> *"May the Light watch over you, brother."*

---

## 4. How the Code Works

### Event registration (`Flavor.lua`)

The addon registers all events in `Flavor:Init()`, called once at login:

```lua
function Flavor:Init()
    if not PC.isPaladin then return end

    local evt = CreateFrame("Frame")
    evt:RegisterEvent("PLAYER_REGEN_DISABLED")        -- entered combat
    evt:RegisterEvent("PLAYER_LEVEL_UP")              -- leveled
    evt:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- mounted/dismounted
    evt:RegisterEvent("LOOT_OPENED")                  -- looting
    evt:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")  -- for kills by the player

    evt:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            Flavor:Maybe("combat")

        elseif event == "PLAYER_LEVEL_UP" then
            Flavor:Maybe("levelup")

        elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            if IsMounted() then Flavor:Maybe("mount") end

        elseif event == "LOOT_OPENED" then
            Flavor:Maybe("loot")

        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            local _, subEvent, _, sourceGUID = CombatLogGetCurrentEventInfo()
            if subEvent == "PARTY_KILL" and sourceGUID == UnitGUID("player") then
                Flavor:Maybe("kill")
            end
        end
    end)
end
```

### The `Maybe()` gate (`Flavor.lua`)

Every event funnels through `Maybe()`, which enforces the chance roll and cooldown before speaking:

```lua
Flavor.lastSpoke = 0
function Flavor:Maybe(context)
    if not PC.isPaladin then return end
    if not PC.db.enabled or not PC.db.flavorEnabled then return end

    local now = GetTime()
    if now - self.lastSpoke < (PC.db.flavorCooldown or 90) then return end  -- cooldown check
    if math.random() > (PC.db.flavorChance or 0.06) then return end         -- chance roll

    local pool = self.lines[context] or self.lines.generic
    local line = Pick(pool) or Pick(self.lines.generic)
    if line then
        self.lastSpoke = now
        self:Say(line)
    end
end
```

`math.random()` returns a float in `[0, 1)`. With the default `flavorChance` of `0.06`, roughly **6 out of every 100 eligible events** will produce a line. The rest are silently ignored.

---

## 5. Configuration

| Setting | Default | Command |
|---------|---------|---------|
| Flavor enabled | Yes (on by default) | `/pc flavor on` / `/pc flavor off` |
| Chance per event | 6% | `/pc chance 10` (sets to 10%) |
| Cooldown between lines | 90 seconds | `/pc cooldown 120` (sets to 120 s) |
| Output channel | EMOTE | `/pc channel emote` / `/pc channel say` / `/pc channel self` |

**Output channel behaviour:**

- `emote` (default) — sends `/emote <line>` — **everyone nearby sees** `[Your Name] emotes: Cleansed by the Light.`
- `say` — sends `/say <line>` — **everyone nearby sees** `[Your Name]: Cleansed by the Light.`
- `self` — prints only to your own chat frame as `[Light] Cleansed by the Light.` — **no one else sees it**.

---

## 6. Concrete Dungeon Scenario

Below is a step-by-step walkthrough of what happens as a Paladin runs a dungeon with default settings (6% chance, 90 s cooldown, emote channel).

```
T+0s    Paladin pulls a pack — combat starts.
        Event: PLAYER_REGEN_DISABLED → Flavor:Maybe("combat")
        Roll: math.random() = 0.42  |  threshold: 0.06
        0.42 > 0.06 → NO LINE. Nothing happens.

T+15s   Paladin kills the first enemy.
        Event: COMBAT_LOG_EVENT_UNFILTERED (PARTY_KILL, player is source)
              → Flavor:Maybe("kill")
        Cooldown: 15s since last spoke (0s) — 15 < 90 → BLOCKED.
        Wait, lastSpoke is 0 so (15 - 0 = 15) ... actually lastSpoke starts at 0
        and GetTime() starts counting from login, so the first eligible event
        passes the cooldown immediately after login.
        Roll: math.random() = 0.03  |  threshold: 0.06
        0.03 <= 0.06 → PASSES.
        Cooldown: (15 - 0) = 15 seconds since last spoke — actually on the
        very first line lastSpoke=0 so it always passes.
        Picks from kill pool → "Cleansed by the Light."
        Speaks: /emote Cleansed by the Light.
        lastSpoke = T+15s
        ──────────────────────────────────────────────────────────────
        Nearby players see:  [Paladin Name] emotes: Cleansed by the Light.
        ──────────────────────────────────────────────────────────────

T+20s   Paladin loots the corpse.
        Event: LOOT_OPENED → Flavor:Maybe("loot")
        Cooldown: 20-15 = 5s since last spoke — 5 < 90 → BLOCKED. No line.

T+45s   Paladin pulls the next pack — combat starts again.
        Event: PLAYER_REGEN_DISABLED → Flavor:Maybe("combat")
        Cooldown: 45-15 = 30s — 30 < 90 → BLOCKED. No line.

T+60s   Paladin kills another enemy.
        Event: PARTY_KILL → Flavor:Maybe("kill")
        Cooldown: 60-15 = 45s — 45 < 90 → BLOCKED. No line.

T+95s   Paladin loots again.
        Event: LOOT_OPENED → Flavor:Maybe("loot")
        Cooldown: 95-15 = 80s — 80 < 90 → BLOCKED. No line.

T+135s  Paladin kills another enemy.
        Event: PARTY_KILL → Flavor:Maybe("kill")
        Cooldown: 135-15 = 120s — 120 >= 90 → PASSES.
        Roll: math.random() = 0.02  |  threshold: 0.06
        0.02 <= 0.06 → PASSES.
        Picks from kill pool → "Justice, swift and bright."
        Speaks: /emote Justice, swift and bright.
        lastSpoke = T+135s
        ──────────────────────────────────────────────────────────────
        Nearby players see:  [Paladin Name] emotes: Justice, swift and bright.
        ──────────────────────────────────────────────────────────────
```

Two lines in ~2 minutes of active combat. At 6% chance and 90 s cooldown you can expect roughly **1–2 lines per 5–10 minutes** of active gameplay.

---

## 7. Why Automatic?

- **Immersion** — you're not commanding the paladin to speak; the character's faith in the Light occasionally bursts out naturally during meaningful gameplay moments.
- **Tied to gameplay events** — lines fire on combat, victory, loot, and travel — not random idle chatter.
- **Spam prevention** — the chance roll + cooldown together mean you'll hear a line occasionally, not constantly. At 6% / 90 s you can play for minutes without a line, then one appears at a dramatically appropriate moment.
- **Tunable** — if it's too chatty, lower the chance (`/pc chance 3`) or raise the cooldown (`/pc cooldown 180`). If you want it completely private, set `/pc channel self` and no one else will ever see a line.
