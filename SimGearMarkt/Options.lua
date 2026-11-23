-- SimGear Markt settings: Game Menu > Options > AddOns > SimGear Markt (also right click on the minimap button,
-- the gear button in the window, /sgm options). Filters are stored per character, the rest per account.
local _, ns = ...
local T = function(k) return ns.T(k) end

local frame, category
local checks = {}

local function Refresh()
    if not (frame and ns.cdb) then return end
    for _, c in ipairs(checks) do
        local store = rawget(c, "account") and ns.db or ns.cdb
        c:SetChecked(store[c.key] ~= false and store[c.key] ~= nil)
        if rawget(c, "boxKey") then c.box:SetText(tostring(ns.cdb[c.boxKey] or 0)) end
    end
end

local function Changed()
    if ns.ClearSetView then ns.ClearSetView() end
    if ns.OnScanChanged then ns.OnScanChanged() end
end

local function Head(text, y)
    local h = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h:SetPoint("TOPLEFT", 16, y)
    h:SetText(text)
end

local function Check(key, label, y, boxKey, account)
    local c = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", 16, y)
    c.key, c.account = key, account
    c.text = type(c.Text) == "table" and c.Text or frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c, "RIGHT", 4, 0)
    c.text:SetFontObject("GameFontHighlight")
    c.text:SetText(T(label))
    c:SetScript("OnClick", function(self)
        local store = account and ns.db or ns.cdb
        store[key] = self:GetChecked() and true or false
        if key == "minimap" and ns.mmb then ns.mmb.Update() end
        Changed()
    end)
    if boxKey then
        local e = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        e:SetSize(50, 20); e:SetPoint("LEFT", c.text, "RIGHT", 12, 0); e:SetAutoFocus(false); e:SetNumeric(true)
        local function Save(self) ns.cdb[boxKey] = tonumber(self:GetText()) or 0; Changed() end
        e:SetScript("OnEnterPressed", function(self) Save(self); self:ClearFocus() end)
        e:SetScript("OnEditFocusLost", Save)
        c.box, c.boxKey = e, boxKey
    end
    checks[#checks + 1] = c
    frame[key] = c
    return c
end

function ns.BuildOptions()
    if frame then return frame end
    frame = CreateFrame("Frame", "SimGearMarktOptions", UIParent)
    frame:Hide()
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(T("title"))
    local y = -50
    Head(T("filterHead"), y); y = y - 22
    Check("onlyAffordable", "fAfford", y); y = y - 28
    Check("maxGoldOn", "fMax", y, "maxGold"); y = y - 28
    Check("top5", "fTop5", y); y = y - 28
    Check("bestArmor", "fArmor", y); y = y - 28
    Check("minGainOn", "fMin", y, "minGain"); y = y - 28
    Check("netCost", "fNet", y); y = y - 28
    Check("maxAgeOn", "fAge", y, "maxAge"); y = y - 28
    Check("autoLive", "fAuto", y); y = y - 40
    Head(T("generalHead"), y); y = y - 22
    Check("minimap", "minimapOpt", y, nil, true)
    frame:SetScript("OnShow", Refresh)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(frame, T("title"))
        Settings.RegisterAddOnCategory(category)
    end
    return frame
end

function ns.OpenOptions()
    ns.BuildOptions()
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
    else
        frame:Show()
    end
    Refresh()
end

-- the window's filter button opens the settings (old name kept)
ns.ToggleFilters = ns.OpenOptions
function ns._Filters() return frame end
