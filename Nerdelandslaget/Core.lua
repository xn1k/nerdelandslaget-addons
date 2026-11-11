-- Nerdelandslaget: the suite's core. Every module (Nerdelandslaget_LFG and later ones) depends
-- on it and reaches it through the global table Nerdelandslaget, which is this addon's ns.
--
-- The core owns what modules share: events, the debug log, guild membership, the hidden
-- addon channel (Comm.lua), the look (Theme.lua, Widgets.lua), the minimap button and the
-- suite's options page with the wordmark.
--
-- WoW Forever (interface 16001) runs the Mainline API with Midnight's secret values.
-- Never register COMBAT_LOG_EVENT_UNFILTERED; guard possibly-secret values with IsSecret.

local ADDON_NAME, ns = ...
Nerdelandslaget = ns
ns.NAME = ADDON_NAME
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "0"

-- The guilds the suite is for. Index 1 and 2 travel in messages, so keep the order.
ns.GUILDS = { "Nerdelandslaget", "Nerdelandslaget II" }

---------------------------------------------------------------------------
-- Client detection
---------------------------------------------------------------------------

local iface = select(4, GetBuildInfo())
ns.IS_FOREVER = (type(iface) == "number" and iface >= 16000 and iface < 20000)
    or (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)

---------------------------------------------------------------------------
-- Secret-value helpers
---------------------------------------------------------------------------

local issecretvalue = issecretvalue

function ns.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- The value if it can be read, else nil. Use before any comparison or arithmetic.
function ns.Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

function ns.Describe(v)
    if ns.IsSecret(v) then return "<secret " .. type(v) .. ">" end
    return tostring(v)
end

---------------------------------------------------------------------------
-- Saved variables + debug log (WTF\...\SavedVariables\Nerdelandslaget.lua after /reload)
---------------------------------------------------------------------------

local DEFAULTS = {
    debug = false,
    mapButton = true,
    mapButtonAngle = 215,
}

function ns.ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ns.ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local LOG_MAX = 600
local earlyLog = {}

-- ns.log(...) or ns.log("[LFG]", ...): to db.log, and to chat while debug is on.
function ns.log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = ns.Describe((select(i, ...))) end
    local line = date("%H:%M:%S ") .. table.concat(parts, " ")
    local db = ns.db
    if not db then
        earlyLog[#earlyLog + 1] = line
        return
    end
    db.log = db.log or {}
    local log = db.log
    log[#log + 1] = line
    while #log > LOG_MAX do table.remove(log, 1) end
    if db.debug then print("|cffF7C12FNL|r " .. line) end
end

function ns.Print(msg)
    print("|cffF7C12FNerdelandslaget|r " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Events: any number of handlers per event, from any file or module
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
    local list = handlers[event]
    if not list then
        if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
            ns.log("event not valid on this client:", event)
            return
        end
        list = {}
        handlers[event] = list
        frame:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then
            ns.log("error in", event, err)
            if geterrorhandler then geterrorhandler()(err) end
        end
    end
end)

-- Run fn now, or once combat ends.
local pending = {}
function ns.AfterCombat(fn)
    if not InCombatLockdown() then return fn() end
    pending[#pending + 1] = fn
end
ns.On("PLAYER_REGEN_ENABLED", function()
    local list = pending
    pending = {}
    for i = 1, #list do list[i]() end
end)

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------

-- ns.RegisterModule{ key, title, desc, icon, open = fn, toggle = fn, tooltip = fn(tt),
--                    slash = fn(rest), options = fn(category) }
-- The first module registered is the one the minimap button and plain /nl open.
ns.modules = {}
function ns.RegisterModule(def)
    assert(type(def) == "table" and def.key, "module needs a key")
    ns.modules[#ns.modules + 1] = def
    ns.modules[def.key] = def
    if ns.OnModuleRegistered then ns.OnModuleRegistered(def) end
    return def
end

function ns.DefaultModule()
    return ns.modules[1]
end

function ns.ToggleDefault()
    local m = ns.DefaultModule()
    if m and m.toggle then m.toggle()
    elseif m and m.open then m.open()
    else ns.OpenOptions() end
end

---------------------------------------------------------------------------
-- Names and guild
---------------------------------------------------------------------------

local function Realm()
    local r = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(r) == "string" and r ~= "" and not ns.IsSecret(r) then return r end
    return nil
end

-- "Name-Realm" for any readable name; nil for secret or empty ones.
function ns.Full(name)
    if type(name) ~= "string" or ns.IsSecret(name) or name == "" then return nil end
    if name:find("-", 1, true) then return name end
    local realm = Realm()
    return realm and (name .. "-" .. realm) or name
end

-- "Name" if on our realm, else "Name-Realm". Use this (not Full) for anything the server
-- reads, such as invites and whispers: on Forever the normalized realm is an internal id
-- ("CAMWOWEU5Realm2PvP") that the server won't take back in a name.
function ns.Short(name)
    if type(name) ~= "string" then return "?" end
    if Ambiguate then
        local ok, s = pcall(Ambiguate, name, "none")
        if ok and type(s) == "string" and s ~= "" and not ns.IsSecret(s) then return s end
    end
    local realm = Realm()
    if realm then
        local n, r = name:match("^(.-)%-(.+)$")
        if n and r == realm then return n end
    end
    return name
end

function ns.Me()
    return ns.Full(UnitName("player"))
end

-- 1 or 2 for <Nerdelandslaget> / <Nerdelandslaget II>, else nil.
function ns.GuildIndex(name)
    if type(name) ~= "string" or ns.IsSecret(name) then return nil end
    for i, g in ipairs(ns.GUILDS) do
        if g == name then return i end
    end
    return nil
end

function ns.MyGuildName()
    if not IsInGuild() then return nil end
    local g = GetGuildInfo("player")
    if type(g) ~= "string" or ns.IsSecret(g) then return nil end
    return g
end

function ns.MyGuild()
    return ns.GuildIndex(ns.MyGuildName())
end

function ns.GuildTag(i)
    if i == 1 then return "NL" elseif i == 2 then return "NL II" end
    return "?"
end

---------------------------------------------------------------------------
-- Talking to people
---------------------------------------------------------------------------

local function ChatOpen()
    local get = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
    if not get then return false end
    local ok, eb = pcall(get)
    return ok and eb ~= nil
end

-- Opens a whisper to name in the chat box, or the suite's own whisper box if the game
-- won't let an addon open its chat box.
function ns.Whisper(name)
    if not name then return end
    local target = ns.Short(name)
    for _, fn in ipairs({ ChatFrameUtil and ChatFrameUtil.SendTell, ChatFrame_SendTell }) do
        if type(fn) == "function" then
            local ok = pcall(fn, target)
            if ok and ChatOpen() then return end
        end
    end
    ns.log("chat box whisper unavailable, using the quick whisper box")
    if ns.UI and ns.UI.QuickWhisper then ns.UI.QuickWhisper(target) end
end

function ns.SendWhisper(text, target)
    if type(text) ~= "string" or text == "" then return end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok, err = pcall(send, text, "WHISPER", nil, target)
    if not ok then ns.log("whisper failed:", err) end
end

function ns.Invite(name)
    if not name then return end
    local fn = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if not fn then
        ns.Print("This client has no way to invite from an addon.")
        return
    end
    local target = ns.Short(name)
    ns.log("invite", name, "as", target)
    local ok, err = pcall(fn, target)
    if not ok then ns.log("invite failed:", err) end
end

---------------------------------------------------------------------------
-- Classes
---------------------------------------------------------------------------

-- classFile ("WARRIOR") for a classID, or nil.
function ns.ClassFile(classID)
    classID = tonumber(classID)
    if not classID then return nil end
    if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.classFile then return info.classFile, info.className end
    end
    if GetClassInfo then
        local name, file = GetClassInfo(classID)
        if file then return file, name end
    end
    return nil
end

function ns.ClassColorHex(classFile)
    local c
    if classFile and C_ClassColor and C_ClassColor.GetClassColor then c = C_ClassColor.GetClassColor(classFile) end
    if not c and classFile and RAID_CLASS_COLORS then c = RAID_CLASS_COLORS[classFile] end
    if not c then return "ffe8dcb5" end
    if c.GenerateHexColor then return c:GenerateHexColor() end
    return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

function ns.ClassName(name, classFile)
    return "|c" .. ns.ClassColorHex(classFile) .. ns.Short(name) .. "|r"
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

ns.startup = {}       -- functions run at PLAYER_LOGIN, after every module has loaded

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON_NAME then return end
    NerdelandslagetDB = NerdelandslagetDB or {}
    ns.db = ns.ApplyDefaults(NerdelandslagetDB, DEFAULTS)
    for _, line in ipairs(earlyLog) do
        ns.db.log = ns.db.log or {}
        table.insert(ns.db.log, line)
    end
    wipe(earlyLog)
    ns.log("loaded", ns.VERSION, "build", (GetBuildInfo()), "iface", iface, "forever", ns.IS_FOREVER)
end)

ns.On("PLAYER_LOGIN", function()
    for _, fn in ipairs(ns.startup) do
        local ok, err = pcall(fn)
        if not ok then ns.log("startup error:", err) end
    end
    ns.started = true
end)

function Nerdelandslaget_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then ns.OpenOptions() else ns.ToggleDefault() end
end

---------------------------------------------------------------------------
-- Probe: what this client lets us do, written to the log (read it after /reload)
---------------------------------------------------------------------------

function ns.Probe()
    local function has(path)
        local v = _G
        for part in path:gmatch("[^%.]+") do
            if type(v) ~= "table" then return false end
            v = v[part]
        end
        return v ~= nil
    end
    local checks = {
        "ChatFrameUtil.SendTell", "ChatFrame_SendTell", "ChatFrameUtil.GetActiveWindow", "ChatEdit_GetActiveWindow",
        "C_PartyInfo.InviteUnit", "InviteUnit", "JoinTemporaryChannel", "JoinChannelByName",
        "C_ChatInfo.SendAddonMessage", "C_ChatInfo.InChatMessagingLockdown", "C_ChatInfo.SendChatMessage",
        "SendChatMessage", "MenuUtil.CreateContextMenu", "Settings.RegisterCanvasLayoutCategory",
        "Settings.RegisterCanvasLayoutSubcategory", "C_CreatureInfo.GetClassInfo", "UnitGroupRolesAssigned",
        "C_ClassColor.GetClassColor", "C_Texture.GetAtlasInfo", "CLASS_ICON_TCOORDS",
    }
    ns.log("probe: forever", ns.IS_FOREVER, "build", (GetBuildInfo()), "iface", iface)
    for _, c in ipairs(checks) do ns.log("probe:", c, has(c)) end
    if C_Texture and C_Texture.GetAtlasInfo then
        for _, a in ipairs({ "roleicon-tiny-tank", "roleicon-tiny-healer", "roleicon-tiny-dps",
            "UI-LFG-RoleIcon-Tank", "groupfinder-icon-role-large-tank", "classicon-warrior" }) do
            ns.log("probe: atlas", a, C_Texture.GetAtlasInfo(a) ~= nil)
        end
    end
    ns.log("probe: guild", ns.MyGuildName(), "index", ns.MyGuild())
    if ns.Comm then ns.log("probe: channel id", ns.Comm.ChannelID()) end
    ns.Print("Probe written to the log. /reload, then the SavedVariables file has it.")
end

---------------------------------------------------------------------------
-- Slash command: /nl [module] [args]
---------------------------------------------------------------------------

SLASH_NERDELANDSLAGET1 = "/nl"
SLASH_NERDELANDSLAGET2 = "/nerdelandslaget"
SlashCmdList.NERDELANDSLAGET = function(msg)
    local cmd, rest = strsplit(" ", strtrim(msg or ""), 2)
    cmd = (cmd or ""):lower()
    if cmd == "" then
        ns.ToggleDefault()
    elseif cmd == "options" or cmd == "config" then
        ns.OpenOptions()
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("debug " .. (ns.db.debug and "on" or "off"))
    elseif cmd == "clearlog" then
        wipe(ns.db.log or {})
        ns.Print("log cleared")
    elseif cmd == "probe" then
        ns.Probe()
    elseif cmd == "button" then
        ns.db.mapButton = not ns.db.mapButton
        if ns.MapButton then ns.MapButton.Refresh() end
    elseif ns.modules[cmd] then
        local m = ns.modules[cmd]
        if m.slash then m.slash(rest or "") elseif m.toggle then m.toggle() end
    else
        local names = {}
        for _, m in ipairs(ns.modules) do names[#names + 1] = m.key end
        ns.Print("/nl [" .. table.concat(names, "|") .. "] | options | button | probe | debug | clearlog")
    end
end
