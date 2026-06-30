-- PaladinComms: Minimap
-- Lightweight draggable minimap button for opening settings quickly.

local ADDON_NAME, PC = ...

local MinimapButton = {}
PC.Minimap = MinimapButton

local ICON = "Interface\\Icons\\Spell_Holy_HolyBolt"

local function EnsureDB()
    PC.db.minimap = PC.db.minimap or {}
    if PC.db.minimap.hide == nil then
        PC.db.minimap.hide = false
    end
    if PC.db.minimap.angle == nil then
        PC.db.minimap.angle = 225
    end
end

local function UpdatePosition(button)
    if not button or not Minimap then return end

    EnsureDB()
    local angle = math.rad(PC.db.minimap.angle or 225)
    local radius = 80
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function UpdateAngleFromCursor(button)
    if not button or not Minimap then return end

    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()

    px = px / scale
    py = py / scale

    local angle
    if math.atan2 then
        angle = math.deg(math.atan2(py - my, px - mx))
    else
        local dx = px - mx
        local dy = py - my
        if dx == 0 then
            angle = (dy >= 0) and 90 or -90
        else
            angle = math.deg(math.atan(dy / dx))
            if dx < 0 then
                angle = angle + 180
            end
        end
    end
    PC.db.minimap.angle = angle
    UpdatePosition(button)
end

function MinimapButton:SetHidden(hidden)
    EnsureDB()
    PC.db.minimap.hide = not not hidden

    if not self.button then return end
    if PC.db.minimap.hide then
        self.button:Hide()
    else
        self.button:Show()
    end
end

function MinimapButton:Create()
    if self.button or not Minimap then
        return self.button
    end

    local button = CreateFrame("Button", "PaladinCommsMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetTexture(ICON)
    button.icon:SetPoint("TOPLEFT", 7, -5)
    button.icon:SetPoint("BOTTOMRIGHT", -7, 5)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetAllPoints()

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetAllPoints()

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            if PC.Options and PC.Options.Open then
                PC.Options:Open()
            end
        elseif PC.Flavor and PC.Flavor.Force then
            PC.Flavor:Force("generic")
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(frame)
            UpdateAngleFromCursor(frame)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateAngleFromCursor(self)
    end)

    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("PaladinComms")
        GameTooltip:AddLine("Left-click: open settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: channel the Light now", 1, 1, 1)
        GameTooltip:AddLine("Drag: move around the minimap", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    self.button = button
    return button
end

function MinimapButton:Init()
    EnsureDB()

    local button = self:Create()
    UpdatePosition(button)
    self:SetHidden(PC.db.minimap.hide)
end
