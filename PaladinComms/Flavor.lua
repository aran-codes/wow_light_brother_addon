-- PaladinComms: Flavor
-- Randomly channels the Light with brotherly / paladin one-liners.

local ADDON_NAME, PC = ...

local Flavor = {}
PC.Flavor = Flavor

-- Light-brother / paladin flavor pools, keyed by context.
Flavor.lines = {
    generic = {
        "For the Light, brother!",
        "Stay righteous, brother.",
        "The Light shines upon us this day.",
        "By the Light, justice will be served.",
        "Walk with the Light, brother.",
        "Another day in service to the Light.",
        "Light give me strength.",
        "We are but vessels of the Light, brother.",
        "Hold the line -- the Light is with us.",
        "May the Light watch over you, brother.",
    },
    combat = {
        "By the Light, justice is served!",
        "Feel the Light's wrath!",
        "Repent, foul creature!",
        "The Light shall purge you!",
        "Stand and face the Light!",
        "No mercy for the wicked!",
        "Your darkness ends here, brother stands ready!",
    },
    kill = {
        "Cleansed by the Light.",
        "Justice, swift and bright.",
        "One less shadow upon the world.",
        "The Light claims another, brother.",
        "Purged. As it should be.",
    },
    loot = {
        "The Light provides, brother.",
        "A righteous reward.",
        "Even treasure bends to the Light.",
        "Spoils worthy of a paladin.",
    },
    levelup = {
        "The Light makes me stronger, brother!",
        "I grow ever closer to the Light!",
        "Another step on the righteous path.",
    },
    mount = {
        "Ride with the Light, brother!",
        "My steed and I serve the Light.",
        "Onward, in the Light's name!",
    },
}

local function Pick(pool)
    if not pool or #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

-- Emit a line through the configured channel.
function Flavor:Say(line)
    if not line then return end
    local mode = PC.db.flavorChannel
    if mode == "SAY" then
        SendChatMessage(line, "SAY")
    elseif mode == "EMOTE" then
        SendChatMessage(line, "EMOTE")
    else -- SELF: just our chat frame, no one else sees it
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[Light]|r " .. line)
    end
end

-- Gate: respects toggle, class, per-event chance and a shared cooldown.
Flavor.lastSpoke = 0
function Flavor:Maybe(context)
    if not PC.isPaladin then return end
    if not PC.db.enabled or not PC.db.flavorEnabled then return end

    local now = GetTime()
    if now - self.lastSpoke < (PC.db.flavorCooldown or 90) then return end
    if math.random() > (PC.db.flavorChance or 0.06) then return end

    local pool = self.lines[context] or self.lines.generic
    local line = Pick(pool) or Pick(self.lines.generic)
    if line then
        self.lastSpoke = now
        self:Say(line)
    end
end

-- Force a line immediately (used by /pc light), ignoring chance/cooldown.
function Flavor:Force(context)
    if not PC.isPaladin then
        PC:Print("Only paladins may channel the Light, brother.")
        return
    end
    local pool = self.lines[context] or self.lines.generic
    self:Say(Pick(pool) or Pick(self.lines.generic))
    self.lastSpoke = GetTime()
end

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
