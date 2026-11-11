-- A permissive mock of the WoW API, enough to load the Nerdelandslaget suite outside the game.
-- Widgets accept any method (unknown ones are no-ops); the ones the suite reads back
-- (sizes, text, checked, shown, scripts, values) keep state. Timers run when the test
-- calls mock.advance(seconds). Errors from geterrorhandler land in mock.errors.

mock = { now = 1000, clock = 1700000000, timers = {}, sent = {}, errors = {}, events = {}, frames = {} }

function mock.advance(sec)
    local target = mock.now + sec
    while true do
        table.sort(mock.timers, function(a, b) return a.at < b.at end)
        local t = mock.timers[1]
        if not t or t.at > target then break end
        table.remove(mock.timers, 1)
        mock.now = t.at
        mock.clock = mock.clock + 0
        local ok, err = pcall(t.fn)
        if not ok then table.insert(mock.errors, "timer: " .. tostring(err)) end
        if t.every then t.at = t.at + t.every table.insert(mock.timers, t) end
    end
    mock.clock = mock.clock + (target - mock.now)
    mock.now = target
end

function geterrorhandler() return function(e) table.insert(mock.errors, tostring(e)) end end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local Widget = {}
local function noop() end

local function new(kind, name, parent)
    local w = setmetatable({ _kind = kind, _scripts = {}, _shown = true, _w = 100, _h = 20, _text = "",
        _enabled = true, _checked = false, _parent = parent, _min = 0, _max = 0, _value = 0, _children = {} }, Widget)
    if name then _G[name] = w end
    if parent and type(parent) == "table" and parent._children then table.insert(parent._children, w) end
    table.insert(mock.frames, w)
    return w
end
mock.new = new

local methods = {}
function methods:SetScript(s, fn) self._scripts[s] = fn end
function methods:GetScript(s) return self._scripts[s] end
function methods:HookScript(s, fn)
    local old = self._scripts[s]
    self._scripts[s] = function(...) if old then old(...) end fn(...) end
end
function methods:Fire(s, ...) local f = self._scripts[s] if f then return f(self, ...) end end
function methods:Show()
    local was = self._shown
    self._shown = true
    if not was then self:Fire("OnShow") end
end
function methods:Hide()
    local was = self._shown
    self._shown = false
    if was then self:Fire("OnHide") end
end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:IsShown() return self._shown end
function methods:IsVisible() return self._shown end
function methods:SetSize(w, h) self._w, self._h = w, h self:Fire("OnSizeChanged", w, h) end
function methods:SetWidth(w) self._w = w end
function methods:SetHeight(h) self._h = h self:Fire("OnSizeChanged", self._w, h) end
function methods:GetWidth() return self._w end
function methods:GetHeight() return self._h end
function methods:GetSize() return self._w, self._h end
function methods:SetText(t) self._text = t == nil and "" or tostring(t) end
function methods:GetText() return self._text end
function methods:SetFormattedText(f, ...) self._text = string.format(f, ...) end
function methods:GetStringWidth() return #self._text * 6 end
function methods:SetChecked(c) self._checked = c and true or false end
function methods:GetChecked() return self._checked end
function methods:Enable() self._enabled = true self:Fire("OnEnable") end
function methods:Disable() self._enabled = false self:Fire("OnDisable") end
function methods:SetEnabled(on) if on then self:Enable() else self:Disable() end end
function methods:IsEnabled() return self._enabled end
function methods:HasFocus() return false end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:GetCenter() return 500, 400 end
function methods:GetEffectiveScale() return 1 end
function methods:GetFrameLevel() return 5 end
function methods:GetParent() return self._parent end
function methods:SetMinMaxValues(a, b) self._min, self._max = a, b end
function methods:GetMinMaxValues() return self._min, self._max end
function methods:SetValue(v) self._value = v self:Fire("OnValueChanged", v) end
function methods:GetValue() return self._value end
function methods:CreateTexture() return new("Texture", nil, self) end
function methods:CreateFontString() return new("FontString", nil, self) end
function methods:CreateAnimationGroup() return new("AnimationGroup", nil, self) end
function methods:CreateAnimation() return new("Animation", nil, self) end
function methods:GetStatusBarTexture() return new("Texture", nil, self) end
function methods:GetID() return 7 end
-- the real client fires OnClick with the button
function methods:Click(button) self:Fire("OnClick", button or "LeftButton") end

Widget.__index = function(t, k)
    if methods[k] then return methods[k] end
    if type(k) == "string" and k:match("^%u") then return noop end   -- unknown methods
    return nil                                                          -- unknown fields
end

function CreateFrame(kind, name, parent, template)
    local f = new(kind, name, parent)
    f._shown = true
    return f
end

UIParent = new("Frame", "UIParent")
Minimap = new("Frame", "Minimap")
Minimap._w = 140
GameTooltip = new("GameTooltip", "GameTooltip")
UISpecialFrames = {}
BackdropTemplateMixin = {}
function Mixin(o, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do o[k] = v end end return o end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

---------------------------------------------------------------------------
-- Lua helpers the game adds
---------------------------------------------------------------------------

function strsplit(sep, s, n)
    local out, start = {}, 1
    while true do
        if n and #out == n - 1 then out[#out + 1] = s:sub(start) break end
        local i = s:find(sep, start, true)
        if not i then out[#out + 1] = s:sub(start) break end
        out[#out + 1] = s:sub(start, i - 1)
        start = i + #sep
    end
    return unpack(out)
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
function GetTime() return mock.now end
function time() return math.floor(mock.clock) end
date = os.date
function issecretvalue(v) return type(v) == "table" and rawget(v, "__secret") == true end

---------------------------------------------------------------------------
-- Game state the test can change
---------------------------------------------------------------------------

mock.player = { name = "Hans", realm = "Firemaw", class = "PRIEST", classID = 5, level = 32, guild = "Nerdelandslaget II" }
mock.party = {}           -- { { name=, class=, classID=, level= } }
mock.leader = true
mock.channelJoined = false

function Ambiguate(name, context)
    local n, r = name:match("^(.-)%-(.+)$")
    if n and r == mock.player.realm then return n end
    return name
end
function GetBuildInfo() return "1.60.1", "70888", "Nov 2026", 16001 end
function GetNormalizedRealmName() return mock.player.realm end
function UnitName(u)
    if u == "player" then return mock.player.name end
    local i = tonumber(u:match("^party(%d)$") or "")
    local m = i and mock.party[i]
    return m and m.name or nil
end
local CLASSES = { [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
    [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID" }
function UnitClass(u)
    if u == "player" then return "Priest", mock.player.class, mock.player.classID end
    local i = tonumber(u:match("^party(%d)$") or "")
    local m = i and mock.party[i]
    if m then return m.class, m.class, m.classID end
end
function UnitLevel(u)
    if u == "player" then return mock.player.level end
    local i = tonumber(u:match("^party(%d)$") or "")
    local m = i and mock.party[i]
    return m and m.level or 0
end
function UnitGroupRolesAssigned() return "NONE" end
function IsInGuild() return mock.player.guild ~= nil end
function GetGuildInfo() return mock.player.guild, "Member", 5 end
function IsInGroup() return #mock.party > 0 end
function IsInRaid() return false end
function UnitIsGroupLeader() return mock.leader end
function InCombatLockdown() return false end
function GetCursorPosition() return 0, 0 end
function PlaySound() end
SOUNDKIT = { READY_CHECK = 8960 }
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
C_CreatureInfo = { GetClassInfo = function(id)
    local f = CLASSES[id]
    return f and { classFile = f, className = f:sub(1, 1) .. f:sub(2):lower(), classID = id } or nil
end }
C_ClassColor = nil
C_Texture = { GetAtlasInfo = function(a) return a:find("roleicon") and {} or nil end }
C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
C_EventUtils = { IsEventValid = function() return true end }
C_PartyInfo = { InviteUnit = function(name) table.insert(mock.sent, { kind = "INVITE", target = name }) end }
Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3 } }

function GetChannelName(name) if mock.channelJoined then return 6, name end return 0 end
function JoinTemporaryChannel() mock.channelJoined = true end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    InChatMessagingLockdown = function() return false end,
    SendAddonMessage = function(prefix, text, dist, target)
        assert(type(text) == "string" and #text <= 255, "addon message too long: " .. tostring(text and #text))
        table.insert(mock.sent, { prefix = prefix, text = text, dist = dist, target = target })
        return 0
    end,
    SendChatMessage = function(text, kind, _, target) table.insert(mock.sent, { kind = kind, text = text, target = target }) end,
}
ChatFrameUtil = { AddMessageEventFilter = function() end }

C_Timer = {
    After = function(s, fn) table.insert(mock.timers, { at = mock.now + s, fn = fn }) end,
    NewTicker = function(s, fn) local t = { at = mock.now + s, fn = fn, every = s } table.insert(mock.timers, t) return t end,
}

Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) return { name = name, GetID = function() return 7 end } end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name) mock.subpage = frame return { name = name, GetID = function() return 8 end } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) mock.openedCategory = id end,
}

-- Builds the menu so the code that fills it runs.
local function MenuDesc()
    local d = {}
    setmetatable(d, { __index = function() return function() return d end end })
    return d
end
MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, MenuDesc()) end }

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function mock.fire(event, ...)
    for _, f in ipairs(mock.frames) do
        local h = f._scripts and f._scripts.OnEvent
        if h and f._registered and f._registered[event] then h(f, event, ...) end
    end
end
methods.RegisterEvent = function(self, e) self._registered = self._registered or {} self._registered[e] = true end
methods.UnregisterEvent = function(self, e) if self._registered then self._registered[e] = nil end end
methods.RegisterUnitEvent = methods.RegisterEvent

SlashCmdList = {}
