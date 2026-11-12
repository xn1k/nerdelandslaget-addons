-- Dungeon Finder: who's looking, for what, and the messages that tell everyone.
--
-- Two kinds of listing, both carried over the suite's hidden channel (Nerdelandslaget.Comm):
--   a player  - roles (any of T, H, D), any number of dungeons, a comment
--   a group   - the leader's role, the members' roles, a level range, dungeons, a comment;
--               what it still needs is worked out from the roles (1 tank, 1 healer, 3 damage)
-- A player asks to join a group with a whisper; the leader sees them as an applicant and
-- invites, whispers or declines. Listings are repeated every minute and forgotten when
-- nobody has heard them for a little over three.
--
-- Messages (prefix NLLFG1, fields separated by ';', free text last):
--   Q;version                                   who's listed? (everyone listed answers)
--   P;guild;classID;level;roles;mins;dungeons;comment
--   G;guild;classID;level;role;min;max;mins;dungeons;members;comment
--        members: classID.level.role for each member but the leader, comma-separated
--   X;P | X;G                                   no longer listed
--   A;classID;level;roles;comment               (whisper) I'd like to join your group
--   N;reason                                    (whisper) declined / closed / full
--   R;roles                                     (party) the roles I can play in this group

local ADDON_NAME, ns = ...
local NL = Nerdelandslaget
local D = ns.Dungeons
local Comm = NL.Comm
local T = NL.Theme
local C = T.c

local L = {}
ns.LFG = L
ns.NL = NL

local PREFIX = "NLLFG1"
local HEARTBEAT = 60          -- seconds between repeats of our listing
local EXPIRE = 200            -- forget a listing not heard for this long
local APPLY_EXPIRE = 15 * 60
local RESUME_WINDOW = 30 * 60 -- a listing survives a /reload or short logout this long
local COMMENT_MAX = 60
local COMP = { T = 1, H = 1, D = 3 }

L.PREFIX = PREFIX
L.COMMENT_MAX = COMMENT_MAX

local ACCOUNT_DEFAULTS = {
    notifyGroups = true,      -- tell me about new groups that fit, while I'm listed
    notifyApplicants = true,
    notifyPlayers = false,    -- tell a leader about new players that fit
    toastGroups = true,       -- pop up when a new group is listed that I'd want
    toastMode = "level",      -- "level": takes my level, "range": toastMin-toastMax,
    toastMin = 1,             -- "dungeons": is for one of toastDungeons
    toastMax = 60,
    toastDungeons = {},
    toastApplicants = true,   -- pop up (with Invite/Whisper) when someone asks to join
    sound = true,
    autoDelistOnJoin = true,
    autoDelistWhenFull = true,
    onlyFits = false,
    browseKind = "groups",
    browseDungeon = 0,        -- 0 = all
    window = {},
}

local CHAR_DEFAULTS = {
    roles = {},
    dungeons = {},
    comment = "",
    listed = false,
    listedAt = 0,
    group = { dungeons = {}, comment = "", role = "D", min = 0, max = 0, listed = false, listedAt = 0 },
    lastActive = 0,
}

-- Sensible first roles by class; everything stays selectable.
local CLASS_DEFAULT_ROLE = { WARRIOR = "T", PRIEST = "H", PALADIN = "H", SHAMAN = "H", DRUID = "H" }

local IsSecret = NL.IsSecret

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

L.players = {}        -- [name] = listing
L.groups = {}         -- [leader] = listing
L.applicants = {}     -- [name] = { name, classFile, level, roles, comment, at }
L.applied = {}        -- [leader] = { at, declined = reason? }
L.partyRoles = {}     -- [name] = roles set, from R messages
L.roleOverride = {}   -- [name] = role the leader picked for a member
L.notified = {}       -- [name] = true once we've told the user about this listing
L.toasted = {}        -- [leader] = true once a new-group pop-up has shown for their listing
L.quietUntil = math.huge  -- no new-group pop-ups for what we hear right after logging in
L.newerVersion = nil

function L.Log(...) NL.log("[LFG]", ...) end

---------------------------------------------------------------------------
-- Change listeners (the window)
---------------------------------------------------------------------------

local listeners = {}
local changePending = false
function L.OnChange(fn) listeners[#listeners + 1] = fn end
function L.Changed()
    if changePending then return end
    changePending = true
    C_Timer.After(0.05, function()
        changePending = false
        for _, fn in ipairs(listeners) do pcall(fn) end
    end)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function L.Allowed()
    return NL.MyGuild() ~= nil
end

local function MyClass()
    local _, file, id = UnitClass("player")
    return file, id
end

local function MyLevel()
    return NL.Plain(UnitLevel("player")) or 1
end

function L.RolesString(set)
    local s = ""
    for _, r in ipairs(T.ROLES) do
        if set and set[r] then s = s .. r end
    end
    return s
end

function L.RolesSet(s)
    local set = {}
    if type(s) == "string" then
        for _, r in ipairs(T.ROLES) do
            if s:find(r, 1, true) then set[r] = true end
        end
    end
    return set
end

-- "tank or healer"
function L.RoleNames(set)
    local names = {}
    for _, r in ipairs(T.ROLES) do
        if set and set[r] then names[#names + 1] = T.ROLE_NAME[r]:lower() end
    end
    if #names == 0 then return "anything" end
    return table.concat(names, " or ")
end

local function Minutes(since)
    if not since or since <= 0 then return 0 end
    return math.max(0, math.floor((time() - since) / 60))
end

function L.Sound()
    if not L.db.sound then return end
    local id = SOUNDKIT and (SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION or SOUNDKIT.READY_CHECK) or 8960
    pcall(PlaySound, id)
end

function L.Notify(msg, sound)
    NL.Print(msg)
    if sound then L.Sound() end
end

---------------------------------------------------------------------------
-- Pop-ups
---------------------------------------------------------------------------

-- The levels "level" and "range" pop-ups are for: my level, or the range in the options.
function L.ToastRange()
    if L.db.toastMode ~= "range" then
        local l = MyLevel()
        return l, l
    end
    local lo, hi = tonumber(L.db.toastMin) or 1, tonumber(L.db.toastMax) or D.MAX_LEVEL
    if lo > hi then lo, hi = hi, lo end
    return lo, hi
end

local function TakesLevels(e, lo, hi)
    local gmin, gmax = e.min or 0, e.max or 0
    if gmin <= 0 or gmax <= 0 then return true end
    return gmin <= hi and gmax >= lo
end

-- Does a new group earn a pop-up under my settings? In "dungeons" mode a group for any of
-- my dungeons does; one listed for no dungeon in particular does if it takes my level.
function L.ToastWants(e)
    if L.db.toastMode == "dungeons" then
        if next(e.dungeons or {}) then return D.Overlaps(L.db.toastDungeons, e.dungeons) end
        local l = MyLevel()
        return TakesLevels(e, l, l)
    end
    return TakesLevels(e, L.ToastRange())
end

local function NeedsText(e)
    local needs, open = L.Needs(e.role, e.members)
    local parts = {}
    for _, r in ipairs(T.ROLES) do
        if needs[r] > 0 then parts[#parts + 1] = (needs[r] > 1 and (needs[r] .. " ") or "") .. T.ROLE_NAME[r]:lower() end
    end
    if #parts == 0 then return open > 0 and "Needs anyone" or "Full" end
    return "Needs " .. table.concat(parts, ", ")
end

-- The pop-up for a group: click it to see the group, or ask to join right there.
function L.GroupToast(e)
    NL.Toast.Show({
        key = "group:" .. e.name,
        title = "New group  " .. T.Color("Lvl " .. (e.min or 0) .. "-" .. (e.max or 0), C.cream),
        classFile = e.classFile,
        text = NL.ClassName(e.name, e.classFile) .. ":  " .. D.Summary(e.dungeons, 3),
        sub = NeedsText(e) .. ((e.comment and e.comment ~= "") and ("  ·  \"" .. e.comment .. "\"") or ""),
        duration = 15,
        onClick = function() ns.Win.ShowGroup(e.name) end,
        buttons = { { "Ask to join", function() if not e.demo then L.Apply(e.name) end end, "primary" } },
    })
end

-- A new group was listed: pop up if it's in my range and I could join it.
local function MaybeToastGroup(e)
    if not L.db.toastGroups or e.demo or L.toasted[e.name] then return false end
    if GetTime() < L.quietUntil then return false end
    if L.char.group.listed or IsInGroup() then return false end
    local _, open = L.Needs(e.role, e.members)
    if open <= 0 or not L.ToastWants(e) then return false end
    L.toasted[e.name] = true
    L.GroupToast(e)
    L.Sound()
    return true
end

function L.ApplicantToast(a)
    local who = NL.ClassName(a.name, a.classFile) .. T.Color("  " .. (a.level or "?"), C.dim)
    NL.Toast.Show({
        key = "app:" .. a.name,
        title = "Wants to join your group",
        classFile = a.classFile,
        text = who .. "  ·  " .. L.RoleNames(a.roles),
        sub = (a.comment and a.comment ~= "") and ("\"" .. a.comment .. "\"") or "Click to see your group",
        duration = 40,
        onClick = function() ns.Win.Open(3) end,
        buttons = {
            { "Invite", function() if not a.demo then L.InviteApplicant(a.name) end end, "primary" },
            { "Whisper", function() if not a.demo then NL.Whisper(a.name) end end },
        },
    })
end

-- /nl lfg test, and the options' test button
function L.TestToasts()
    local lvl = MyLevel()
    local dungeons, n = {}, 0
    for _, d in ipairs(D.list) do
        if n < 2 and D.Suits(d, lvl) then dungeons[d.id] = true n = n + 1 end
    end
    L.GroupToast({
        demo = true, name = "Testy-" .. (GetNormalizedRealmName() or ""), classFile = "WARRIOR",
        min = math.max(1, lvl - 2), max = math.min(D.MAX_LEVEL, lvl + 4), role = "T",
        members = {}, dungeons = dungeons, comment = "a test pop-up",
    })
    L.Sound()
end

function L.InGroupNotLeader()
    return IsInGroup() and not UnitIsGroupLeader("player")
end

---------------------------------------------------------------------------
-- The group I lead: members and what we still need
---------------------------------------------------------------------------

-- Members other than me: { name, classFile, level, role ("T"/"H"/"D" or nil), roles (set) }
function L.Members()
    local out = {}
    if not IsInGroup() then return out end
    local prefix, n = "party", 4
    if IsInRaid() then prefix, n = "raid", 40 end
    local me = NL.Me()
    for i = 1, n do
        local unit = prefix .. i
        -- no UnitExists/UnitIsUnit: they can come back secret; a readable name is enough
        local rawName = UnitName(unit)
        local secret = IsSecret(rawName)
        local name = (not secret and rawName ~= nil) and NL.Full(rawName) or nil
        if (secret or rawName ~= nil) and (name == nil or name ~= me) then
            local _, classFile, classID = UnitClass(unit)
            if IsSecret(classFile) then classFile = nil end
            if IsSecret(classID) then classID = nil end
            local level = NL.Plain(UnitLevel(unit))
            local roles = name and L.partyRoles[name] or {}
            local role = name and L.roleOverride[name]
            if not role then
                local assigned = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
                if not IsSecret(assigned) then
                    role = (assigned == "TANK" and "T") or (assigned == "HEALER" and "H")
                        or (assigned == "DAMAGER" and "D") or nil
                end
            end
            if not role then
                local only = L.RolesString(roles)
                if #only == 1 then role = only end
            end
            out[#out + 1] = { name = name, unit = unit, classFile = classFile, classID = classID,
                level = level, role = role, roles = roles }
        end
    end
    return out
end

-- needs = { T = n, H = n, D = n }, open slots, size. members: list of { role }.
function L.Needs(leaderRole, members)
    local filled = { T = 0, H = 0, D = 0 }
    if leaderRole and filled[leaderRole] then filled[leaderRole] = filled[leaderRole] + 1 end
    local unknown = 0
    for _, m in ipairs(members or {}) do
        if m.role and filled[m.role] then filled[m.role] = filled[m.role] + 1 else unknown = unknown + 1 end
    end
    local size = 1 + #(members or {})
    local open = math.max(0, 5 - size)
    local needs = {}
    local total = 0
    for _, r in ipairs(T.ROLES) do
        needs[r] = math.max(0, COMP[r] - filled[r])
        total = total + needs[r]
    end
    -- members without a known role (and anyone over the plan) take the places of damage first
    for _, r in ipairs({ "D", "H", "T" }) do
        while total > open and needs[r] > 0 do
            needs[r] = needs[r] - 1
            total = total - 1
        end
    end
    return needs, open, size, unknown
end

---------------------------------------------------------------------------
-- My listings as entries (the same shape as others', so the lists can show them)
---------------------------------------------------------------------------

function L.MyPlayerEntry()
    local c = L.char
    if not c.listed then return nil end
    local classFile = MyClass()
    return {
        name = NL.Me(), classFile = classFile, level = MyLevel(), guild = NL.MyGuild(),
        roles = c.roles, dungeons = c.dungeons, comment = c.comment,
        since = c.listedAt, seen = GetTime(), self = true,
    }
end

function L.MyGroupEntry()
    local g = L.char.group
    if not g.listed then return nil end
    local classFile = MyClass()
    local members = L.Members()
    return {
        name = NL.Me(), classFile = classFile, level = MyLevel(), guild = NL.MyGuild(),
        role = g.role, min = g.min, max = g.max, dungeons = g.dungeons, comment = g.comment,
        members = members, since = g.listedAt, seen = GetTime(), self = true,
    }
end

---------------------------------------------------------------------------
-- Fitting
---------------------------------------------------------------------------

-- Does a group fit me? Returns fits, and a list of reasons it doesn't.
function L.GroupFitsMe(g)
    local why = {}
    local level = MyLevel()
    if (g.min or 0) > 0 and level < g.min then why[#why + 1] = "you're below level " .. g.min end
    if (g.max or 0) > 0 and level > g.max then why[#why + 1] = "you're above level " .. g.max end
    local needs, open = L.Needs(g.role, g.members)
    if open <= 0 then
        why[#why + 1] = "the group is full"
    elseif next(L.char.roles) then
        local ok = false
        for r in pairs(L.char.roles) do if needs[r] and needs[r] > 0 then ok = true end end
        if not ok then why[#why + 1] = "it doesn't need your roles" end
    end
    if next(L.char.dungeons) and next(g.dungeons or {}) and not D.Overlaps(L.char.dungeons, g.dungeons) then
        why[#why + 1] = "none of your dungeons"
    end
    return #why == 0, why
end

-- Does a player fit the group I'm leading (or setting up)?
function L.PlayerFitsMyGroup(p)
    local g = L.char.group
    local why = {}
    if (g.min or 0) > 0 and (p.level or 0) < g.min then why[#why + 1] = "below level " .. g.min end
    if (g.max or 0) > 0 and (p.level or 0) > g.max then why[#why + 1] = "above level " .. g.max end
    local needs = L.Needs(g.role, L.Members())
    local ok = false
    for r in pairs(p.roles or {}) do if needs[r] and needs[r] > 0 then ok = true end end
    if not ok then why[#why + 1] = "no role you need" end
    if next(g.dungeons) and next(p.dungeons or {}) and not D.Overlaps(g.dungeons, p.dungeons) then
        why[#why + 1] = "none of your dungeons"
    end
    return #why == 0, why
end

function L.Leading()
    return L.char.group.listed
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function Send(text, key)
    if not L.Allowed() then return end
    Comm.Broadcast(PREFIX, text, key)
end

local function PlayerLine()
    local c = L.char
    local _, classID = MyClass()
    return table.concat({ "P", NL.MyGuild() or 0, classID or 0, MyLevel(), L.RolesString(c.roles),
        Minutes(c.listedAt), D.Encode(c.dungeons), Comm.Clean(c.comment, COMMENT_MAX) }, ";")
end

local function GroupLine()
    local g = L.char.group
    local _, classID = MyClass()
    local members = {}
    for _, m in ipairs(L.Members()) do
        members[#members + 1] = (m.classID or 0) .. "." .. (m.level or 0) .. "." .. (m.role or "?")
    end
    return table.concat({ "G", NL.MyGuild() or 0, classID or 0, MyLevel(), g.role or "D", g.min or 0, g.max or 0,
        Minutes(g.listedAt), D.Encode(g.dungeons), table.concat(members, ","),
        Comm.Clean(g.comment, COMMENT_MAX) }, ";")
end

function L.SendListing()
    if L.char.listed then Send(PlayerLine(), "player") end
    if L.char.group.listed then Send(GroupLine(), "group") end
    L.char.lastActive = time()
end

-- Repeat our listing soon, once, however many times this is asked for.
local soonPending = false
function L.SendSoon(delay)
    if soonPending then return end
    soonPending = true
    C_Timer.After(delay or 1, function()
        soonPending = false
        L.SendListing()
    end)
end

local lastQuery = 0
function L.Query(force)
    if not L.Allowed() then return end
    if not force and GetTime() - lastQuery < 30 then return end
    lastQuery = GetTime()
    Send("Q;" .. (NL.VERSION or "0"), "query")
end

---------------------------------------------------------------------------
-- Listing and delisting
---------------------------------------------------------------------------

function L.CanListSelf()
    if not L.Allowed() then return false, "Only for members of the Nerdelandslaget guilds." end
    if not next(L.char.roles) then return false, "Pick at least one role." end
    if IsInGroup() then return false, "You're already in a group." end
    return true
end

function L.ListSelf()
    local ok, why = L.CanListSelf()
    if not ok then L.Notify(why) return false end
    local c = L.char
    if not c.listed then
        c.listed = true
        c.listedAt = time()
        L.notified = {}
    end
    Send(PlayerLine(), "player")
    L.Changed()
    return true
end

function L.DelistSelf(quiet)
    local c = L.char
    if not c.listed then return end
    c.listed = false
    Send("X;P", "player")
    if not quiet then NL.Print("You're no longer listed.") end
    L.Changed()
end

function L.CanListGroup()
    if not L.Allowed() then return false, "Only for members of the Nerdelandslaget guilds." end
    if L.InGroupNotLeader() then return false, "Only the group leader can list the group." end
    local g = L.char.group
    if (g.min or 0) > 0 and (g.max or 0) > 0 and g.min > g.max then return false, "The level range is upside down." end
    local _, open = L.Needs(g.role, L.Members())
    if open <= 0 then return false, "Your group is already full." end
    return true
end

function L.ListGroup()
    local ok, why = L.CanListGroup()
    if not ok then L.Notify(why) return false end
    local g = L.char.group
    if L.char.listed then L.DelistSelf(true) end
    if not g.listed then
        g.listed = true
        g.listedAt = time()
    end
    Send(GroupLine(), "group")
    L.Changed()
    return true
end

function L.DelistGroup(quiet, reason)
    local g = L.char.group
    if not g.listed then return end
    g.listed = false
    Send("X;G", "group")
    for name in pairs(L.applicants) do
        Comm.Whisper(PREFIX, "N;" .. (reason or "closed"), name)
        NL.Toast.Hide("app:" .. name)
    end
    wipe(L.applicants)
    NL.MapButton.Attention(false)
    if not quiet then NL.Print("Your group is no longer listed.") end
    L.Changed()
end

---------------------------------------------------------------------------
-- Applying (player -> leader) and answering (leader -> player)
---------------------------------------------------------------------------

function L.Apply(leader)
    if not L.Allowed() or not leader then return end
    local _, classID = MyClass()
    local roles = L.RolesString(L.char.roles)
    if roles == "" then roles = "D" end
    Comm.Whisper(PREFIX, table.concat({ "A", classID or 0, MyLevel(), roles,
        Comm.Clean(L.char.comment, COMMENT_MAX) }, ";"), leader)
    L.applied[leader] = { at = GetTime() }
    L.Changed()
end

function L.Decline(name, reason)
    if not L.applicants[name] then return end
    L.applicants[name] = nil
    NL.Toast.Hide("app:" .. name)
    Comm.Whisper(PREFIX, "N;" .. (reason or "declined"), name)
    if not next(L.applicants) then NL.MapButton.Attention(false) end
    L.Changed()
end

function L.InviteApplicant(name)
    local a = L.applicants[name]
    if a then a.invited = true end
    NL.Invite(name)
    L.Changed()
end

function L.ApplicantCount()
    local n = 0
    for _ in pairs(L.applicants) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

local function NewerThan(a, b)
    local function parts(v)
        local t = {}
        for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end
        return t
    end
    local pa, pb = parts(a), parts(b)
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

local function Guild(v)
    local g = tonumber(v)
    if g == 1 or g == 2 then return g end
    return nil
end

local function Level(v)
    local n = tonumber(v)
    if n and n >= 1 and n <= 100 then return math.floor(n) end
    return nil
end

local handlers = {}

handlers.Q = function(f, from)
    local v = f[2]
    if v and NewerThan(v, NL.VERSION) and not L.newerVersion then
        L.newerVersion = v
        NL.Print("A newer version (" .. v .. ") is out. Grab it when you can.")
    end
    if L.char.listed or L.char.group.listed then
        L.SendSoon(0.5 + math.random() * 3.5)
    end
end

handlers.P = function(f, from)
    local g, level = Guild(f[2]), Level(f[4])
    if not (g and level) then return end
    local classFile = NL.ClassFile(f[3])
    local old = L.players[from]
    local e = old or {}
    e.name, e.classFile, e.level, e.guild = from, classFile, level, g
    e.roles = L.RolesSet(f[5])
    e.since = time() - (tonumber(f[6]) or 0) * 60
    e.dungeons = D.Decode(f[7])
    e.comment = f[8] or ""
    e.seen = GetTime()
    L.players[from] = e
    if not old and L.Leading() and L.db.notifyPlayers and not L.notified[from] then
        if L.PlayerFitsMyGroup(e) then
            L.notified[from] = true
            L.Notify(NL.ClassName(from, classFile) .. " (" .. level .. ") is looking for a group and fits yours.", true)
        end
    end
    L.Changed()
end

handlers.G = function(f, from)
    local g, level = Guild(f[2]), Level(f[4])
    if not (g and level) then return end
    local classFile = NL.ClassFile(f[3])
    local members = {}
    for m in (f[10] or ""):gmatch("[^,]+") do
        local cid, lvl, role = strsplit(".", m)
        members[#members + 1] = {
            classFile = NL.ClassFile(cid), level = Level(lvl),
            role = (role == "T" or role == "H" or role == "D") and role or nil,
        }
        if #members >= 4 then break end
    end
    local old = L.groups[from]
    local e = old or {}
    e.name, e.classFile, e.level, e.guild = from, classFile, level, g
    e.role = (f[5] == "T" or f[5] == "H" or f[5] == "D") and f[5] or "D"
    e.min, e.max = Level(f[6]) or 0, Level(f[7]) or 0
    e.since = time() - (tonumber(f[8]) or 0) * 60
    e.dungeons = D.Decode(f[9])
    e.members = members
    e.comment = f[11] or ""
    e.seen = GetTime()
    L.groups[from] = e
    local toasted = not old and MaybeToastGroup(e)
    if L.char.listed and L.db.notifyGroups and not L.notified[from] and L.GroupFitsMe(e) then
        L.notified[from] = true
        if toasted then NL.Print("New group that fits you: " .. NL.ClassName(from, classFile) .. "'s "
            .. D.Summary(e.dungeons, 3) .. " (" .. e.min .. "-" .. e.max .. ").") else
        L.Notify("New group that fits you: " .. NL.ClassName(from, classFile) .. "'s "
            .. D.Summary(e.dungeons, 3) .. " (" .. e.min .. "-" .. e.max .. "). /nl to look.", true) end
    end
    L.Changed()
end

handlers.X = function(f, from)
    if f[2] == "P" then L.players[from] = nil
    elseif f[2] == "G" then
        L.groups[from] = nil
        L.toasted[from] = nil
        NL.Toast.Hide("group:" .. from)
    end
    L.Changed()
end

handlers.A = function(f, from, via)
    if via ~= "WHISPER" then return end
    if not L.char.group.listed then
        Comm.Whisper(PREFIX, "N;closed", from)
        return
    end
    local isNew = not L.applicants[from]
    L.applicants[from] = {
        name = from, classFile = NL.ClassFile(f[2]), level = Level(f[3]) or 0,
        roles = L.RolesSet(f[4]), comment = f[5] or "", at = GetTime(),
    }
    if isNew then
        local a = L.applicants[from]
        if L.db.notifyApplicants then
            NL.Print(NL.ClassName(from, a.classFile) .. " (" .. a.level .. ", " .. L.RolesString(a.roles)
                .. ") wants to join your group. /nl to answer.")
        end
        if L.db.toastApplicants then L.ApplicantToast(a) end
        if L.db.notifyApplicants or L.db.toastApplicants then
            L.Sound()
            NL.MapButton.Attention(true)
        end
    end
    L.Changed()
end

handlers.N = function(f, from, via)
    if via ~= "WHISPER" then return end
    local a = L.applied[from]
    if not a then return end
    a.declined = f[2] or "declined"
    local word = (a.declined == "full" and "is full") or (a.declined == "closed" and "is no longer listed") or "declined"
    NL.Print(NL.Short(from) .. "'s group " .. word .. ".")
    L.Changed()
end

handlers.R = function(f, from, via)
    if via ~= "PARTY" then return end
    L.partyRoles[from] = L.RolesSet(f[2])
    if L.char.group.listed then L.SendSoon(1) end
    L.Changed()
end

Comm.Register(PREFIX, function(text, from, via)
    if not L.char or not L.Allowed() then return end
    local f = { strsplit(";", text) }
    local h = handlers[f[1]]
    if h then h(f, from, via) end
end)

---------------------------------------------------------------------------
-- Upkeep
---------------------------------------------------------------------------

local function Expire()
    local now = GetTime()
    local changed = false
    for _, tbl in ipairs({ L.players, L.groups }) do
        for name, e in pairs(tbl) do
            if not e.demo and now - (e.seen or 0) > EXPIRE then
                tbl[name] = nil
                changed = true
            end
        end
    end
    for name, a in pairs(L.applicants) do
        if now - a.at > APPLY_EXPIRE then
            L.applicants[name] = nil
            NL.Toast.Hide("app:" .. name)
            changed = true
        end
    end
    for name, a in pairs(L.applied) do
        if now - a.at > APPLY_EXPIRE then L.applied[name] = nil changed = true end
    end
    if changed then L.Changed() end
end

local rosterPending = false
local function OnRoster()
    if rosterPending then return end
    rosterPending = true
    C_Timer.After(0.5, function()
        rosterPending = false
        local c = L.char
        if IsInGroup() then
            if c.listed and L.db.autoDelistOnJoin then
                L.DelistSelf(true)
                NL.Print("You're in a group now, so you're no longer listed.")
            end
            wipe(L.applied)
            for leader in pairs(L.groups) do NL.Toast.Hide("group:" .. leader) end
            -- tell the leader what I can play
            local roles = c.group.listed and { [c.group.role] = true } or c.roles
            Comm.Party(PREFIX, "R;" .. L.RolesString(roles), "roles")
        end
        if c.group.listed then
            if L.InGroupNotLeader() then
                L.DelistGroup(true)
                NL.Print("You're no longer the group leader, so the group is no longer listed.")
            else
                local members = L.Members()
                for _, m in ipairs(members) do
                    if m.name and L.applicants[m.name] then
                        L.applicants[m.name] = nil
                        NL.Toast.Hide("app:" .. m.name)
                    end
                end
                local _, open = L.Needs(c.group.role, members)
                if open <= 0 and L.db.autoDelistWhenFull then
                    L.DelistGroup(true, "full")
                    NL.Print("Your group is full, so it's no longer listed. Have fun!")
                else
                    L.SendSoon(1)
                end
            end
        end
        -- forget roles of people who left
        local present = {}
        for _, m in ipairs(L.Members()) do if m.name then present[m.name] = true end end
        for name in pairs(L.partyRoles) do if not present[name] then L.partyRoles[name] = nil end end
        for name in pairs(L.roleOverride) do if not present[name] then L.roleOverride[name] = nil end end
        L.Changed()
    end)
end

-- Leader: cycle a member's role (T -> H -> D -> T).
function L.CycleMemberRole(name, current)
    local nextRole = { T = "H", H = "D", D = "T" }
    L.roleOverride[name] = nextRole[current or "D"] or "T"
    if L.char.group.listed then L.SendSoon(0.5) end
    L.Changed()
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

NL.On("ADDON_LOADED", function(name)
    if name ~= ADDON_NAME then return end
    NerdelandslagetLFGDB = NerdelandslagetLFGDB or {}
    NerdelandslagetLFGCharDB = NerdelandslagetLFGCharDB or {}
    L.db = NL.ApplyDefaults(NerdelandslagetLFGDB, ACCOUNT_DEFAULTS)
    local fresh = next(NerdelandslagetLFGCharDB) == nil
    L.char = NL.ApplyDefaults(NerdelandslagetLFGCharDB, CHAR_DEFAULTS)
    if fresh then
        local _, classFile = UnitClass("player")
        L.char.roles = { [CLASS_DEFAULT_ROLE[classFile] or "D"] = true }
        L.char.group.role = CLASS_DEFAULT_ROLE[classFile] or "D"
    end
    -- listings older than a short logout don't come back
    if time() - (L.char.lastActive or 0) > RESUME_WINDOW then
        L.char.listed = false
        L.char.group.listed = false
    end
end)

table.insert(NL.startup, function()
    C_Timer.NewTicker(10, Expire)
    C_Timer.NewTicker(HEARTBEAT, function()
        if L.char.listed or L.char.group.listed then L.SendListing() end
    end)
    Comm.WhenReady(function()
        if not L.Allowed() then
            L.char.listed = false
            L.char.group.listed = false
            L.Log("not in a Nerdelandslaget guild:", NL.MyGuildName())
            return
        end
        -- everything heard in answer to the login query is old news, not a new group
        L.quietUntil = GetTime() + 15
        L.Query(true)
        if L.char.listed and IsInGroup() then L.char.listed = false end
        if L.char.group.listed and L.InGroupNotLeader() then L.char.group.listed = false end
        L.SendListing()
        L.Changed()
    end)
end)

NL.On("GROUP_ROSTER_UPDATE", OnRoster)
NL.On("PLAYER_LEVEL_UP", function() L.SendSoon(2) end)
NL.On("PLAYER_GUILD_UPDATE", function() L.Changed() end)
NL.On("PLAYER_LOGOUT", function()
    if L.char and (L.char.listed or L.char.group.listed) then L.char.lastActive = time() end
end)
