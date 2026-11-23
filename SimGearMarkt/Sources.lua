-- SimGear Markt: where the offers come from - the scans you already make with Auctionator and/or Auctioneer.
-- SimGear Markt does not scan the auction house itself any more.
--   Auctionator: its price database (per item: last seen lowest price "m", per day lowest/highest/amount). On
--                Forever's auction house gear is stored under the plain item ID (random suffixes are not told
--                apart), so such an item is scored as its base item.
--   Auctioneer:  the image of its last full scan: every auction with its link (suffix included), buyout and count.
--                Auctions without buyout are skipped.
-- Both together: per item link the lower price wins; Auctioneer's exact links are kept.
local _, ns = ...
local Sources = {}
ns.Sources = Sources

local SCAN0 = time({ year = 2020, month = 1, day = 1, hour = 0 }) -- Auctionator's day 0 (local time)
local function Today() return math.floor((time() - SCAN0) / 86400) end

function Sources.HasAuctionator()
    return Auctionator and Auctionator.Database and type(Auctionator.Database.db) == "table" and true or false
end
function Sources.HasAuctioneer()
    return AucAdvanced and AucAdvanced.Scan and AucAdvanced.Scan.GetImageCopy and true or false
end
function Sources.Any() return Sources.HasAuctionator() or Sources.HasAuctioneer() end

-- the auction house's key for an item (needed by the live check)
local function Key(itemID, suffix)
    if C_AuctionHouse and C_AuctionHouse.MakeItemKey then
        local ok, key = pcall(C_AuctionHouse.MakeItemKey, itemID, 0, suffix or 0)
        if ok and key then return key end
    end
    return { itemID = itemID, itemLevel = 0, itemSuffix = suffix or 0, battlePetSpeciesID = 0 }
end
Sources.Key = Key

local function Gear(itemID)
    local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" or equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_AMMO"
        or equipLoc == "INVTYPE_QUIVER" or equipLoc == "INVTYPE_TABARD" or equipLoc == "INVTYPE_BODY" then return nil end
    return equipLoc, classID, subClassID
end

-- the newest day Auctionator saw the item
local function LastDay(e)
    local last
    for d in pairs(e.h or {}) do local n = tonumber(d); if n and (not last or n > last) then last = n end end
    return last
end

-- offers: list of { itemID, link, price, qty, equipLoc, classID, subClassID, src, age (days, or nil) }
-- maxAge: leave out Auctionator prices older than this many days (0 = keep all)
function Sources.Offers(maxAge)
    local byLink, out = {}, {}
    local today = Today()
    local function Add(o)
        local have = byLink[o.link]
        if have then
            if o.price < have.price then have.price, have.src, have.age = o.price, o.src, o.age end
            have.qty = math.max(have.qty or 0, o.qty or 0)
            return
        end
        byLink[o.link] = o
        out[#out + 1] = o
    end
    -- Auctioneer first: exact links with suffix, real buyouts of its last scan
    if Sources.HasAuctioneer() then
        local ok, image = pcall(AucAdvanced.Scan.GetImageCopy)
        local C = AucAdvanced.Const or {}
        local LINK, ID, COUNT, BUY = C.LINK or 1, C.ITEMID or 23, C.COUNT or 11, C.BUYOUT or 17
        if ok and type(image) == "table" then
            for _, a in ipairs(image) do
                local id, buy, count, link = a[ID], a[BUY] or 0, a[COUNT] or 1, a[LINK]
                if id and buy > 0 and count > 0 then
                    local loc, classID, sub = Gear(id)
                    if loc then
                        local plain = type(link) == "string" and link:match("|H(item:[^|]+)|h") or ("item:" .. id)
                        local suffix = tonumber(plain:match("^item:%d+:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:(%-?%d+)")) or 0
                        Add({ itemID = id, link = plain, itemKey = Key(id, suffix), price = math.floor(buy / count), qty = count, equipLoc = loc,
                            classID = classID, subClassID = sub, src = "auc", age = 0 })
                    end
                end
            end
        end
    end
    -- Auctionator: the plain item keys (gear on Forever lives there)
    if Sources.HasAuctionator() then
        for k, e in pairs(Auctionator.Database.db) do
            if type(k) == "string" and type(e) == "table" and e.m and e.m > 0 then
                local id = tonumber(k:match("^(%d+)$") or k:match("^g:(%d+):"))
                if id then
                    local loc, classID, sub = Gear(id)
                    if loc then
                        local last = LastDay(e)
                        local age = last and (today - last) or nil
                        if not (maxAge and maxAge > 0 and age and age > maxAge) then
                            Add({ itemID = id, link = "item:" .. id, itemKey = Key(id, 0), price = e.m, qty = last and e.a and e.a[last] or 0,
                                equipLoc = loc, classID = classID, subClassID = sub, src = "atr", age = age })
                        end
                    end
                end
            end
        end
    end
    return out
end
