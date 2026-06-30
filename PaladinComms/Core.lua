-- PaladinComms: Core
-- Bootstraps the addon, wires up events, and exposes slash commands.

local ADDON_NAME, PC = ...

-- Namespace defaults
PC.version    = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "1.0.0"
PC.playerName = nil   -- set on login (name-realm)
PC.isPaladin  = false

-- Default saved variables
local defaults = {
    enabled        = true,
    flavorEnabled  = true,
    flavorChance   = 0.06,   -- 6% chance per eligible event
    flavorCooldown = 90,     -- seconds between flavor lines
    flavorChannel  = "EMOTE",-- EMOTE | SAY | SELF (chat frame only)
    announceJoin   = true,   -- greet the paladin network on login
    minimap        = { angle = 200, hide = false },
}

local function ApplyDefaults(db, src)
    for k, v in pairs(src) do
        if db[k] == nil then
            db[k] = v
        elseif type(v) == "table" and type(db[k]) == "table" then
            -- Recursively merge nested tables (e.g. minimap).
            ApplyDefaults(db[k], v)
        end
    end
    return db
end

-- Central event frame
local frame = CreateFrame("Frame", "PaladinCommsFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == ADDON_NAME then
            PaladinCommsDB = ApplyDefaults(PaladinCommsDB or {}, defaults)
            PC.db = PaladinCommsDB
        end

    elseif event == "PLAYER_LOGIN" then
        -- Resolve identity
        local name, realm = UnitFullName("player")
        realm = (realm and realm ~= "" and realm) or GetNormalizedRealmName()
        PC.playerName = name .. "-" .. (realm or "")

        -- Class check: only paladins participate
        local _, classFile = UnitClass("player")
        PC.isPaladin = (classFile == "PALADIN")

        if PC.Comms and PC.Comms.Init then PC.Comms:Init() end
        if PC.Flavor and PC.Flavor.Init then PC.Flavor:Init() end
        if PC.Options and PC.Options.Init then PC.Options:Init() end
        if PC.Minimap and PC.Minimap.Init then PC.Minimap:Init() end

        if PC.isPaladin then
            PC:Print("Online. The Light guides our words. Type |cffffd100/pc|r for options.")
        else
            PC:Print("Loaded, but you are not a paladin -- comms and flavor are disabled for this character.")
        end
    end
end)

-- Pretty printer
local PREFIX = "|cffF58CBA[PaladinComms]|r "
function PC:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

-- Slash command: /pc and /paladincomms
SLASH_PALADINCOMMS1 = "/pc"
SLASH_PALADINCOMMS2 = "/paladincomms"
SlashCmdList["PALADINCOMMS"] = function(msg)
    if PC.Config and PC.Config.HandleSlash then
        PC.Config:HandleSlash(msg)
    end
end
