-- PaladinComms: Options
-- In-game Settings panel wired to PC.db. Works with the modern Settings API
-- (Midnight/DF+) and falls back to the legacy InterfaceOptions panel or plain
-- slash-command hints.

local ADDON_NAME, PC = ...

local Options = {}
PC.Options = Options

-- Internal references populated by Init().
local _panel      = nil   -- the canvas Frame
local _categoryID = nil   -- modern Settings category handle

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

-- Spacing constants for the panel layout.
local PAD_X  = 16
local PAD_Y  = 16
local ROW_H  = 26

-- Create a standard checkbox tied to a PC.db boolean field.
local function MakeCheckbox(parent, label, field, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", PAD_X, -y)
    cb:SetSize(24, 24)

    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb.OnRefresh = function()
        cb:SetChecked(PC.db[field] and true or false)
    end
    cb:SetScript("OnClick", function(self)
        PC.db[field] = self:GetChecked() and true or false
    end)
    return cb
end

-- Create a label FontString.
local function MakeLabel(parent, labelText, y, isTitle)
    local fs = parent:CreateFontString(nil, "ARTWORK", isTitle and "GameFontNormalLarge" or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", PAD_X, -y)
    fs:SetText(labelText)
    return fs
end

-- Create a slider (horizontal) tied to a PC.db numeric field.
-- displayMult: multiply stored value by this for display (e.g. 100 for percent stored as 0..1).
local function MakeSlider(parent, label, field, minVal, maxVal, step, displayMult, suffix, y)
    local mult = displayMult or 1

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(300, 50)
    container:SetPoint("TOPLEFT", PAD_X, -y)

    local title = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local sl = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", 0, -16)
    sl:SetSize(260, 16)
    sl:SetMinMaxValues(minVal, maxVal)
    sl:SetValueStep(step)
    sl:SetObeyStepOnDrag(true)

    -- Template creates _Low/_High/_Text children.
    local low  = _G[sl:GetName() and sl:GetName() .. "Low"]  or container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    local high = _G[sl:GetName() and sl:GetName() .. "High"] or container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    if low  and low.SetText  then low:SetText(tostring(minVal) .. (suffix or ""))  end
    if high and high.SetText then high:SetText(tostring(maxVal) .. (suffix or "")) end

    local valLabel = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valLabel:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 0, -2)

    local function UpdateLabel(val)
        valLabel:SetText(tostring(math.floor(val * mult + 0.5)) .. (suffix or ""))
    end

    sl.OnRefresh = function()
        local stored = PC.db[field] or minVal
        sl:SetValue(stored * mult)
        UpdateLabel(stored * mult)
    end

    sl:SetScript("OnValueChanged", function(self, val)
        UpdateLabel(val)
        PC.db[field] = val / mult
    end)

    container.slider = sl
    container.OnRefresh = function()
        sl.OnRefresh()
    end
    return container
end

-- Create a simple dropdown for flavorChannel (EMOTE / SAY / SELF).
local function MakeChannelDropdown(parent, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", PAD_X, -y)
    label:SetText("Flavor output channel:")

    -- Use simple radio-style buttons so we have no UIDropDownMenu dependency.
    local choices = { "EMOTE", "SAY", "SELF" }
    local btns = {}
    for i, choice in ipairs(choices) do
        local rb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        rb:SetPoint("TOPLEFT", PAD_X + (i - 1) * 90, -(y + 20))
        rb:SetSize(20, 20)

        local txt = rb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", rb, "RIGHT", 2, 0)
        txt:SetText(choice)

        rb.choice = choice
        rb:SetScript("OnClick", function(self)
            PC.db.flavorChannel = self.choice
            -- Uncheck siblings.
            for _, b in ipairs(btns) do
                b:SetChecked(b.choice == self.choice)
            end
        end)
        btns[i] = rb
    end

    local container = {}
    container.OnRefresh = function()
        local cur = PC.db.flavorChannel or "EMOTE"
        for _, b in ipairs(btns) do
            b:SetChecked(b.choice == cur)
        end
    end
    return container
end

-------------------------------------------------------------------------------
-- Build the panel canvas
-------------------------------------------------------------------------------

local function BuildPanel()
    local panel = CreateFrame("Frame", "PaladinCommsOptionsPanel", UIParent)
    panel:Hide()

    local controls = {}  -- list of objects with OnRefresh

    -- Title
    MakeLabel(panel, "PaladinComms", PAD_Y, true)

    -- Subtitle
    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", PAD_X, -(PAD_Y + 26))
    sub:SetText("Addon-only paladin chat network and Light flavor lines.")

    local y = PAD_Y + 58

    -- Checkboxes
    local cbEnabled = MakeCheckbox(panel, "Enable addon",                       "enabled",       y)
    controls[#controls + 1] = cbEnabled
    y = y + ROW_H

    local cbFlavor  = MakeCheckbox(panel, "Enable random flavor lines",          "flavorEnabled", y)
    controls[#controls + 1] = cbFlavor
    y = y + ROW_H

    local cbAnnounce = MakeCheckbox(panel, "Announce when paladins join",        "announceJoin",  y)
    controls[#controls + 1] = cbAnnounce
    y = y + ROW_H + 8

    -- Channel radio buttons
    local chDrop = MakeChannelDropdown(panel, y)
    controls[#controls + 1] = chDrop
    y = y + 52

    -- Chance slider (stored 0..1, displayed 1..100%)
    local slChance = MakeSlider(panel, "Flavor chance per event:", "flavorChance", 1, 100, 1, 100, "%", y)
    controls[#controls + 1] = slChance
    y = y + 58

    -- Cooldown slider (stored as seconds, displayed as seconds)
    local slCD = MakeSlider(panel, "Flavor cooldown:", "flavorCooldown", 10, 300, 5, 1, "s", y)
    controls[#controls + 1] = slCD
    y = y + 66

    -- Separator line
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetSize(340, 1)
    sep:SetPoint("TOPLEFT", PAD_X, -y)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    y = y + 12

    -- "Channel the Light now" button
    local btnLight = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnLight:SetSize(180, 24)
    btnLight:SetPoint("TOPLEFT", PAD_X, -y)
    btnLight:SetText("Channel the Light now")
    btnLight:SetScript("OnClick", function()
        if PC.Flavor and PC.Flavor.Force then
            PC.Flavor:Force("generic")
        end
    end)
    y = y + 32

    -- "Who's online" button
    local btnWho = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnWho:SetSize(180, 24)
    btnWho:SetPoint("TOPLEFT", PAD_X, -y)
    btnWho:SetText("Who's online")
    btnWho:SetScript("OnClick", function()
        if PC.Comms and PC.Comms.GetOnline then
            local online = PC.Comms:GetOnline()
            if #online == 0 then
                PC:Print("No other paladins detected yet.")
            else
                PC:Print(("Paladins online (%d): %s"):format(#online, table.concat(online, ", ")))
            end
        end
    end)

    -- Refresh all controls when the panel is shown.
    panel:SetScript("OnShow", function()
        for _, ctrl in ipairs(controls) do
            if ctrl.OnRefresh then ctrl:OnRefresh() end
        end
    end)

    return panel
end

-------------------------------------------------------------------------------
-- Registration helpers (modern API or legacy fallback)
-------------------------------------------------------------------------------

local function RegisterModern(panel)
    -- Midnight / DF modern Settings API.
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "PaladinComms")
        _categoryID = category
        Settings.RegisterAddOnCategory(category)
        return true
    end
    return false
end

local function RegisterLegacy(panel)
    if InterfaceOptions_AddCategory then
        panel.name = "PaladinComms"
        InterfaceOptions_AddCategory(panel)
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Public interface
-------------------------------------------------------------------------------

function Options:Open()
    if _categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(_categoryID)
    elseif _panel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(_panel)
        InterfaceOptionsFrame_OpenToCategory(_panel)  -- double-call workaround
    elseif _panel then
        -- Neither modern nor legacy registered; just show the raw frame.
        if _panel:IsShown() then
            _panel:Hide()
        else
            _panel:Show()
        end
    else
        PC:Print("Settings panel unavailable. Use |cffffd100/pc help|r for slash commands.")
    end
end

function Options:Init()
    _panel = BuildPanel()

    if not RegisterModern(_panel) then
        if not RegisterLegacy(_panel) then
            -- No registration API; the panel can still be shown manually via Open().
            _panel:SetParent(UIParent)
        end
    end
end
