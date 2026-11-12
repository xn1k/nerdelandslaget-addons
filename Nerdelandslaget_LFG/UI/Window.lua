-- Window: the Dungeon Finder's window, its three tabs (Browse, Sign up, My group) and the
-- module's registration with the suite (minimap button, /nl lfg, options).

local ADDON_NAME, ns = ...
local NL = Nerdelandslaget
local UI, T = NL.UI, NL.Theme
local C = T.c
local L = ns.LFG
local D = ns.Dungeons

local W = {}
ns.Win = W

local WIDTH, HEIGHT = 860, 580
local frame, tabs, lock
W.pages = {}

local function Count(tbl, fn)
    local n = 0
    for _, e in pairs(tbl) do if not fn or fn(e) then n = n + 1 end end
    return n
end

function W.Refresh()
    if not frame or not frame:IsShown() then return end
    local allowed = L.Allowed()
    lock:SetShown(not allowed and not L.demo)
    local g = NL.MyGuildName()
    local groups, players = Count(L.groups), Count(L.players)
    if L.char.group.listed then groups = groups + 1 end
    if L.char.listed then players = players + 1 end
    local status
    if L.char.group.listed then
        status = T.Color("Your group is listed", C.green)
    elseif L.char.listed then
        status = T.Color("You're listed for " .. D.Count(L.char.dungeons) .. " dungeon"
            .. (D.Count(L.char.dungeons) == 1 and "" or "s"), C.green)
    else
        status = "Not listed"
    end
    frame.subtitle:SetText((g and ("<" .. g .. ">  ·  ") or "") .. groups .. " group" .. (groups == 1 and "" or "s")
        .. "  ·  " .. players .. " looking  ·  " .. status .. (L.demo and T.Color("  ·  DEMO", C.orange) or ""))
    local apps = L.ApplicantCount()
    tabs:SetBadge(3, apps > 0 and tostring(apps) or "")
    for i, page in ipairs(W.pages) do
        if page:IsShown() and page.Refresh then page:Refresh() end
    end
end

local function Build()
    frame = UI.Window("NerdelandslagetLFGFrame", WIDTH, HEIGHT, "Dungeon Finder", L.db.window)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 12, -84)
    content:SetPoint("BOTTOMRIGHT", -12, 12)
    W.content = content

    W.pages[1] = ns.BuildBrowse(content)
    W.pages[2] = ns.BuildSignUp(content)
    W.pages[3] = ns.BuildGroup(content)
    for _, p in ipairs(W.pages) do
        p:SetAllPoints(content)
        p:Hide()
    end

    tabs = UI.Tabs(frame, { "Browse", "Sign up", "My group" }, function(i)
        for k, p in ipairs(W.pages) do p:SetShown(k == i) end
        L.db.tab = i
        if i == 3 then NL.MapButton.Attention(false) end
        W.Refresh()
    end)
    tabs.buttons[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -52)

    -- not in one of the guilds: a curtain over everything
    lock = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    lock:SetPoint("TOPLEFT", content, "TOPLEFT", -4, 34)
    lock:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 4, -4)
    UI.Backdrop(lock, { 0.02, 0.07, 0.09, 0.97 }, C.edgeDim)
    lock:SetFrameLevel(frame:GetFrameLevel() + 20)
    lock:EnableMouse(true)
    local head = UI.Header(lock, 360)
    head:SetPoint("CENTER", 0, 60)
    local msg = UI.Text(lock, 14, C.cream, "CENTER")
    msg:SetPoint("TOP", head, "BOTTOM", 0, -20)
    msg:SetWidth(520)
    msg:SetWordWrap(true)
    msg:SetText("The Dungeon Finder is for members of " .. T.Color("<Nerdelandslaget>", C.gold) .. " and "
        .. T.Color("<Nerdelandslaget II>", C.gold) .. ".\n\nJoin one of the guilds to find groups with the community.")
    local demo = UI.Button(lock, "Show a demo", 120, 24)
    demo:SetPoint("TOP", msg, "BOTTOM", 0, -18)
    demo:SetScript("OnClick", function() lock:Hide() L.Demo(true) end)
    lock:Hide()

    frame:SetScript("OnShow", function()
        L.Query()
        W.Refresh()
    end)
    tabs:Select(L.db.tab or 1)
end

function W.Open(tab)
    if not frame then Build() end
    frame:Show()
    if tab then tabs:Select(tab) end
    W.Refresh()
end

function W.Toggle()
    if frame and frame:IsShown() then frame:Hide() else W.Open() end
end

function W.Select(tab) W.Open(tab) end

-- From a pop-up: Browse, groups, with this group at the top and glowing for a while (shown
-- even if the dungeon filter or "only what fits me" would hide it).
W.HIGHLIGHT_TIME = 12
function W.ShowGroup(name)
    L.db.browseKind = "groups"
    W.highlight, W.highlightUntil, W.scrollTop = name, GetTime() + W.HIGHLIGHT_TIME, true
    W.Open(1)
    if not L.groups[name] then
        NL.Print(NL.Short(name) .. "'s group isn't listed any more.")
    end
    C_Timer.After(W.HIGHLIGHT_TIME + 0.1, W.Refresh)
end

function W.Highlighted()
    if W.highlight and GetTime() < (W.highlightUntil or 0) then return W.highlight end
    W.highlight = nil
end

L.OnChange(W.Refresh)

-- "12m", "2h"
function W.Age(since)
    if not since or since <= 0 then return "" end
    local s = math.max(0, time() - since)
    if s < 60 then return "now" end
    if s < 3600 then return math.floor(s / 60) .. "m" end
    return math.floor(s / 3600) .. "h"
end

-- A row of role icons for a set ({ T = true, ... }).
function W.RoleIcons(parent, size)
    local icons = {}
    for i, r in ipairs(T.ROLES) do
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetSize(size, size)
        if i > 1 then t:SetPoint("LEFT", icons[i - 1], "RIGHT", 2, 0) end
        icons[i] = t
    end
    function icons:Set(set, hideOff)
        for i, r in ipairs(T.ROLES) do
            local on = set and set[r]
            T.SetRole(self[i], r, not on)
            self[i]:SetShown(on or not hideOff)
        end
    end
    return icons
end

---------------------------------------------------------------------------
-- The module
---------------------------------------------------------------------------

NL.RegisterModule({
    key = "lfg",
    title = "Dungeon Finder",
    desc = "Sign up for several dungeons at once, or start a group with a level range.",
    icon = "Interface\\Icons\\INV_Misc_GroupLooking",
    open = function() W.Open() end,
    toggle = function() W.Toggle() end,
    tooltip = function(tt)
        if not L.char then return end
        local groups, players = Count(L.groups), Count(L.players)
        tt:AddDoubleLine("Dungeon Finder", groups .. " groups · " .. players .. " looking", 0.96, 0.9, 0.69, 1, 1, 1)
        if L.char.group.listed then
            local n = L.ApplicantCount()
            tt:AddLine("  Your group is listed" .. (n > 0 and (" · " .. n .. " want to join") or ""), 0.45, 0.82, 0.38)
        elseif L.char.listed then
            tt:AddLine("  You're listed for " .. D.Summary(L.char.dungeons, 4), 0.45, 0.82, 0.38)
        end
    end,
    slash = function(rest)
        local cmd = strtrim(rest or ""):lower()
        if cmd == "demo" then
            L.Demo(not L.demo)
            NL.Print("Demo listings " .. (L.demo and "on" or "off") .. ".")
            if L.demo then W.Open() end
        elseif cmd == "delist" then
            L.DelistSelf()
            L.DelistGroup()
        elseif cmd == "options" then
            NL.OpenOptions(ns.optionsCategory)
        elseif cmd == "test" then
            L.TestToasts()
        elseif cmd == "" then
            W.Toggle()
        else
            NL.Print("/nl lfg [demo|delist|test|options]")
        end
    end,
    options = function() if ns.BuildOptions then ns.BuildOptions() end end,
})
