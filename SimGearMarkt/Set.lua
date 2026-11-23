-- SimGear Markt: "best set for X gold" - the combination of upgrades (at most one per slot, two rings, two
-- trinkets, a two-hander or main hand + off hand) with the largest summed SimGear gain within a budget.
-- A multiple-choice knapsack over the slots; prices in silver, rounded so the table stays small. Own code.
local _, ns = ...
local Set = {}
ns.Set = Set

Set.MAX_CELLS = 4000                 -- budget steps; finer budgets are rounded up per item
Set.EMPTY_VALUE = 100                -- an item for an empty slot counts like +100 %
Set.PAIR_POOL = 6                    -- rings/trinkets: pairs are built from the best 6

local GROUP = {
    INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_CLOAK = "back",
    INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands",
    INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_FINGER = "finger",
    INVTYPE_TRINKET = "trinket", INVTYPE_2HWEAPON = "two", INVTYPE_WEAPON = "main", INVTYPE_WEAPONMAINHAND = "main",
    INVTYPE_WEAPONOFFHAND = "off", INVTYPE_SHIELD = "off", INVTYPE_HOLDABLE = "off",
    INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged", INVTYPE_THROWN = "ranged", INVTYPE_RELIC = "ranged",
}
Set.GROUP = GROUP

function Set.Value(o)
    if o.empty then return math.max(o.pct or 0, Set.EMPTY_VALUE) end
    return math.max(0, o.pct or 0)
end

-- options per slot: list of { items = {o...}, cost = copper, value }
local function Options(offers)
    local by = {}
    for _, o in ipairs(offers) do
        local g = GROUP[o.equipLoc or ""]
        if g then by[g] = by[g] or {}; table.insert(by[g], o) end
    end
    local groups = {}
    local function single(list)
        local opts = {}
        for _, o in ipairs(list or {}) do opts[#opts + 1] = { items = { o }, cost = o.price, value = Set.Value(o) } end
        return opts
    end
    local function pairsOf(list)
        local opts = single(list)
        table.sort(list or {}, function(a, b) return Set.Value(a) > Set.Value(b) end)
        local n = math.min(#(list or {}), Set.PAIR_POOL)
        for i = 1, n do
            for j = i + 1, n do
                local a, b = list[i], list[j]
                opts[#opts + 1] = { items = { a, b }, cost = a.price + b.price, value = Set.Value(a) + Set.Value(b) }
            end
        end
        return opts
    end
    for _, g in ipairs({ "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet", "ranged" }) do
        if by[g] then groups[#groups + 1] = single(by[g]) end
    end
    if by.finger then groups[#groups + 1] = pairsOf(by.finger) end
    if by.trinket then groups[#groups + 1] = pairsOf(by.trinket) end
    return groups, by
end

-- multiple-choice knapsack: each group gives at most one option
local function Solve(groups, budget)
    local unit = math.max(100, math.ceil(budget / Set.MAX_CELLS / 100) * 100) -- at least 1 silver
    local cap = math.floor(budget / unit)
    local best = {}
    for c = 0, cap do best[c] = 0 end
    local choice = {}
    for gi, opts in ipairs(groups) do
        local nextBest, pick = {}, {}
        for c = 0, cap do nextBest[c] = best[c]; pick[c] = 0 end
        for oi, opt in ipairs(opts) do
            local w = math.ceil(opt.cost / unit)
            if w <= cap then
                for c = cap, w, -1 do
                    local v = best[c - w] + opt.value
                    if v > nextBest[c] then nextBest[c] = v; pick[c] = oi end
                end
            end
        end
        choice[gi] = pick
        best = nextBest
    end
    -- walk back
    local c, out = cap, {}
    for gi = #groups, 1, -1 do
        local oi = choice[gi][c]
        if oi > 0 then
            local opt = groups[gi][oi]
            out[#out + 1] = opt
            c = c - math.ceil(opt.cost / unit)
        end
    end
    return best[cap], out
end

-- offers: upgrade offers (with price, pct, equipLoc); budget in copper. Returns chosen offers, total cost, total gain.
function Set.Best(offers, budget)
    if not budget or budget <= 0 then return {}, 0, 0 end
    local base, by = Options(offers)
    local function run(weaponGroups)
        local groups = {}
        for _, g in ipairs(base) do groups[#groups + 1] = g end
        for _, g in ipairs(weaponGroups) do groups[#groups + 1] = g end
        return Solve(groups, budget)
    end
    local function single(list)
        local opts = {}
        for _, o in ipairs(list or {}) do opts[#opts + 1] = { items = { o }, cost = o.price, value = Set.Value(o) } end
        return opts
    end
    -- either a two-hander, or main hand + off hand
    local twoV, twoOut = run({ single(by.two) })
    local oneV, oneOut = run({ single(by.main), single(by.off) })
    local value, out = twoV, twoOut
    if oneV > twoV then value, out = oneV, oneOut end
    local items, cost = {}, 0
    for _, opt in ipairs(out) do
        for _, o in ipairs(opt.items) do items[#items + 1] = o; cost = cost + o.price end
    end
    table.sort(items, function(a, b) return Set.Value(a) > Set.Value(b) end)
    return items, cost, value
end
