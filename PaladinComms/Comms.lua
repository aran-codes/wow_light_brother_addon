-- PaladinComms: Comms
-- Paladin-only chat that is INVISIBLE to non-addon users.
--
-- How invisibility works:
--   We join a hidden custom channel ("PaladinCommsNet") via JoinTemporaryChannel,
--   then send addon messages over it with C_ChatInfo.SendAddonMessage(..., "CHANNEL", idx).
--   Addon messages are delivered to the CHAT_MSG_ADDON event ONLY -- they never render
--   in any player's chat window, even for people without the addon. Because it is a
--   custom channel (not GUILD/PARTY), the network is effectively server-wide.
--
-- Fallback:
--   If the hidden channel cannot be joined for any reason, we fall back to addon
--   messages over GUILD/PARTY/RAID/INSTANCE_CHAT so the feature still works.

local ADDON_NAME, PC = ...

local Comms = {}
PC.Comms = Comms

local PREFIX        = "PALCOMMS"          -- addon message prefix (<=16 chars)
local PROTO         = "1"                 -- protocol version
local CHANNEL_NAME  = "PaladinCommsNet"   -- hidden custom channel name
local SEP           = "\031"              -- unit separator for payload framing
local HEARTBEAT_SEC = 60                  -- presence ping interval
local STALE_SEC     = 150                 -- drop roster entries older than this
local JOIN_DELAY    = 5                   -- let chat settle before joining

Comms.roster      = {}     -- [playerName] = { lastSeen = GetTime(), name = ... }
Comms.channelIndex = 0      -- 0 means "not on the hidden channel"

-- Resolve the live index of our hidden channel (0 if not joined).
local function ChannelIndex()
    local idx = GetChannelName(CHANNEL_NAME)
    return idx or 0
end

-- Decide how to distribute a message right now.
-- Prefer the hidden channel; otherwise fall back to group/guild.
local function PreferredTarget()
    local idx = ChannelIndex()
    if idx and idx > 0 then
        return "CHANNEL", idx
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    if IsInGuild() then return "GUILD" end
    return nil
end

-- Low-level send. type/payload are joined with a unit separator.
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

-- Send a control/presence message to the whole network.
local function SendToNetwork(msgType, payload)
    local channel, target = PreferredTarget()
    if channel then
        RawSend(msgType, payload, channel, target)
    end
end

-- Public: broadcast a chat line to fellow paladins.
function Comms:Broadcast(text)
    if not PC.isPaladin or not PC.db.enabled then return end
    if not text or text:gsub("%s", "") == "" then return end

    local channel, target = PreferredTarget()
    if not channel then
        PC:Print("|cffff6060Cannot reach the paladin network yet.|r Try again in a few seconds, or join a guild/party as a fallback.")
        return
    end
    RawSend("CHAT", text, channel, target)
    -- Echo locally so the sender sees their own message styled.
    self:Display(PC.playerName, text, true)
end

-- Render an incoming/outgoing paladin message into the chat frame.
function Comms:Display(sender, text, isSelf)
    local short = Ambiguate(sender, "short")
    local tag   = isSelf and "|cff80ff80you|r" or ("|cffF58CBA" .. short .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage(("|cffffd100[Paladin]|r %s: %s"):format(tag, text))
end

-- Roster bookkeeping ---------------------------------------------------------
local function TouchRoster(sender)
    Comms.roster[sender] = Comms.roster[sender] or { name = sender }
    Comms.roster[sender].lastSeen = GetTime()
end

local function PruneRoster()
    local now = GetTime()
    for name, info in pairs(Comms.roster) do
        if now - (info.lastSeen or 0) > STALE_SEC then
            Comms.roster[name] = nil
        end
    end
end

function Comms:GetOnline()
    PruneRoster()
    local list = {}
    for name in pairs(self.roster) do
        list[#list + 1] = Ambiguate(name, "short")
    end
    table.sort(list)
    return list
end

-- Incoming addon message handler --------------------------------------------
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

-- Keep the hidden channel out of the visible chat UI -------------------------
-- We never want the user to see channel join notices or stray channel text.
local function SuppressChannelNoise()
    -- Remove the channel from every chat frame's subscribed channel list so its
    -- NOTICE/þmessages do not render. Addon messages are unaffected.
    for i = 1, NUM_CHAT_WINDOWS do
        ChatFrame_RemoveChannel(_G["ChatFrame" .. i], CHANNEL_NAME)
    end
end

-- Filter out any channel-notice spam for our hidden channel, just in case.
local function InstallChatFilters()
    if not ChatFrame_AddMessageEventFilter then return end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", function(_, _, _, _, _, _, _, _, channelName)
        if channelName == CHANNEL_NAME then return true end
        return false
    end)
    -- Hide any plain text that might arrive on the channel from non-addon clients.
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", function(_, _, _, _, _, _, _, _, channelName)
        if channelName == CHANNEL_NAME then return true end
        return false
    end)
end

-- Join the hidden channel (silently) and tidy the UI.
local function JoinHiddenChannel()
    if not JoinTemporaryChannel then return end
    JoinTemporaryChannel(CHANNEL_NAME)
    Comms.channelIndex = ChannelIndex()
    SuppressChannelNoise()
end

-- Periodic presence heartbeat ------------------------------------------------
local hbFrame = CreateFrame("Frame")
local hbElapsed = 0
local function StartHeartbeat()
    hbFrame:SetScript("OnUpdate", function(_, dt)
        hbElapsed = hbElapsed + dt
        if hbElapsed >= HEARTBEAT_SEC then
            hbElapsed = 0
            -- Re-resolve channel index (it can change if other channels move).
            Comms.channelIndex = ChannelIndex()
            if PC.db.enabled and PC.isPaladin then
                SendToNetwork("PING", "")
            end
            PruneRoster()
        end
    end)
end

function Comms:Init()
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then
        PC:Print("|cffff6060This client does not support addon messaging.|r")
        return
    end

    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    InstallChatFilters()

    local evt = CreateFrame("Frame")
    evt:RegisterEvent("CHAT_MSG_ADDON")
    evt:SetScript("OnEvent", function(_, _, ...) OnAddonMessage(...) end)

    if PC.isPaladin then
        TouchRoster(PC.playerName)
        StartHeartbeat()

        -- Join the hidden channel after a short delay so the chat system is ready,
        -- then announce ourselves to the network.
        C_Timer.After(JOIN_DELAY, function()
            JoinHiddenChannel()
            if PC.db.enabled then
                SendToNetwork("HELLO", "")
            end
        end)
    end
end
