-- SimGear Markt: buying, with a question first. "Kaufen" looks the item up in the auction house right now
-- (one search), then a box shows SimGear's gain, the buyout and the net cost - and the old and the new price
-- if it changed, the next offer if the cheapest is gone, or that nothing is left. Only the box's own button
-- pays (C_AuctionHouse.PlaceBid needs a real click). Own code.
local _, ns = ...
local Buy = {}
ns.Buy = Buy

local box, pending, offer
local auction, paid          -- the auction the box would buy, and the purchase on its way
local listener = CreateFrame("Frame")
local T = function(k) return ns.T(k) end

local function Same(a, b) return a and b and a.itemID == b.itemID and (a.itemSuffix or 0) == (b.itemSuffix or 0) end

-- the cheapest buyout among the current auctions of an item that is not your own, or nil
function Buy.Cheapest(itemKey)
    local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    local best
    for i = 1, n do
        local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if r and r.buyoutAmount and r.buyoutAmount > 0 and not r.containsOwnerItem then
            if not best or r.buyoutAmount < best.buyoutAmount then best = r end
        end
    end
    return best
end

local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

local function Build()
    -- the game's dialog look (like its own pop-ups)
    box = CreateFrame("Frame", "SimGearMarktBuyBox", UIParent)
    box:SetSize(340, 200)
    box:SetPoint("CENTER", 0, 80)
    box:SetFrameStrata("DIALOG")
    box:EnableMouse(true)
    local border = CreateFrame("Frame", nil, box, "DialogBorderTemplate")
    if border.SetAllPoints then border:SetAllPoints() end
    box.title = Text(box, "GameFontNormalLarge"); box.title:SetPoint("TOP", 0, -18); box.title:SetJustifyH("CENTER")
    box.icon = box:CreateTexture(nil, "ARTWORK"); box.icon:SetSize(36, 36); box.icon:SetPoint("TOPLEFT", 22, -44)
    box.name = Text(box, "GameFontHighlight"); box.name:SetPoint("LEFT", box.icon, "RIGHT", 8, 0); box.name:SetWidth(260)
    box.lines = Text(box, "GameFontHighlightSmall"); box.lines:SetPoint("TOPLEFT", 22, -88); box.lines:SetWidth(296)
    box.yes = CreateFrame("Button", nil, box, "UIPanelButtonTemplate"); box.yes:SetSize(120, 22); box.yes:SetPoint("BOTTOMLEFT", 36, 18)
    box.yes:SetText(T("buy"))
    box.no = CreateFrame("Button", nil, box, "UIPanelButtonTemplate"); box.no:SetSize(120, 22); box.no:SetPoint("BOTTOMRIGHT", -36, 18)
    box.no:SetText(T("cancel"))
    box.no:SetScript("OnClick", function() Buy.Close() end)
    -- the only place that pays: a real click on this button
    box.yes:SetScript("OnClick", function()
        local a = auction
        if not (a and offer and ns.ahOpen) then return end
        if (GetMoney and GetMoney() or 0) < a.buyoutAmount then box.lines:SetText(T("buyNoMoney")); return end
        box.yes:Disable()
        paid = { offer = offer, price = a.buyoutAmount }
        listener:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED")
        listener:RegisterEvent("AUCTION_HOUSE_SHOW_ERROR")
        C_AuctionHouse.PlaceBid(a.auctionID, a.buyoutAmount)
    end)
    tinsert(UISpecialFrames, "SimGearMarktBuyBox")
    box:Hide()
end

function Buy.Close()
    if box then box:Hide() end
    pending, offer = nil, nil
    listener:UnregisterAllEvents()
end

-- step 1: ask the auction house for the item's auctions right now
function Buy.Start(o)
    if not ns.ahOpen or not o or not o.itemKey then return false end
    if not box then Build() end
    offer, pending = o, o.itemKey
    auction, paid = nil, nil
    box.title:SetText(T("buyTitle"))
    box.icon:SetTexture(select(5, C_Item.GetItemInfoInstant(o.itemID)) or 134400)
    box.name:SetText(C_Item.GetItemNameByID(o.itemID) or ("#" .. o.itemID))
    box.lines:SetText(T("buyChecking"))
    box.yes:Disable()
    box:Show()
    listener:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    listener:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
    C_AuctionHouse.SendSearchQuery(o.itemKey, { { sortOrder = 0, reverseSort = false } }, false)
    return true
end

-- step 2: the answer - fill the box
local function Show()
    local o = offer
    local a = Buy.Cheapest(o.itemKey)
    local gain = o.empty and T("new") or (o.text or "")
    local lines = { T("buyGain"):format(gain) }
    if not a then
        lines[#lines + 1] = T("buyGone")
        o.bidOnly = true
        box.yes:Disable()
    else
        local old = o.price
        if o.live and a.buyoutAmount > old then
            lines[#lines + 1] = T("buyNext"):format(ns.Money(a.buyoutAmount))
        elseif a.buyoutAmount ~= old then
            lines[#lines + 1] = T("buyChanged"):format(ns.Money(old), ns.Money(a.buyoutAmount))
        end
        o.price, o.verified, o.live = a.buyoutAmount, true, true
        lines[#lines + 1] = T("buyPrice"):format(ns.Money(a.buyoutAmount))
        lines[#lines + 1] = T("buyNet"):format(ns.Money(ns.Scan.NetCost(o)))
        auction = a
        box.yes:Enable()
    end
    box.lines:SetText(table.concat(lines, "\n"))
    if ns.OnScanChanged then ns.OnScanChanged() end
end

listener:SetScript("OnEvent", function(_, event, a1)
    if event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
        if pending and Same(a1, pending) and box:IsShown() and not paid then Show() end
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        local p = paid
        if p then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSimGear Markt|r " .. T("buyDone"):format(C_Item.GetItemNameByID(p.offer.itemID) or "?", ns.Money(p.price)))
            -- the bought item leaves the list
            for i, r in ipairs(ns.Scan.results) do if r == p.offer then table.remove(ns.Scan.results, i); break end end
            if ns.OnScanChanged then ns.OnScanChanged() end
        end
        Buy.Close()
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        if box and paid then
            box.lines:SetText(T("buyFail"):format(tostring(a1)))
            paid = nil
            box.yes:Enable()
        end
    end
end)

-- test hooks
function Buy._Box() return box end
function Buy._Auction() return auction end
