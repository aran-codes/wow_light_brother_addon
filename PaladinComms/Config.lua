-- PaladinComms: Config
-- Slash-command UX for talking to paladins and tuning flavor.

local ADDON_NAME, PC = ...

local Config = {}
PC.Config = Config

local function usage()
    PC:Print("Commands:")
    PC:Print("  |cffffd100/pc <message>|r  -- say something to all paladins running the addon")
    PC:Print("  |cffffd100/pc who|r         -- list paladins currently online")
    PC:Print("  |cffffd100/pc light|r       -- channel a random Light line right now")
    PC:Print("  |cffffd100/pc flavor on|off|r -- toggle random flavor lines")
    PC:Print("  |cffffd100/pc channel say|emote|self|r -- where flavor lines go")
    PC:Print("  |cffffd100/pc chance <1-100>|r -- flavor chance per event (percent)")
    PC:Print("  |cffffd100/pc toggle|r       -- enable/disable the whole addon")
    PC:Print("  |cffffd100/pc status|r       -- show current settings")
    PC:Print("  |cffffd100/pc config|r       -- open the Settings panel (alias: /pc options)")
    PC:Print("  |cffffd100/pc minimap show|hide|r -- show or hide the minimap button")
end

function Config:HandleSlash(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""
    rest = rest or ""

    if cmd == "" or cmd == "help" then
        usage()

    elseif cmd == "who" or cmd == "online" then
        local online = PC.Comms:GetOnline()
        if #online == 0 then
            PC:Print("No other paladins detected yet. (They must be online and running PaladinComms.)")
        else
            PC:Print(("Paladins online (%d): %s"):format(#online, table.concat(online, ", ")))
        end

    elseif cmd == "light" then
        PC.Flavor:Force(rest ~= "" and rest:lower() or "generic")

    elseif cmd == "flavor" then
        local v = rest:lower()
        if v == "on" then
            PC.db.flavorEnabled = true;  PC:Print("Random flavor: |cff80ff80ON|r")
        elseif v == "off" then
            PC.db.flavorEnabled = false; PC:Print("Random flavor: |cffff6060OFF|r")
        else
            PC:Print("Use |cffffd100/pc flavor on|r or |cffffd100/pc flavor off|r")
        end

    elseif cmd == "channel" then
        local v = rest:lower()
        if v == "say" or v == "emote" or v == "self" then
            PC.db.flavorChannel = v:upper()
            PC:Print("Flavor channel set to |cffffd100" .. v:upper() .. "|r")
        else
            PC:Print("Use |cffffd100/pc channel say|emote|self|r")
        end

    elseif cmd == "chance" then
        local n = tonumber(rest)
        if n and n >= 1 and n <= 100 then
            PC.db.flavorChance = n / 100
            PC:Print(("Flavor chance set to |cffffd100%d%%|r per event."):format(n))
        else
            PC:Print("Use |cffffd100/pc chance <1-100>|r")
        end

    elseif cmd == "toggle" then
        PC.db.enabled = not PC.db.enabled
        PC:Print("Addon is now " .. (PC.db.enabled and "|cff80ff80ENABLED|r" or "|cffff6060DISABLED|r"))

    elseif cmd == "status" then
        PC:Print("Status:")
        PC:Print("  enabled:        " .. tostring(PC.db.enabled))
        PC:Print("  flavor:         " .. tostring(PC.db.flavorEnabled))
        PC:Print("  flavor channel: " .. tostring(PC.db.flavorChannel))
        PC:Print(("  flavor chance:  %d%%"):format(math.floor((PC.db.flavorChance or 0) * 100 + 0.5)))
        PC:Print(("  flavor cd:      %ds"):format(PC.db.flavorCooldown or 0))
        PC:Print("  is paladin:     " .. tostring(PC.isPaladin))

    elseif cmd == "config" or cmd == "options" then
        if PC.Options and PC.Options.Open then
            PC.Options:Open()
        else
            PC:Print("Settings panel not available yet. Use |cffffd100/pc help|r for slash commands.")
        end

    elseif cmd == "minimap" then
        local v = rest:lower()
        if v == "show" then
            if PC.Minimap and PC.Minimap.SetShown then
                PC.Minimap:SetShown(true)
                PC:Print("Minimap button: |cff80ff80shown|r")
            end
        elseif v == "hide" then
            if PC.Minimap and PC.Minimap.SetShown then
                PC.Minimap:SetShown(false)
                PC:Print("Minimap button: |cffff6060hidden|r")
            end
        else
            PC:Print("Use |cffffd100/pc minimap show|r or |cffffd100/pc minimap hide|r")
        end

    else
        -- Anything else is treated as a message to broadcast to paladins.
        PC.Comms:Broadcast(msg)
    end
end
