-- Dungeons: every WoW Forever dungeon, with its level range. Taken from ForeverDungeonJournal's
-- data (November 2026). "new" marks the ones Blizzard announced for Forever; the journal
-- listed them as not yet playable, so they show a tag.
--
-- The id travels in messages. NEVER renumber or reuse an id: add new dungeons at the end
-- with the next free number. The list is shown sorted by level, not by id.

local ADDON_NAME, ns = ...

local D = {}
ns.Dungeons = D

D.list = {
    { id = 1,  name = "Ragefire Chasm",            short = "RFC",       min = 13, max = 18, zone = "Orgrimmar" },
    { id = 2,  name = "Hall of Thanes",            short = "Thanes",    min = 13, max = 20, zone = "Ironforge, Dun Morogh" },
    { id = 3,  name = "Ruins of Lordaeron",        short = "Ruins",     min = 15, max = 22, zone = "Lordaeron, Tirisfal Glades" },
    { id = 4,  name = "Wailing Caverns",           short = "WC",        min = 15, max = 24, zone = "The Barrens" },
    { id = 5,  name = "The Deadmines",             short = "VC",        min = 17, max = 26, zone = "Westfall" },
    { id = 6,  name = "Shadowfang Keep",           short = "SFK",       min = 20, max = 30, zone = "Silverpine Forest" },
    { id = 7,  name = "Blackfathom Deeps",         short = "BFD",       min = 24, max = 32, zone = "Ashenvale" },
    { id = 8,  name = "The Stockade",              short = "Stocks",    min = 24, max = 32, zone = "Stormwind City" },
    { id = 9,  name = "Excavation Site: Wetlands", short = "Excavation", min = 26, max = 33, zone = "Wetlands" },
    { id = 10, name = "City of Dalaran",           short = "Dalaran",   min = 28, max = 33, zone = "Alterac Mountains" },
    { id = 11, name = "Gnomeregan",                short = "Gnomer",    min = 29, max = 38, zone = "Dun Morogh" },
    { id = 12, name = "Razorfen Kraul",            short = "RFK",       min = 29, max = 38, zone = "The Barrens" },
    { id = 13, name = "Scarlet Monastery: Graveyard", short = "SM GY",  min = 30, max = 38, zone = "Tirisfal Glades" },
    { id = 14, name = "Scarlet Monastery: Library", short = "SM Lib",   min = 33, max = 41, zone = "Tirisfal Glades" },
    { id = 15, name = "Scarlet Monastery: Armory", short = "SM Arm",    min = 34, max = 42, zone = "Tirisfal Glades" },
    { id = 16, name = "Scarlet Monastery: Cathedral", short = "SM Cath", min = 36, max = 45, zone = "Tirisfal Glades" },
    { id = 17, name = "The Drowned City",          short = "Drowned",   min = 35, max = 40, zone = "Stranglethorn Vale", new = true },
    { id = 18, name = "Razorfen Downs",            short = "RFD",       min = 37, max = 46, zone = "The Barrens" },
    { id = 19, name = "Uldaman",                   short = "Ulda",      min = 38, max = 48, zone = "Badlands" },
    { id = 20, name = "Krol'dok Stronghold",       short = "Krol'dok",  min = 40, max = 45, zone = "Riverglades", new = true },
    { id = 21, name = "Zul'Farrak",                short = "ZF",        min = 43, max = 50, zone = "Tanaris" },
    { id = 22, name = "Maraudon",                  short = "Mara",      min = 45, max = 52, zone = "Desolace" },
    { id = 23, name = "Alcaz Prison",              short = "Alcaz",     min = 48, max = 53, zone = "Dustwallow Marsh", new = true },
    { id = 24, name = "Sunken Temple",             short = "ST",        min = 49, max = 56, zone = "Swamp of Sorrows" },
    { id = 25, name = "Blackrock Depths",          short = "BRD",       min = 52, max = 60, zone = "Blackrock Mountain" },
    { id = 26, name = "Lower Blackrock Spire",     short = "LBRS",      min = 55, max = 60, zone = "Blackrock Mountain" },
    { id = 27, name = "Upper Blackrock Spire",     short = "UBRS",      min = 55, max = 60, zone = "Blackrock Mountain" },
    { id = 28, name = "Dire Maul: East",           short = "DM East",   min = 55, max = 60, zone = "Feralas" },
    { id = 29, name = "Dire Maul: West",           short = "DM West",   min = 57, max = 60, zone = "Feralas" },
    { id = 30, name = "Dire Maul: North",          short = "DM North",  min = 57, max = 60, zone = "Feralas" },
    { id = 31, name = "Blackmaw Hold",             short = "Blackmaw",  min = 55, max = 60, zone = "Azshara", new = true },
    { id = 32, name = "Scholomance",               short = "Scholo",    min = 58, max = 60, zone = "Western Plaguelands" },
    { id = 33, name = "Stratholme: Living",        short = "Strat Live", min = 58, max = 60, zone = "Eastern Plaguelands" },
    { id = 34, name = "Stratholme: Undead",        short = "Strat UD",  min = 58, max = 60, zone = "Eastern Plaguelands" },
    { id = 35, name = "Shaper's Terrace",          short = "Shaper's",  min = 58, max = 60, zone = "Un'Goro Crater", new = true },
}

D.byId = {}
for _, d in ipairs(D.list) do D.byId[d.id] = d end

table.sort(D.list, function(a, b)
    if a.min ~= b.min then return a.min < b.min end
    if a.max ~= b.max then return a.max < b.max end
    return a.id < b.id
end)

D.MAX_LEVEL = 60

---------------------------------------------------------------------------
-- Level colours, like the game's own dungeon list
---------------------------------------------------------------------------

-- "red" (too low), "orange" (a bit low), "green" (in range), "gray" (outgrown)
function D.Standing(d, level)
    level = level or UnitLevel("player")
    if level < d.min - 2 then return "red" end
    if level < d.min then return "orange" end
    if level <= d.max then return "green" end
    return "gray"
end

local STANDING_HEX = { red = "ffe0503f", orange = "ffef8a3a", green = "ff7bd65e", gray = "ff8a8a8a" }

function D.RangeText(d, level)
    return "|c" .. STANDING_HEX[D.Standing(d, level)] .. d.min .. "-" .. d.max .. "|r"
end

-- Dungeons that suit a level: in range, or at most a level below it.
function D.Suits(d, level)
    level = level or UnitLevel("player")
    return level >= d.min - 1 and level <= d.max
end

---------------------------------------------------------------------------
-- Sets of ids <-> the "3,4,12" form used in messages
---------------------------------------------------------------------------

function D.Encode(set)
    local ids = {}
    for id in pairs(set) do
        if D.byId[id] then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

function D.Decode(s)
    local set = {}
    if type(s) ~= "string" then return set end
    for n in s:gmatch("%d+") do
        local id = tonumber(n)
        if D.byId[id] then set[id] = true end
    end
    return set
end

function D.Count(set)
    local n = 0
    for _ in pairs(set or {}) do n = n + 1 end
    return n
end

-- In list (level) order.
function D.Sorted(set)
    local out = {}
    for _, d in ipairs(D.list) do
        if set and set[d.id] then out[#out + 1] = d end
    end
    return out
end

function D.Overlaps(a, b)
    for id in pairs(a or {}) do
        if b and b[id] then return true end
    end
    return false
end

-- "WC, VC, SFK +2" for a row; "Wailing Caverns" alone if only one.
function D.Summary(set, maxShown)
    local sorted = D.Sorted(set)
    if #sorted == 0 then return "|cff8a8a8aAny dungeon|r" end
    if #sorted == 1 then return sorted[1].name end
    maxShown = maxShown or 4
    local names = {}
    for i = 1, math.min(#sorted, maxShown) do names[i] = sorted[i].short end
    local s = table.concat(names, ", ")
    if #sorted > maxShown then s = s .. " |cff8a8a8a+" .. (#sorted - maxShown) .. "|r" end
    return s
end

-- The level range covering a set of dungeons (for a new group's default).
function D.Span(set)
    local lo, hi
    for id in pairs(set or {}) do
        local d = D.byId[id]
        if d then
            lo = lo and math.min(lo, d.min) or d.min
            hi = hi and math.max(hi, d.max) or d.max
        end
    end
    return lo, hi
end
