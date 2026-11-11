-- Demo: made-up listings so the window can be tried alone (/nl lfg demo). They live only in
-- this client, are never sent, and Whisper/Invite/Ask to join do nothing on them.

local ADDON_NAME, ns = ...
local L = ns.LFG
local NL = Nerdelandslaget

local PLAYERS = {
    { "Bøttekott", "WARRIOR", 24, "TD", { 6, 7, 8 }, "Tanking for gear, can heal nada", 1 },
    { "Fiskeboller", "PRIEST", 31, "H", { 11, 12, 13, 14 }, "Heals all evening", 2 },
    { "Pølsemaker", "MAGE", 34, "D", { 13, 14, 15 }, "SM runs please!", 1 },
    { "Brunost", "DRUID", 42, "THD", { 19, 21 }, "", 1 },
    { "Kvikklunsj", "ROGUE", 18, "D", { 1, 2, 3, 4, 5 }, "Anything low level", 2 },
    { "Lefsegutten", "SHAMAN", 57, "HD", { 25, 26, 28, 29, 30 }, "BRD for Hurley", 1 },
    { "Trollkrem", "HUNTER", 60, "D", { 32, 33, 34 }, "", 2 },
    { "Rakfisk", "PALADIN", 37, "TH", { 16, 18 }, "Prot or holy, your pick", 1 },
}

local GROUPS = {
    { "Gubbetrekk", "WARLOCK", 33, "D", 30, 38, { 13, 14 }, { { "PRIEST", 32, "H" }, { "WARRIOR", 34, "T" } }, "SM GY into Lib", 1 },
    { "Hyttetur", "PALADIN", 22, "T", 18, 26, { 5, 4 }, {}, "VC then WC if time", 2 },
    { "Nordlys", "SHAMAN", 58, "H", 55, 60, { 25 }, { { "ROGUE", 59, "D" }, { "MAGE", 60, "D" }, { "WARRIOR", 58, "T" } }, "BRD arena + emp", 1 },
    { "Skamfisk", "DRUID", 45, "T", 43, 50, { 21, 22 }, { { "HUNTER", 44, "D" } }, "", 2 },
}

local function Set(ids)
    local s = {}
    for _, id in ipairs(ids) do s[id] = true end
    return s
end

function L.Demo(on)
    for _, tbl in ipairs({ L.players, L.groups }) do
        for name, e in pairs(tbl) do if e.demo then tbl[name] = nil end end
    end
    if on then
        local t = time()
        for i, p in ipairs(PLAYERS) do
            local name = NL.Full(p[1])
            L.players[name] = { name = name, classFile = p[2], level = p[3], roles = L.RolesSet(p[4]),
                dungeons = Set(p[5]), comment = p[6], guild = p[7], since = t - i * 170, seen = GetTime(), demo = true }
        end
        for i, g in ipairs(GROUPS) do
            local name = NL.Full(g[1])
            local members = {}
            for _, m in ipairs(g[8]) do members[#members + 1] = { classFile = m[1], level = m[2], role = m[3] } end
            L.groups[name] = { name = name, classFile = g[2], level = g[3], role = g[4], min = g[5], max = g[6],
                dungeons = Set(g[7]), members = members, comment = g[9], guild = g[10],
                since = t - i * 240, seen = GetTime(), demo = true }
        end
    end
    L.demo = on
    L.Changed()
end
