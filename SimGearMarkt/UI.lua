-- SimGear Markt: the window, in the game's own look (ButtonFrameTemplate: portrait, title bar, inset, button
-- bar; game fonts). Built on first use, rows pooled, redrawn only when the scan changes something (at most 4
-- times a second while scanning).
local _, ns = ...
local T = function(k) return ns.T(k) end

local W, H = 430, 630
local ROW_H, ROWS = 34, 10
local panel, toggleBtn, rows = nil, nil, {}
local offset = 0
local setView = nil      -- { items, cost, value } while "best set" is shown
local redrawAt, dirty = 0, false

local SLOT_NAME = {
    all = { de = "Alle", en = "All" }, weapon = { de = "Waffe", en = "Weapon" }, ranged = { de = "Fernkampf", en = "Ranged" },
    head = { de = "Kopf", en = "Head" }, shoulder = { de = "Schulter", en = "Shoulder" }, back = { de = "Rücken", en = "Back" },
    chest = { de = "Brust", en = "Chest" }, wrist = { de = "Handgelenk", en = "Wrist" }, hands = { de = "Hände", en = "Hands" },
    waist = { de = "Taille", en = "Waist" }, legs = { de = "Beine", en = "Legs" }, feet = { de = "Füße", en = "Feet" },
    jewel = { de = "Schmuck", en = "Jewelry" }, other = { de = "Sonstiges", en = "Other" },
}
local function SlotName(k) local e = SLOT_NAME[k]; return e and (e[ns.Lang()] or e.en) or k end

local function Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function Button(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetText(text)
    return b
end

local function Search(o)
    -- search the item in Blizzard's auction house window; buying stays with the player
    local name = C_Item.GetItemNameByID(o.itemID)
    local bar = AuctionHouseFrame and AuctionHouseFrame.SearchBar
    if name and bar and bar.SetSearchText and bar.StartSearch then
        bar:SetSearchText(name)
        bar:StartSearch()
    end
end

local function BuildRow(i)
    local r = CreateFrame("Button", nil, panel.list)
    r:SetSize(W - 40, ROW_H - 2)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp")
    -- every second row slightly lighter, the game's quest-list highlight on hover
    if i % 2 == 0 then local st = r:CreateTexture(nil, "BACKGROUND"); st:SetAllPoints(); st:SetColorTexture(1, 1, 1, 0.03) end
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); hl:SetBlendMode("ADD"); hl:SetAlpha(0.5)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(28, 28); r.icon:SetPoint("LEFT", 2, 0)
    local ib = r:CreateTexture(nil, "OVERLAY"); ib:SetTexture("Interface\\Buttons\\UI-Quickslot2"); ib:SetSize(46, 46); ib:SetPoint("CENTER", r.icon)
    r.name = Text(r, "GameFontHighlight"); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1); r.name:SetWidth(200); r.name:SetWordWrap(false)
    r.slot = Text(r, "GameFontDisableSmall"); r.slot:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
    r.gain = Text(r, "GameFontGreen", "RIGHT"); r.gain:SetPoint("TOPRIGHT", -54, -2); r.gain:SetWidth(100)
    r.price = Text(r, "GameFontHighlightSmall", "RIGHT"); r.price:SetPoint("BOTTOMRIGHT", -54, 2); r.price:SetWidth(130)
    -- buy (only at the auction house): asks first, with the current price
    r.buy = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.buy:SetSize(46, 20); r.buy:SetPoint("RIGHT", -2, 0)
    r.buy:SetText(T("buy"))
    r.buy:SetScript("OnClick", function(self) local o = self:GetParent().offer; if o then ns.Buy.Start(o) end end)
    r:SetScript("OnClick", function(self)
        local o = self.offer
        if not o then return end
        if IsShiftKeyDown() then
            local _, link = C_Item.GetItemInfo(o.link)
            if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        else
            Search(o)
        end
    end)
    r:SetScript("OnEnter", function(self)
        local o = self.offer
        if not o then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(o.link)
        local src = o.live and T("srcLive") or (o.src == "auc" and T("srcAuc")) or ((o.age or 0) <= 0 and T("srcAtrToday")) or T("srcAtr"):format(o.age)
        GameTooltip:AddLine(ns.Money(o.price) .. "  (" .. src .. ")", 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function Redraw()
    if not (panel and panel:IsShown()) then return end
    local Scan = ns.Scan
    local list = setView and setView.items or Scan.Shown()
    offset = math.max(0, math.min(offset, #list - ROWS))
    for i = 1, ROWS do
        local r = rows[i] or BuildRow(i)
        local o = list[i + offset]
        r.offer = o
        if o then
            local quality = C_Item.GetItemQualityByID(o.itemID) or 1
            local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            r.icon:SetTexture(select(5, C_Item.GetItemInfoInstant(o.itemID)) or 134400)
            -- a yellow * after the name: effects SimGear does not count (procs and the like)
            r.name:SetText((C_Item.GetItemNameByID(o.itemID) or ("#" .. o.itemID)) .. (o.effect and " |cffffd100*|r" or ""))
            if c then r.name:SetTextColor(c.r, c.g, c.b) else r.name:SetTextColor(1, 1, 1) end
            local marks = ""
            if o.markBest then marks = marks .. "  |cffffd100" .. T("markBest") .. "|r" end
            if o.markValue then marks = marks .. "  |cff40ff40" .. T("markValue") .. "|r" end
            r.slot:SetText(SlotName(ns.SlotGroup(o.equipLoc)) .. marks)
            -- the same text as SimGear's own tooltip ("+12%", "+4.2%", "at least +8%")
            r.gain:SetText(o.empty and T("new") or (o.text ~= "" and o.text) or ("+%.1f %%"):format(o.pct or 0))
            -- grey = lowest from the scan data, not yet checked (may be a bid); white = checked buyout
            r.price:SetText(ns.Money(o.price))
            if o.live then r.price:SetTextColor(1, 1, 1) else r.price:SetTextColor(0.5, 0.5, 0.5) end
            r.buy:SetShown(ns.ahOpen and not o.bidOnly)
            r:Show()
        else
            r:Hide()
        end
    end
    -- status line
    local api = ns.API()
    if not ns.Sources.Any() and Scan.state ~= "done" then
        panel.status:SetText(T("noData"))
    elseif not api then
        panel.status:SetText(T("noSimGear"))
    elseif Scan.state == "query" or Scan.state == "score" then
        panel.status:SetText(T("progress"):format(Scan.state == "query" and Scan.ClassName() or "SimGear", #Scan.offers, Scan.scored))
    elseif Scan.state == "prices" then
        panel.status:SetText(T("checking"):format(Scan.PricesDone(), Scan.priceTotal or 0))
    elseif setView then
        panel.status:SetText(#setView.items > 0 and T("setHead"):format(#setView.items, ns.Money(setView.cost), ("+%.1f %%"):format(setView.value)) or T("setNone"))
    elseif Scan.state == "done" then
        local mins = math.floor((GetTime() - (Scan.at or GetTime())) / 60)
        local text = #list > 0 and T("done"):format(#list, #Scan.offers, T("since"):format(mins)) or T("none")
        if (Scan.hidden or 0) > 0 then text = text .. "  |cffff8040" .. T("hiddenPricey"):format(Scan.hidden) .. "|r" end
        panel.status:SetText(text)
    else
        panel.status:SetText(T("nothing"))
    end
    panel.scan:SetText((Scan.state == "query" or Scan.state == "score" or Scan.state == "prices") and T("stop") or T("scan"))
    panel.back:SetShown(setView ~= nil)
    panel.live:SetShown(ns.ahOpen and Scan.state == "done")
    panel.scroll:SetShown(#list > ROWS)
    panel.scrollText:SetText(#list > ROWS and ("%d-%d / %d"):format(offset + 1, math.min(#list, offset + ROWS), #list) or "")
    dirty = false
end
ns.Redraw = Redraw

-- scan updates arrive often: redraw at most 4 times a second
-- at most 4 redraws a second while scanning; a change inside that window is drawn when it ends (one timer),
-- so the last change (scan done) is never lost
local trailing = false
function ns.OnScanChanged()
    dirty = true
    local now = GetTime()
    if now - redrawAt > 0.25 then redrawAt = now; Redraw(); return end
    if trailing then return end
    trailing = true
    C_Timer.After(0.26 - (now - redrawAt), function()
        trailing = false
        if dirty then redrawAt = GetTime(); Redraw() end
    end)
end

local function Build()
    panel = CreateFrame("Frame", "SimGearMarktFrame", UIParent, "ButtonFrameTemplate")
    panel:SetSize(W, H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")
    panel:SetToplevel(true)
    panel:SetMovable(true); panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SimGearMarktFrame")
    if panel.SetTitle then panel:SetTitle(T("title")) end
    if panel.SetPortraitToAsset then panel:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Coin_02") end
    local inset = type(panel.Inset) == "table" and panel.Inset or panel

    -- top area (right of the portrait): level slider, settings
    panel.level = CreateFrame("Slider", nil, panel, "UISliderTemplate")
    panel.level:SetSize(150, 16)
    panel.level:SetPoint("TOPLEFT", 74, -36)
    panel.level:SetValueStep(1)
    panel.levelText = Text(panel, "GameFontNormal"); panel.levelText:SetPoint("LEFT", panel.level, "RIGHT", 8, 0)
    panel.level:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        local mine = ns.Scan.MyLevel()
        ns.viewLevel = v > mine and v or nil
        panel.levelText:SetText(T("level"):format(v))
        if v > mine then panel.levelText:SetTextColor(1, 0.82, 0) else panel.levelText:SetTextColor(1, 1, 1) end
        setView = nil; offset = 0
        ns.OnScanChanged()
    end)
    panel.filterBtn = Button(panel, T("settings"), 110)
    panel.filterBtn:SetPoint("TOPRIGHT", -10, -32)
    panel.filterBtn:SetScript("OnClick", function() ns.OpenOptions() end)

    -- inside the inset: sort buttons, slot chips, list, best set row
    panel.sorts = {}
    local x = 8
    for _, k in ipairs({ "gain", "value", "price" }) do
        local b = Button(inset, T(k == "gain" and "sortGain" or (k == "value" and "sortValue" or "sortPrice")), 128)
        b:SetPoint("TOPLEFT", x, -8)
        b:SetScript("OnClick", function() ns.db.sort = k; for kk, bb in pairs(panel.sorts) do bb:SetEnabled(kk ~= k) end; Redraw() end)
        panel.sorts[k] = b
        x = x + 132
    end
    panel.slots = {}
    for i, k in ipairs(ns.SLOT_GROUPS) do
        local b = Button(inset, SlotName(k), 78)
        b:SetSize(78, 20)
        local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
        b:SetPoint("TOPLEFT", 8 + col * 80, -36 - row * 22)
        b:SetScript("OnClick", function() ns.db.slot = k; for kk, bb in pairs(panel.slots) do bb:SetEnabled(kk ~= k) end; offset = 0; Redraw() end)
        panel.slots[k] = b
    end
    -- the list starts below the last row of slot buttons (however many rows there are)
    local chipRows = math.ceil(#ns.SLOT_GROUPS / 5)
    panel.list = CreateFrame("Frame", nil, inset)
    panel.list:SetPoint("TOPLEFT", 10, -36 - chipRows * 22 - 8); panel.list:SetSize(W - 40, ROWS * ROW_H)
    panel.list:EnableMouseWheel(true)
    panel.list:SetScript("OnMouseWheel", function(_, d) offset = offset - d * 3; Redraw() end)
    panel.scroll = CreateFrame("Frame", nil, inset); panel.scroll:SetPoint("BOTTOMRIGHT", -10, 34); panel.scroll:SetSize(100, 14)
    panel.scrollText = Text(inset, "GameFontDisableSmall", "RIGHT"); panel.scrollText:SetPoint("BOTTOMRIGHT", -10, 34)
    -- best set for ... gold
    local bs = Text(inset, "GameFontNormal"); bs:SetPoint("BOTTOMLEFT", 10, 10); bs:SetText(T("bestSet"))
    panel.budget = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    panel.budget:SetSize(60, 20); panel.budget:SetPoint("LEFT", bs, "RIGHT", 10, 0); panel.budget:SetAutoFocus(false); panel.budget:SetNumeric(true)
    local gold = Text(inset, "GameFontHighlight"); gold:SetPoint("LEFT", panel.budget, "RIGHT", 4, 0); gold:SetText("|TInterface\\MoneyFrame\\UI-GoldIcon:0|t")
    panel.setBtn = Button(inset, "OK", 44); panel.setBtn:SetPoint("LEFT", gold, "RIGHT", 8, 0)
    local function RunSet()
        ns.cdb.setBudget = tonumber(panel.budget:GetText()) or 0
        local budget = ns.cdb.setBudget > 0 and ns.cdb.setBudget * 10000 or (GetMoney and GetMoney() or 0)
        local items, cost, value = ns.Set.Best(ns.Scan.Filtered(budget), budget)
        setView = { items = items, cost = cost, value = value }
        offset = 0
        Redraw()
    end
    panel.setBtn:SetScript("OnClick", RunSet)
    panel.budget:SetScript("OnEnterPressed", function(self) self:ClearFocus(); RunSet() end)
    panel.back = Button(inset, T("backList"), 110); panel.back:SetPoint("BOTTOMRIGHT", -8, 8)
    panel.back:SetScript("OnClick", function() setView = nil; Redraw() end)
    panel.back:Hide()

    -- button bar: status left, live check and scan right
    panel.scan = Button(panel, T("scan"), 100)
    panel.scan:SetPoint("BOTTOMRIGHT", -6, 4)
    panel.scan:SetScript("OnClick", function()
        local Scan = ns.Scan
        if Scan.state == "query" or Scan.state == "score" or Scan.state == "prices" then Scan.Stop(); return end
        setView = nil
        local ok, why = Scan.Start()
        if not ok and why == "notready" then panel.status:SetText(T("notReady")) end
        if not ok and why == "nodata" then panel.status:SetText(T("noData")) end
        Redraw()
    end)
    panel.live = Button(panel, T("live"), 100); panel.live:SetPoint("RIGHT", panel.scan, "LEFT", -2, 0)
    panel.live:SetScript("OnClick", function() setView = nil; ns.Scan.StartPrices(); Redraw() end)
    panel.status = Text(panel, "GameFontHighlightSmall"); panel.status:SetPoint("BOTTOMLEFT", 12, 9); panel.status:SetWidth(W - 230)
    panel.status:SetWordWrap(false)

    panel:SetScript("OnShow", function()
        local mine = ns.Scan.MyLevel()
        local max = math.max(mine, (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or 60)
        panel.level:SetMinMaxValues(mine, max)
        panel.level:SetValue(ns.Scan.ViewLevel())
        panel.level:GetScript("OnValueChanged")(panel.level, ns.Scan.ViewLevel())
        panel.budget:SetText((ns.cdb.setBudget or 0) > 0 and tostring(ns.cdb.setBudget) or "")
        for kk, bb in pairs(panel.sorts) do bb:SetEnabled(kk ~= ns.db.sort) end
        for kk, bb in pairs(panel.slots) do bb:SetEnabled(kk ~= ns.db.slot) end
        Redraw()
    end)
    panel:Hide()
end

function ns.ClearSetView() setView = nil end

function ns.Toggle()
    if not panel then Build() end
    panel:SetShown(not panel:IsShown())
end

-- a small button on the auction house window opens the panel
function ns.OnAHShow()
    if not toggleBtn and AuctionHouseFrame then
        toggleBtn = Button(AuctionHouseFrame, T("toggle"), 120)
        toggleBtn:SetPoint("TOPRIGHT", AuctionHouseFrame, "TOPRIGHT", -60, -1)
        toggleBtn:SetScript("OnClick", function() ns.Toggle() end)
    end
end

-- the window stays open without the auction house (it works from your saved prices); only the live check stops
function ns.OnAHClosed()
    if panel and panel:IsShown() then Redraw() end
end

-- test hooks
function ns._Panel() return panel end
function ns._Rows() return rows end
function ns._SetView() return setView end
