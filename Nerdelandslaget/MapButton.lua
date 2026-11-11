-- MapButton: the NL emblem on the minimap's rim. Left-click opens the first module (the
-- Dungeon Finder), right-click gives a menu of modules and options, drag slides it around
-- the rim. Modules can make it pulse for attention (an applicant, say).

local ADDON_NAME, ns = ...
local T = ns.Theme
local UI = ns.UI

local MB = {}
ns.MapButton = MB

local SIZE = 32
local B

local function Place()
    local mm = _G.Minimap
    local a = math.rad(ns.db.mapButtonAngle or 215)
    local w = ns.Plain(mm:GetWidth()) or 140
    local r = w / 2 + 6
    B:ClearAllPoints()
    B:SetPoint("CENTER", mm, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function FollowCursor()
    local mm = _G.Minimap
    local mx, my = mm:GetCenter()
    mx, my = ns.Plain(mx), ns.Plain(my)
    if not (mx and my) then return end
    local s = ns.Plain(mm:GetEffectiveScale()) or 1
    local cx, cy = GetCursorPosition()
    ns.db.mapButtonAngle = math.floor(math.deg(math.atan2(cy / s - my, cx / s - mx)) + 0.5) % 360
    Place()
end

local function Menu(owner)
    UI.Menu(owner, function(root)
        root:CreateTitle("Nerdelandslaget")
        for _, m in ipairs(ns.modules) do
            if m.open or m.toggle then
                root:CreateButton(m.title or m.key, function() (m.toggle or m.open)() end)
            end
        end
        root:CreateButton("Options", function() ns.OpenOptions() end)
        root:CreateButton("Hide this button", function()
            ns.db.mapButton = false
            MB.Refresh()
            ns.Print("Minimap button hidden. /nl button brings it back.")
        end)
    end)
end

local function Build()
    local mm = _G.Minimap
    if type(mm) ~= "table" then return end
    B = CreateFrame("Button", "NerdelandslagetMapButton", mm)
    B:SetSize(SIZE, SIZE)
    B:SetFrameStrata("MEDIUM")
    B:SetFrameLevel(8)
    B:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    B:RegisterForDrag("LeftButton")

    local glow = B:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER")
    glow:SetSize(SIZE * 1.6, SIZE * 1.6)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.6, 0.2, 0)
    B.glow = glow

    local icon = B:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(T.media.emblemSmall)
    B.icon = icon

    B:SetScript("OnEnter", function(self)
        icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Nerdelandslaget", T.c.gold[1], T.c.gold[2], T.c.gold[3])
        for _, m in ipairs(ns.modules) do
            if m.tooltip then m.tooltip(GameTooltip) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffF6E7B0Click|r to open, |cffF6E7B0right-click|r for more, drag to move.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    B:SetScript("OnLeave", function() GameTooltip:Hide() end)
    B:SetScript("OnClick", function(self, button)
        if button == "RightButton" then Menu(self) else ns.ToggleDefault() end
    end)
    B:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", FollowCursor)
    end)
    B:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    -- attention: a slow orange pulse
    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.15)
    a:SetToAlpha(0.9)
    a:SetDuration(0.8)
    B.pulse = ag

    Place()
end

function MB.Attention(on)
    if not B then return end
    if on then
        B.glow:SetVertexColor(1, 0.6, 0.2, 1)
        B.pulse:Play()
    else
        B.pulse:Stop()
        B.glow:SetVertexColor(1, 0.6, 0.2, 0)
    end
end

function MB.Refresh()
    if not B then Build() end
    if not B then return end
    B:SetShown(ns.db.mapButton)
    Place()
end

table.insert(ns.startup, function() MB.Refresh() end)
