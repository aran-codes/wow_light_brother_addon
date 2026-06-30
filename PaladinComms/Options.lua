-- PaladinComms: Options
-- In-game Settings panel for configuring addon behavior.

local ADDON_NAME, PC = ...

local Options = {}
PC.Options = Options

local PANEL_NAME = "PaladinComms"

local function AttachTooltip(widget, title, body)
    if not widget or not widget.HookScript then return end

    widget:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or PANEL_NAME)
        if body and body ~= "" then
            GameTooltip:AddLine(body, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)

    widget:HookScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function ClampPercent(value)
    value = tonumber(value) or 15
    value = math.floor(value + 0.5)
    if value < 1 then value = 1 end
    if value > 100 then value = 100 end
    return value
end

local function ClampCooldown(value)
    value = tonumber(value) or 45
    value = math.floor((value / 5) + 0.5) * 5
    if value < 10 then value = 10 end
    if value > 300 then value = 300 end
    return value
end

local function PercentFromDB()
    return ClampPercent((PC.db and PC.db.flavorChance or 0.15) * 100)
end

local function CooldownFromDB()
    return ClampCooldown(PC.db and PC.db.flavorCooldown or 45)
end

local function CreateCheckbox(parent, label, tooltip, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    check.Text:SetText(label)
    check:SetScript("OnClick", onClick)
    AttachTooltip(check, label, tooltip)
    AttachTooltip(check.Text, label, tooltip)
    return check
end

local function CreateSlider(parent, name, label, minValue, maxValue, step, tooltip)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetWidth(300)

    slider.Text = _G[slider:GetName() .. "Text"]
    slider.Low = _G[slider:GetName() .. "Low"]
    slider.High = _G[slider:GetName() .. "High"]

    slider.Text:SetText(label)
    slider.Low:SetText(tostring(minValue))
    slider.High:SetText(tostring(maxValue))

    slider.ValueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slider.ValueText:SetPoint("LEFT", slider, "RIGHT", 16, 0)
    slider.ValueText:SetWidth(60)
    slider.ValueText:SetJustifyH("LEFT")

    AttachTooltip(slider, label, tooltip)
    AttachTooltip(slider.Text, label, tooltip)
    return slider
end

function Options:Refresh()
    if not self.panel or not self.panel.controls or not PC.db then return end

    local controls = self.panel.controls
    self.refreshing = true

    controls.enabled:SetChecked(PC.db.enabled)
    controls.flavorEnabled:SetChecked(PC.db.flavorEnabled)
    controls.announceJoin:SetChecked(PC.db.announceJoin)

    UIDropDownMenu_SetSelectedValue(controls.channel, PC.db.flavorChannel or "EMOTE")
    UIDropDownMenu_SetText(controls.channel, PC.db.flavorChannel or "EMOTE")

    local percent = PercentFromDB()
    controls.chance:SetValue(percent)
    controls.chance.ValueText:SetText(("%d%%"):format(percent))

    local cooldown = CooldownFromDB()
    controls.cooldown:SetValue(cooldown)
    controls.cooldown.ValueText:SetText(("%ds"):format(cooldown))

    self.refreshing = false
end

function Options:CreatePanel()
    if self.panel then
        return self.panel
    end

    local panel = CreateFrame("Frame", "PaladinCommsOptionsPanel", UIParent)
    panel.name = PANEL_NAME
    panel:Hide()

    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 16, -16)
    panel.title:SetText(PANEL_NAME)

    panel.subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
    panel.subtitle:SetWidth(560)
    panel.subtitle:SetJustifyH("LEFT")
    panel.subtitle:SetText("Configure addon-only paladin chat, automatic Light flavor, and quick actions. Open this panel from the minimap button or with /pc config.")

    panel.controls = {}

    panel.controls.enabled = CreateCheckbox(
        panel,
        "Enable addon",
        "Turns PaladinComms on or off for this character.",
        function(self)
            PC.db.enabled = not not self:GetChecked()
        end
    )
    panel.controls.enabled:SetPoint("TOPLEFT", panel.subtitle, "BOTTOMLEFT", 0, -18)

    panel.controls.flavorEnabled = CreateCheckbox(
        panel,
        "Enable random flavor lines",
        "Allows combat, loot, mount, and level-up events to trigger Light-themed lines automatically.",
        function(self)
            PC.db.flavorEnabled = not not self:GetChecked()
        end
    )
    panel.controls.flavorEnabled:SetPoint("TOPLEFT", panel.controls.enabled, "BOTTOMLEFT", 0, -8)

    panel.controls.announceJoin = CreateCheckbox(
        panel,
        "Announce paladins joining the network",
        "Print a notice when another paladin running the addon joins the hidden network.",
        function(self)
            PC.db.announceJoin = not not self:GetChecked()
        end
    )
    panel.controls.announceJoin:SetPoint("TOPLEFT", panel.controls.flavorEnabled, "BOTTOMLEFT", 0, -8)

    panel.controls.channelLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.controls.channelLabel:SetPoint("TOPLEFT", panel.controls.announceJoin, "BOTTOMLEFT", 4, -22)
    panel.controls.channelLabel:SetText("Flavor channel")

    panel.controls.channel = CreateFrame("Frame", "PaladinCommsFlavorChannelDropdown", panel, "UIDropDownMenuTemplate")
    panel.controls.channel:SetPoint("TOPLEFT", panel.controls.channelLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(panel.controls.channel, 160)
    UIDropDownMenu_Initialize(panel.controls.channel, function(frame, level)
        local options = {
            { text = "EMOTE", value = "EMOTE", tip = "Send flavor lines to /emote so nearby players can see them." },
            { text = "SAY",   value = "SAY",   tip = "Send flavor lines to /say so nearby players can see them." },
            { text = "SELF",  value = "SELF",  tip = "Show flavor lines only in your own chat frame." },
        }

        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                PC.db.flavorChannel = option.value
                UIDropDownMenu_SetSelectedValue(frame, option.value)
                UIDropDownMenu_SetText(frame, option.value)
            end
            info.checked = (PC.db.flavorChannel == option.value)
            info.tooltipTitle = "Flavor channel"
            info.tooltipText = option.tip
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    AttachTooltip(panel.controls.channel, "Flavor channel", "Choose where automatic Light flavor lines are sent: EMOTE, SAY, or SELF.")
    AttachTooltip(panel.controls.channel.Button, "Flavor channel", "Choose where automatic Light flavor lines are sent: EMOTE, SAY, or SELF.")

    panel.controls.chance = CreateSlider(
        panel,
        "PaladinCommsFlavorChanceSlider",
        "Flavor chance (%)",
        1,
        100,
        1,
        "Chance for each eligible event to speak a random Light line. Stored internally as 0.01 to 1.00, shown here as a percentage."
    )
    panel.controls.chance:SetPoint("TOPLEFT", panel.controls.channel, "BOTTOMLEFT", 20, -34)
    panel.controls.chance:SetScript("OnValueChanged", function(self, value)
        value = ClampPercent(value)
        self.ValueText:SetText(("%d%%"):format(value))
        if Options.refreshing then return end
        PC.db.flavorChance = value / 100
    end)

    panel.controls.cooldown = CreateSlider(
        panel,
        "PaladinCommsFlavorCooldownSlider",
        "Flavor cooldown (seconds)",
        10,
        300,
        5,
        "Minimum time between automatic Light lines. The default is 45 seconds."
    )
    panel.controls.cooldown:SetPoint("TOPLEFT", panel.controls.chance, "BOTTOMLEFT", 0, -42)
    panel.controls.cooldown:SetScript("OnValueChanged", function(self, value)
        value = ClampCooldown(value)
        self.ValueText:SetText(("%ds"):format(value))
        if Options.refreshing then return end
        PC.db.flavorCooldown = value
    end)

    panel.controls.lightNow = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.controls.lightNow:SetSize(180, 24)
    panel.controls.lightNow:SetPoint("TOPLEFT", panel.controls.cooldown, "BOTTOMLEFT", -4, -34)
    panel.controls.lightNow:SetText("Channel the Light now")
    panel.controls.lightNow:SetScript("OnClick", function()
        if PC.Flavor and PC.Flavor.Force then
            PC.Flavor:Force("generic")
        end
    end)
    AttachTooltip(panel.controls.lightNow, "Channel the Light now", "Immediately speaks a random Light line using your current flavor channel.")

    panel.controls.who = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.controls.who:SetSize(140, 24)
    panel.controls.who:SetPoint("LEFT", panel.controls.lightNow, "RIGHT", 12, 0)
    panel.controls.who:SetText("Who's online")
    panel.controls.who:SetScript("OnClick", function()
        if not (PC.Comms and PC.Comms.GetOnline) then return end

        local online = PC.Comms:GetOnline()
        if #online == 0 then
            PC:Print("No other paladins detected yet. (They must be online and running PaladinComms.)")
        else
            PC:Print(("Paladins online (%d): %s"):format(#online, table.concat(online, ", ")))
        end
    end)
    AttachTooltip(panel.controls.who, "Who's online", "Print the roster of paladins currently visible on the addon network.")

    panel:SetScript("OnShow", function()
        Options:Refresh()
    end)

    self.panel = panel
    return panel
end

function Options:RegisterCategory()
    local panel = self:CreatePanel()
    if self.registered then
        return panel
    end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        self.category = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME)
        Settings.RegisterAddOnCategory(self.category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    self.registered = true
    return panel
end

function Options:Open()
    self:RegisterCategory()
    self:Refresh()

    if Settings and Settings.OpenToCategory and self.category then
        local categoryID = self.category.GetID and self.category:GetID() or self.category.ID
        if categoryID then
            Settings.OpenToCategory(categoryID)
            return
        end
    end

    if InterfaceOptionsFrame_OpenToCategory and self.panel then
        -- Legacy clients sometimes need this called twice before the panel is focused.
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
end

function Options:Init()
    self:RegisterCategory()
    self:Refresh()
end
