-- Minimap button (own code, no library; the same file is copied into each of our add-ons).
-- ns.MinimapButton{ name, icon, title, db, onClick, onRightClick, tip }:
--   db: saved table with .minimap (shown, default true) and .mmAngle (position in degrees).
--   Left click: onClick, right click: onRightClick (settings). Drag: around the minimap edge.
-- Nothing runs while idle: the OnUpdate only lives while the button is dragged.
local _, ns = ...

function ns.MinimapButton(o)
    if not Minimap then return nil end
    local b = CreateFrame("Button", o.name, Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20); bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(19, 19); icon:SetPoint("CENTER", 0, 1)
    if icon:SetTexture(o.icon) == false then icon:SetTexture(134400) end
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local function Place()
        local a = math.rad(o.db.mmAngle or 200)
        local r = (Minimap:GetWidth() / 2) + 10
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    end
    function b.Update()
        Place()
        b:SetShown(o.db.minimap ~= false)
    end

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" and o.onRightClick then o.onRightClick() else o.onClick() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(o.title)
        if o.tip then GameTooltip:AddLine(o.tip, 1, 1, 1) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            o.db.mmAngle = math.deg(math.atan2(cy / s - my, cx / s - mx)) % 360
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b.Update()
    return b
end
