-- PaladinComms: Minimap
-- Adds a draggable minimap button using only built-in WoW API.
-- Position is persisted via PC.db.minimap.angle.
-- Left-click → open Settings panel.  Right-click → channel a Light line.

local ADDON_NAME, PC = ...

local Minimap = {}
PC.Minimap = Minimap

-- Minimap radius offset (standard WoW minimap button placement).
local MINIMAP_RADIUS = 80
local BUTTON_SIZE    = 31

-- Convert an angle (degrees) to an (x, y) offset around the minimap edge.
local function AngleToOffset(deg)
    local rad = math.rad(deg)
    return MINIMAP_RADIUS * math.cos(rad), MINIMAP_RADIUS * math.sin(rad)
end

-- Return the angle (degrees) from the minimap center to the cursor.
local function CursorAngle()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale  = UIParent:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    return math.deg(math.atan2(cy - my, cx - mx))
end

-- Place the button at the stored angle.
local function PositionButton(btn)
    local angle = (PC.db and PC.db.minimap and PC.db.minimap.angle) or 200
    local x, y  = AngleToOffset(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-------------------------------------------------------------------------------
-- Build the button
-------------------------------------------------------------------------------

local function BuildButton()
    local btn = CreateFrame("Button", "PaladinCommsMinimapButton", Minimap)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    -- Icon
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\Spell_Holy_HolyBolt")

    -- Border ring (standard minimap button border)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight overlay
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(icon)
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("PaladinComms", 1, 0.84, 0)
        GameTooltip:AddLine("Left-click: Open settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Channel the Light", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click handling
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            if PC.Options and PC.Options.Open then
                PC.Options:Open()
            end
        elseif button == "RightButton" then
            if PC.Flavor and PC.Flavor.Force then
                PC.Flavor:Force("generic")
            end
        end
    end)

    -- Dragging
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local angle = CursorAngle()
            if PC.db and PC.db.minimap then
                PC.db.minimap.angle = angle
            end
            PositionButton(self)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        -- Persist final angle.
        local angle = CursorAngle()
        if PC.db and PC.db.minimap then
            PC.db.minimap.angle = angle
        end
        PositionButton(self)
    end)

    return btn
end

-------------------------------------------------------------------------------
-- Public interface
-------------------------------------------------------------------------------

local _btn = nil

function Minimap:SetShown(show)
    if _btn then
        if show then
            _btn:Show()
        else
            _btn:Hide()
        end
        if PC.db and PC.db.minimap then
            PC.db.minimap.hide = not show
        end
    end
end

function Minimap:Init()
    _btn = BuildButton()
    PositionButton(_btn)

    -- Apply saved show/hide state.
    if PC.db and PC.db.minimap and PC.db.minimap.hide then
        _btn:Hide()
    else
        _btn:Show()
    end
end
