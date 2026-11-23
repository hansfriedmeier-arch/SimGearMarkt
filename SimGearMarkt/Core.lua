-- SimGear Markt: language, settings, the link to SimGear Forever, events. Own code.
-- Scoring is SimGear Forever's: its SimGearForeverAPI (a read-only door in the player's patched SimGear copy)
-- loads an item and compares it with what you wear, exactly like SimGear's tooltip. Nothing runs while the
-- auction house is closed; a scan only starts on the button.
local ADDON, ns = ...

local S = {
    title = { de = "SimGear Markt", en = "SimGear Market" },
    mmTip = { de = "Linksklick: öffnen  -  Rechtsklick: Einstellungen", en = "Left click: open  -  Right click: settings" },
    minimapOpt = { de = "Minimap-Knopf zeigen", en = "Show minimap button" },
    settings = { de = "Einstellungen", en = "Settings" },
    filterHead = { de = "Filter (pro Charakter)", en = "Filters (per character)" },
    generalHead = { de = "Allgemein", en = "General" },
    level = { de = "Level %d", en = "Level %d" },
    scan = { de = "Suchen", en = "Scan" },
    stop = { de = "Stopp", en = "Stop" },
    toggle = { de = "SimGear Markt", en = "SimGear Market" },
    minGain = { de = "Mindestens +%", en = "At least +%" },
    sortGain = { de = "Nach Gewinn", en = "By gain" },
    sortValue = { de = "Gewinn pro Gold", en = "Gain per gold" },
    sortPrice = { de = "Nach Preis", en = "By price" },
    nothing = { de = "Noch nichts gesucht. \"Suchen\" nimmt die Preise aus deinem Auctionator/Auctioneer und lässt SimGear bewerten.",
        en = "Nothing searched yet. \"Scan\" takes the prices from your Auctionator/Auctioneer and lets SimGear score them." },
    noData = { de = "Keine Auktionsdaten: Auctionator oder Auctioneer fehlt. Mit einem davon einmal das Auktionshaus scannen.",
        en = "No auction data: Auctionator or Auctioneer is missing. Scan the auction house once with one of them." },
    live = { de = "Live prüfen", en = "Check live" },
    fAge = { de = "Auctionator-Preise höchstens (Tage alt)", en = "Auctionator prices at most (days old)" },
    srcAtr = { de = "Auctionator, vor %d Tagen", en = "Auctionator, %d days ago" },
    srcAtrToday = { de = "Auctionator, heute", en = "Auctionator, today" },
    srcAuc = { de = "Auctioneer, letzter Scan", en = "Auctioneer, last scan" },
    srcLive = { de = "live geprüft", en = "checked live" },
    new = { de = "Neu", en = "New" },
    markBest = { de = "Bestes Upgrade", en = "Best upgrade" },
    markValue = { de = "Bester Wert", en = "Best value" },
    fAuto = { de = "Am Auktionshaus Preise gleich prüfen", en = "Check prices right away at the auction house" },
    buy = { de = "Kaufen", en = "Buy" },
    buyTitle = { de = "Kaufen?", en = "Buy?" },
    buyChecking = { de = "Prüfe den aktuellen Preis ...", en = "Checking the current price ..." },
    buyGain = { de = "SimGear: %s", en = "SimGear: %s" },
    buyPrice = { de = "Sofortkauf: %s", en = "Buyout: %s" },
    buyNet = { de = "Nettokosten: %s (abzüglich Händlerwert des ersetzten Teils)", en = "Net cost: %s (minus the vendor value of the replaced item)" },
    buyChanged = { de = "Preis geändert: vorher %s, jetzt %s", en = "Price changed: before %s, now %s" },
    buyNext = { de = "Das günstigste wurde gekauft - nächstes Angebot: %s", en = "The cheapest was bought - next offer: %s" },
    buyGone = { de = "Nicht mehr im Angebot.", en = "No longer for sale." },
    buyNoMoney = { de = "Dafür reicht dein Gold nicht.", en = "You do not have enough gold." },
    buyDone = { de = "Gekauft: %s für %s", en = "Bought: %s for %s" },
    buyFail = { de = "Kauf fehlgeschlagen: %s", en = "Purchase failed: %s" },
    cancel = { de = "Abbrechen", en = "Cancel" },
    none = { de = "Keine Upgrades in deinem Budget gefunden.", en = "No upgrades found within your budget." },
    hiddenPricey = { de = "+%d zu teuer", en = "+%d too expensive" },
    progress = { de = "Suche: %s - %d Angebote, %d bewertet", en = "Scanning: %s - %d offers, %d scored" },
    done = { de = "%d Upgrades aus %d Angeboten (%s)", en = "%d upgrades from %d offers (%s)" },
    weapons = { de = "Waffen", en = "Weapons" },
    armor = { de = "Rüstung", en = "Armor" },
    noSimGear = { de = "SimGear Forever mit Schnittstelle fehlt. Bitte SimGear Forever aus UIREWORK-Forever installieren (das Update-Skript baut die Schnittstelle ein).",
        en = "SimGear Forever with its API is missing. Install SimGear Forever from UIREWORK-Forever (the update script adds the API)." },
    notReady = { de = "SimGear kennt deine Ausrüstung noch nicht - kurz warten und nochmal suchen.", en = "SimGear does not know your gear yet - wait a moment and scan again." },
    gain = { de = "SimGear: %s", en = "SimGear: %s" },
    price = { de = "Preis", en = "Price" },
    since = { de = "vor %d Min.", en = "%d min ago" },
    slashHelp = { de = "/sgm öffnen, /sgm scan, /sgm options, /sgm minimap (Knopf an/aus)", en = "/sgm open, /sgm scan, /sgm options, /sgm minimap (button on/off)" },
    filters = { de = "Filter", en = "Filters" },
    fAfford = { de = "Nur was ich bezahlen kann", en = "Only what I can afford" },
    fMax = { de = "Sofortkauf bis", en = "Buyout up to" },
    fTop5 = { de = "Nur die 5 besten pro Platz", en = "Top 5 per slot" },
    fArmor = { de = "Nur die Rüstungsarten der Klasse", en = "Armor types of the class only" },
    fMin = { de = "Upgrade mindestens (%)", en = "Upgrade at least (%)" },
    fNet = { de = "Wert nach Nettokosten", en = "Value by net cost" },
    bestSet = { de = "Bestes Set für", en = "Best set for" },
    setHead = { de = "Bestes Set: %d Teile, zusammen %s, Gewinn %s", en = "Best set: %d items, total %s, gain %s" },
    setNone = { de = "Für dieses Budget passt kein Upgrade.", en = "No upgrade fits this budget." },
    backList = { de = "Zur Liste", en = "Back to list" },
    checking = { de = "Prüfe Sofortkaufpreise: %d von %d", en = "Checking buyouts: %d of %d" },
}

function ns.Lang()
    local s = ns.db and ns.db.lang or "auto"
    if s == "de" or s == "en" then return s end
    return GetLocale() == "deDE" and "de" or "en"
end
function ns.T(k) local e = S[k]; return e and (e[ns.Lang()] or e.en) or k end

local DEFAULTS = { minimap = true, mmAngle = 200, lang = "auto", sort = "gain", slot = "all" }
-- each character has its own sums and switches
local CHAR_DEFAULTS = { maxGoldOn = false, maxGold = 50, onlyAffordable = true, top5 = true, bestArmor = true,
    minGainOn = true, minGain = 1, netCost = false, setBudget = 0, maxAgeOn = true, maxAge = 7, autoLive = true }

-- SimGear's read-only door (SimGearForeverAPI), or nil
function ns.API()
    local api = SimGearForeverAPI
    if type(api) == "table" and api.loadItem and api.compare then return api end
end

-- money as text with the client's coin icons
function ns.Money(copper)
    copper = math.floor(copper or 0)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(copper) end
    return ("%dg %ds %dc"):format(copper / 10000, (copper / 100) % 100, copper % 100)
end

ns.ahOpen = false
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, a1)
    if event == "ADDON_LOADED" then
        if a1 ~= ADDON then return end
        SimGearMarktDB = SimGearMarktDB or {}
        for k, v in pairs(DEFAULTS) do if SimGearMarktDB[k] == nil then SimGearMarktDB[k] = v end end
        ns.db = SimGearMarktDB
        SimGearMarktCharDB = SimGearMarktCharDB or {}
        for k, v in pairs(CHAR_DEFAULTS) do if SimGearMarktCharDB[k] == nil then SimGearMarktCharDB[k] = v end end
        ns.cdb = SimGearMarktCharDB
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("AUCTION_HOUSE_SHOW")
        self:RegisterEvent("AUCTION_HOUSE_CLOSED")
    elseif event == "PLAYER_LOGIN" then
        if ns.BuildOptions then ns.BuildOptions() end
        ns.mmb = ns.MinimapButton and ns.MinimapButton({ name = "SimGearMarktMinimapButton", icon = "Interface\\Icons\\INV_Misc_Coin_02",
            title = ns.T("title"), tip = ns.T("mmTip"), db = ns.db, onClick = function() ns.Toggle() end,
            onRightClick = function() ns.OpenOptions() end })
    elseif event == "AUCTION_HOUSE_SHOW" then
        ns.ahOpen = true
        ns.Scan.Listen(true)
        if ns.OnAHShow then ns.OnAHShow() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ns.ahOpen = false
        ns.Scan.Stop()
        ns.Scan.Listen(false)
        if ns.OnAHClosed then ns.OnAHClosed() end
    end
end)

SLASH_SIMGEARMARKT1 = "/sgm"
SlashCmdList.SIMGEARMARKT = function(msg)
    msg = (msg or ""):lower()
    if msg == "scan" then ns.Scan.Start()
    elseif msg == "options" or msg == "einstellungen" then ns.OpenOptions()
    elseif msg == "debug" then
        -- why an upgrade is not in the list: counts per reason (for bug reports)
        local Scan, mine = ns.Scan, ns.Scan.MyLevel()
        local higher, maxReq = 0, 0
        for _, o in ipairs(Scan.results) do
            if (o.reqLevel or 0) > mine or (o.laterLevel or 0) > mine then higher = higher + 1 end
            maxReq = math.max(maxReq, o.reqLevel or 0)
        end
        local shown = #Scan.Filtered()
        DEFAULT_CHAT_FRAME:AddMessage(("|cff66ccffSimGear Markt|r Angebote %d, Upgrades %d (davon %d über Level %d, höchstes Mindestlevel %d), Regler-Level %d, angezeigt %d, nur wegen Preis aus %d, Gold %s, Nur bezahlbare %s"):format(
            #Scan.offers, #Scan.results, higher, mine, maxReq, Scan.ViewLevel(), shown, Scan.hidden or 0, ns.Money(GetMoney and GetMoney() or 0),
            tostring(ns.cdb.onlyAffordable)))
    elseif msg == "minimap" then ns.db.minimap = not ns.db.minimap; if ns.mmb then ns.mmb.Update() end
    elseif msg == "help" then DEFAULT_CHAT_FRAME:AddMessage(ns.T("slashHelp")) else ns.Toggle() end
end

-- addon compartment (the list button at the minimap): works also with the minimap button hidden
function SimGearMarkt_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then ns.OpenOptions() else ns.Toggle() end
end
