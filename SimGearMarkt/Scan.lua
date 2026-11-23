-- SimGear Markt: the scan. Two browse queries (weapons, armor) up to your level, all pages; every offer that is
-- gear is loaded and scored by SimGear (a few per frame, so the game never stutters). Own code.
local _, ns = ...
local Scan = {}
ns.Scan = Scan

Scan.PER_FRAME = 4               -- items scored per frame
Scan.TIMEOUT = 8                 -- seconds without answer from the auction house: go on

local CLASSES = {
    { key = "weapons", classID = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2 },
    { key = "armor", classID = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4 },
}

Scan.state = "idle"               -- idle | query | score | done
Scan.offers = {}                  -- every gear offer seen: { itemKey, itemID, link, price, qty }
Scan.results = {}                 -- upgrades: offer + { result, pct, text, slot }
Scan.scored = 0
Scan.gen = 0                      -- counts scans: answers of an older scan are ignored
Scan.at = nil

local worker = CreateFrame("Frame")
local listener = CreateFrame("Frame")
local step, queue, qi, waitT = 1, {}, 1, 0
local seen = {}

local function Changed() if ns.OnScanChanged then ns.OnScanChanged() end end

local function LinkOf(key)
    local suffix = key.itemSuffix or 0
    if suffix ~= 0 then return ("item:%d::::::%d"):format(key.itemID, suffix) end
    return "item:" .. key.itemID
end

local function IsGear(itemID)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    return equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and equipLoc ~= "INVTYPE_BAG"
        and equipLoc ~= "INVTYPE_AMMO" and equipLoc ~= "INVTYPE_QUIVER" and equipLoc ~= "INVTYPE_TABARD" and equipLoc ~= "INVTYPE_BODY", equipLoc
end

local function SendQuery()
    local c = CLASSES[step]
    if not c then
        Scan.state = "score"
        qi = 1
        Changed()
        return
    end
    local level = UnitLevel("player") or 60
    waitT = 0
    C_AuctionHouse.SendBrowseQuery({ searchString = "", sorts = { { sortOrder = 0, reverseSort = false } }, minLevel = 0, maxLevel = level,
        itemClassFilters = { { classID = c.classID } } })
end

-- collect what the browse list holds now; more pages are asked for until it is complete
local function Collect()
    local list = C_AuctionHouse.GetBrowseResults() or {}
    for _, r in ipairs(list) do
        local key = r.itemKey
        local id = key and key.itemID
        if id then
            local uid = id .. ":" .. (key.itemSuffix or 0)
            local gear, loc = IsGear(id)
            if gear and not seen[uid] then
                seen[uid] = true
                local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
                local o = { itemKey = key, itemID = id, link = LinkOf(key), price = r.minPrice or 0, qty = r.totalQuantity or 0, equipLoc = loc,
                    classID = classID, subClassID = subClassID }
                Scan.offers[#Scan.offers + 1] = o
                queue[#queue + 1] = o
            end
        end
    end
    if C_AuctionHouse.HasFullBrowseResults() then
        step = step + 1
        SendQuery()
    else
        waitT = 0
        C_AuctionHouse.RequestMoreBrowseResults()
    end
    Changed()
end

listener:SetScript("OnEvent", function(_, event, itemKey)
    if event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
        if Scan.state == "prices" then Scan.OnSearchResults(itemKey) end
        return
    end
    if Scan.state ~= "query" then return end
    Collect()
end)

function Scan.Listen(on)
    if on then
        listener:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        listener:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
    else
        listener:UnregisterAllEvents()
    end
end

-- scoring: SimGear loads the item (async) and compares it with your worn gear
local open = 0                    -- loads asked for and not answered yet

-- the level the list is for: your own, or the one set with the level slider (to look ahead)
function Scan.MyLevel() return UnitLevel("player") or 1 end
function Scan.ViewLevel() return math.max(Scan.MyLevel(), ns.viewLevel or 0) end

local function Judge(o, api, item)
    local result = api.compare(item)
    if not (result and api.isUpgrade(result)) then return false end
    -- what you could put on and when: the item's required level (client data) and SimGear's weapon state
    -- ("later" = learnable from a level, "untrained" = learnable now, "barred" = never). The level slider filters.
    local state = result.weaponState
    if state == "barred" then return false end
    o.reqLevel = select(5, C_Item.GetItemInfo(o.link)) or 0
    o.laterLevel = state == "later" and tonumber(result.weaponValue) or nil
    o.untrained = state == "untrained" or nil
    if state ~= nil and state ~= "later" and state ~= "untrained" then return false end
    o.result = result
    -- SimGear's result.pct is a fraction (0.127 = +12.7 %); here it is kept in percent for filters, sorting and sets
    o.pct = result.pct and result.pct * 100 or (result.newValue and 100) or 0
    o.text = api.gainText(result)
    o.empty = api.isEmpty and api.isEmpty(result) or false
    o.effect = api.unscoredEffect and api.unscoredEffect(result) or false
    Scan.results[#Scan.results + 1] = o
    return true
end

local function ScoreOne(o, api)
    local gen = Scan.gen
    o.pending = true
    open = open + 1
    local ok = pcall(api.loadItem, o.link, function(item)
        if gen ~= Scan.gen or not o.pending then return end -- an old scan, or answered twice
        o.pending = false
        open = open - 1
        waitT = 0                 -- answers still coming: keep waiting
        Scan.scored = Scan.scored + 1
        local added = item and select(2, pcall(Judge, o, api, item))
        -- the count moves while waiting; answers after the end (slow item loads) still show up
        if Scan.state == "score" or added == true then Changed() end
    end)
    if not ok and o.pending then o.pending = false; open = open - 1; Scan.scored = Scan.scored + 1 end
end

worker:SetScript("OnUpdate", function(self, elapsed)
    if Scan.state == "prices" then
        Scan.PriceTick(elapsed)
        if Scan.state ~= "prices" then self:Hide() end
        return
    end
    if Scan.state == "query" then
        waitT = waitT + elapsed
        if waitT > Scan.TIMEOUT then step = step + 1; SendQuery() end -- no answer: next class
        -- score while the next page loads
    end
    local api = ns.API()
    if not api then return end
    local n = 0
    while qi <= #queue and n < Scan.PER_FRAME do
        local o = queue[qi]
        qi = qi + 1
        n = n + 1
        ScoreOne(o, api)
    end
    if Scan.state == "score" and qi > #queue then
        -- wait for the last loads (any of them, not only the last ones); items the game never answers for
        -- (gone from the game, or SimGear could not read them) end the wait after TIMEOUT seconds of silence
        waitT = waitT + elapsed
        if open <= 0 or waitT > Scan.TIMEOUT then
            Scan.state = "done"
            Scan.at = GetTime()
            self:Hide()
            Changed()
            -- at the auction house the shown prices are checked right away (the list is already there)
            if ns.ahOpen and ns.cdb.autoLive then Scan.StartPrices() end
        end
    end
    if n > 0 then Changed() end
end)
worker:Hide()

-- "Suchen": takes the offers from your Auctionator / Auctioneer data (no auction house queries, works anywhere)
-- and lets SimGear score them.
function Scan.Start()
    local api = ns.API()
    if not api then return false, "nosimgear" end
    if not ns.Sources.Any() then return false, "nodata" end
    if api.ready and not api.ready() then return false, "notready" end
    wipe(Scan.offers); wipe(Scan.results); wipe(queue); wipe(seen)
    Scan.scored, qi, step, open = 0, 1, 1, 0
    Scan.gen = (Scan.gen or 0) + 1
    for _, o in ipairs(ns.Sources.Offers(ns.cdb.maxAgeOn and (ns.cdb.maxAge or 0) or 0)) do
        Scan.offers[#Scan.offers + 1] = o
        queue[#queue + 1] = o
    end
    Scan.state = "score"
    waitT = 0
    worker:Show()
    Changed()
    return true
end

function Scan.Stop()
    if Scan.state == "query" or Scan.state == "score" or Scan.state == "prices" then
        Scan.state = (#Scan.results > 0 or Scan.scored > 0) and "done" or "idle"
        Scan.at = GetTime()
    end
    worker:Hide()
    Changed()
end

function Scan.ClassName()
    local c = CLASSES[step]
    return c and ns.T(c.key) or ""
end

---------------------------------------------------------------------------
-- filters (per character) and order
---------------------------------------------------------------------------
-- armor types a class actually wears (1 cloth, 2 leather, 3 mail, 4 plate): hunters and shamans mix leather and mail,
-- warriors and paladins mail and plate (mail / plate only from 40: ARMOR_FROM)
local WEARS = { WARRIOR = { [3] = true, [4] = true }, PALADIN = { [3] = true, [4] = true },
    HUNTER = { [2] = true, [3] = true }, SHAMAN = { [2] = true, [3] = true },
    ROGUE = { [2] = true }, DRUID = { [2] = true }, MAGE = { [1] = true }, PRIEST = { [1] = true }, WARLOCK = { [1] = true } }
function Scan.ArmorTypes()
    local _, class = UnitClass("player")
    if issecretvalue and issecretvalue(class) then class = Scan.lastClass end -- secret in some instances: last known
    Scan.lastClass = class
    return WEARS[class or ""]
end

-- level from which a class may wear an armor type (SimGear item data meta.armorFrom: mail 40 for hunters and
-- shamans, plate 40 for warriors and paladins); below it the game won't equip it, so it is never listed
local ARMOR_FROM = { HUNTER = { [3] = 40 }, SHAMAN = { [3] = 40 }, WARRIOR = { [4] = 40 }, PALADIN = { [4] = 40 } }
Scan.ARMOR_FROM = ARMOR_FROM

local ARMOR_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4
local function ArmorOk(o, wears, from, level)
    if o.classID ~= ARMOR_CLASS then return true end
    local sub = o.subClassID
    if not sub or sub < 1 or sub > 4 then return true end           -- rings, necks, trinkets, shields, relics
    if o.equipLoc == "INVTYPE_CLOAK" then return true end            -- cloaks are cloth for everyone
    if from and from[sub] and level < from[sub] then return false end
    return not wears or wears[sub] == true
end

-- vendor value of what an item would replace (for "value by net cost")
local SLOTS = { INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_2HWEAPON = { 16, 17 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 } }
local function SellOf(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return 0 end
    local sell = select(11, C_Item.GetItemInfo(link))
    return sell or 0
end
function Scan.NetCost(o)
    local slots = SLOTS[o.equipLoc or ""]
    if not slots then return o.price end
    local back
    if o.equipLoc == "INVTYPE_2HWEAPON" then
        back = SellOf(16) + SellOf(17)                       -- a two-hander replaces both hands
    else
        for _, sl in ipairs(slots) do                         -- rings/trinkets: the cheaper one goes
            local v = SellOf(sl)
            if not back or v < back then back = v end
        end
    end
    return math.max(0, o.price - (back or 0))
end

local function GainPerGold(o, net)
    local cost = net and Scan.NetCost(o) or o.price
    return (o.empty and 100 or (o.pct or 0)) / math.max(1, cost / 10000)
end

-- all upgrades that pass the filters (before "top 5 per slot")
-- budget (copper, optional): the best set's gold amount - then that is what you can afford, not your bag gold.
-- Scan.hidden counts upgrades left out only for their price (affordable / max price), for the status line.
function Scan.Filtered(budget)
    local c = ns.cdb
    local money = budget or (GetMoney and GetMoney() or 0)
    local pricey = 0
    local wears = c.bestArmor and Scan.ArmorTypes() or nil
    local level, mine = Scan.ViewLevel(), Scan.MyLevel()
    Scan.ArmorTypes()                                               -- refreshes Scan.lastClass
    local from = ARMOR_FROM[Scan.lastClass or ""]
    local out = {}
    for _, o in ipairs(Scan.results) do
        local ok = not o.bidOnly
            and (o.reqLevel or 0) <= level
            and (not o.laterLevel or o.laterLevel <= level)
            and (not o.untrained or level > mine)                  -- untrained weapon: you'd train it by then
            and (not c.minGainOn or o.empty or (o.pct or 0) >= (c.minGain or 0))
            and ArmorOk(o, wears, from, level)
            and (ns.db.slot == "all" or ns.SlotGroup(o.equipLoc) == ns.db.slot)
        if ok then
            local priceOk = (not c.onlyAffordable or o.price <= money)
                and (budget or not c.maxGoldOn or (c.maxGold or 0) <= 0 or o.price <= (c.maxGold or 0) * 10000)
            if priceOk then out[#out + 1] = o else pricey = pricey + 1 end
        end
    end
    Scan.hidden = pricey
    return out
end

local function Order(list)
    local sort, net = ns.db.sort, ns.cdb.netCost
    table.sort(list, function(a, b)
        if sort == "price" then return a.price < b.price end
        if sort == "value" then return GainPerGold(a, net) > GainPerGold(b, net) end
        local va, vb = a.empty and 1e6 or (a.pct or 0), b.empty and 1e6 or (b.pct or 0)
        return va > vb
    end)
    return list
end

-- per slot two marks: the strongest upgrade and the best value (most gain per gold); one item can carry both
function Scan.Mark(list)
    local best, value = {}, {}
    local net = ns.cdb.netCost
    for _, o in ipairs(list) do
        local g = ns.Set.GROUP[o.equipLoc or ""] or ns.SlotGroup(o.equipLoc)
        local s1 = o.empty and 1e6 or (o.pct or 0)
        if not best[g] or s1 > best[g][2] then best[g] = { o, s1 } end
        local s2 = GainPerGold(o, net)
        if not value[g] or s2 > value[g][2] then value[g] = { o, s2 } end
    end
    for _, o in ipairs(list) do o.markBest, o.markValue = false, false end
    for _, b in pairs(best) do b[1].markBest = true end
    for _, v in pairs(value) do v[1].markValue = true end
end

-- the shown list: filters, then (if on) only the 5 best per slot, in the chosen order
function Scan.Shown()
    local list = Scan.Filtered()
    Scan.Mark(list)
    if ns.cdb.top5 then
        table.sort(list, function(a, b)
            local va, vb = a.empty and 1e6 or (a.pct or 0), b.empty and 1e6 or (b.pct or 0)
            return va > vb
        end)
        local count, kept = {}, {}
        for _, o in ipairs(list) do
            local g = ns.SlotGroup(o.equipLoc) .. (o.equipLoc == "INVTYPE_FINGER" and "f" or (o.equipLoc == "INVTYPE_TRINKET" and "t" or ""))
            count[g] = (count[g] or 0) + 1
            if count[g] <= 5 then kept[#kept + 1] = o end
        end
        list = kept
    end
    return Order(list)
end

---------------------------------------------------------------------------
-- buyout check: the browse list gives the lowest price, which can be a bid; each shown item is searched once
-- (at most ~85 searches a minute, the client allows 100) and gets the lowest real buyout. Bid-only offers drop out.
---------------------------------------------------------------------------
Scan.SEARCH_GAP = 0.7
local priceQueue, pi, pwait, pcurrent = {}, 1, 0, nil
local function Same(a, b) return a and b and a.itemID == b.itemID and (a.itemSuffix or 0) == (b.itemSuffix or 0) end

function Scan.StartPrices()
    if not ns.ahOpen then return false end
    wipe(priceQueue)
    for _, o in ipairs(Scan.Shown()) do if not o.verified then priceQueue[#priceQueue + 1] = o end end
    pi, pwait, pcurrent = 1, Scan.SEARCH_GAP, nil
    Scan.priceTotal = #priceQueue
    if #priceQueue == 0 then Scan.state = "done"; Scan.at = GetTime(); return true end
    Scan.state = "prices"
    listener:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    listener:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
    worker:Show()
    return true
end

function Scan.PricesDone() return pi - 1 end

local function ReadPrice(o)
    local n = C_AuctionHouse.GetNumItemSearchResults(o.itemKey) or 0
    local best
    for i = 1, n do
        local r = C_AuctionHouse.GetItemSearchResultInfo(o.itemKey, i)
        local b = r and r.buyoutAmount
        if b and b > 0 and (not best or b < best) then best = b end
    end
    o.verified, o.live = true, true
    if best then o.price = best; o.bidOnly = false else o.bidOnly = true end
end

function Scan.OnSearchResults(itemKey)
    if pcurrent and Same(itemKey, pcurrent.itemKey) then
        ReadPrice(pcurrent)
        pcurrent = nil
        Changed()
    end
end

function Scan.PriceTick(elapsed)
    pwait = pwait + elapsed
    if pcurrent and pwait > Scan.TIMEOUT then pcurrent.verified = true; pcurrent = nil end -- no answer: keep the browse price
    if pcurrent or pwait < Scan.SEARCH_GAP then return end
    local o = priceQueue[pi]
    if not o then
        Scan.state = "done"
        Scan.at = GetTime()
        listener:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        listener:UnregisterEvent("ITEM_SEARCH_RESULTS_ADDED")
        Changed()
        return
    end
    pi = pi + 1
    pwait = 0
    pcurrent = o
    C_AuctionHouse.SendSearchQuery(o.itemKey, { { sortOrder = 0, reverseSort = false } }, false)
end

-- slot groups for the filter chips
local GROUP = {
    INVTYPE_HEAD = "head", INVTYPE_NECK = "jewel", INVTYPE_SHOULDER = "shoulder", INVTYPE_CLOAK = "back", INVTYPE_CHEST = "chest",
    INVTYPE_ROBE = "chest", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands", INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs",
    INVTYPE_FEET = "feet", INVTYPE_FINGER = "jewel", INVTYPE_TRINKET = "jewel", INVTYPE_WEAPON = "weapon",
    INVTYPE_2HWEAPON = "weapon", INVTYPE_WEAPONMAINHAND = "weapon", INVTYPE_WEAPONOFFHAND = "weapon", INVTYPE_SHIELD = "weapon",
    INVTYPE_HOLDABLE = "weapon", INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged", INVTYPE_THROWN = "ranged", INVTYPE_RELIC = "ranged",
}
function ns.SlotGroup(loc) return GROUP[loc or ""] or "other" end
ns.SLOT_GROUPS = { "all", "weapon", "ranged", "head", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet", "jewel" }
