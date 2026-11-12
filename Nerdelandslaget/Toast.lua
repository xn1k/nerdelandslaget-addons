-- Toast: small pop-ups above the chat, like the "friend has come online" ones.
--
--   Toast.Show({
--       key = "group:Name-Realm",     -- a toast with the same key is updated, not stacked
--       title = "New group",  text = "...",  sub = "...",
--       classFile = "WARRIOR" | icon = texture path   (default: the emblem)
--       duration = 12,                -- seconds; the timer waits while the mouse is over it
--       onClick = fn,                 -- left-click on the toast
--       buttons = { { "Invite", fn, "primary" }, { "Whisper", fn } },
--   })
--   Toast.Hide(key)
--
-- Up to three stack upwards. Left-click does onClick, right-click or × dismisses, and dragging
-- one moves them all (Toast.ResetPosition() puts them back above the chat).

local ADDON_NAME, ns = ...
local T, UI = ns.Theme, ns.UI
local C = T.c

local Toast = {}
ns.Toast = Toast

local WIDTH, HEIGHT, BTN_ROW = 310, 66, 26
local GAP, MAX = 6, 3
local FADE_IN, FADE_OUT = 0.25, 0.6

local anchor
local active = {}   -- newest first
local pool = {}

local function Unpack(c) return c[1], c[2], c[3], c[4] or 1 end

local function PlaceAnchor()
    anchor:ClearAllPoints()
    local p = ns.db and ns.db.toastPos
    if p and p.point then
        anchor:SetPoint(p.point, UIParent, p.point, p.x or 0, p.y or 0)
    elseif type(_G.ChatFrame1) == "table" then
        anchor:SetPoint("BOTTOMLEFT", _G.ChatFrame1, "TOPLEFT", 0, 40)
    else
        anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 30, 260)
    end
end

local function Anchor()
    if anchor then return anchor end
    anchor = CreateFrame("Frame", "NerdelandslagetToastAnchor", UIParent)
    anchor:SetSize(WIDTH, 10)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    PlaceAnchor()
    return anchor
end

local function Layout()
    local y = 0
    for _, f in ipairs(active) do
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, y)
        y = y + f:GetHeight() + GAP
    end
end

local function Dismiss(f)
    for i, a in ipairs(active) do
        if a == f then table.remove(active, i) break end
    end
    f:Hide()
    f.key, f.opts = nil, nil
    pool[#pool + 1] = f
    Layout()
end

local function OnUpdate(self, elapsed)
    if self.fade < 1 then
        self.fade = math.min(1, self.fade + elapsed / FADE_IN)
        self:SetAlpha(self.fade)
    end
    if self:IsMouseOver() then return end
    self.left = self.left - elapsed
    if self.left <= 0 then
        local a = 1 + self.left / FADE_OUT
        if a <= 0 then Dismiss(self) else self:SetAlpha(math.min(a, self.fade)) end
    end
end

local function Build()
    local f = CreateFrame("Button", nil, Anchor(), "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    UI.Backdrop(f, C.bg, C.edge)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:RegisterForDrag("LeftButton")

    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("BOTTOMLEFT", 1, 1)
    accent:SetWidth(3)
    accent:SetColorTexture(Unpack(C.orange))

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(38, 38)
    f.icon:SetPoint("TOPLEFT", 12, -12)

    f.title = UI.Title(f, 13)
    f.title:SetPoint("TOPLEFT", 60, -9)
    f.title:SetPoint("RIGHT", -26, 0)
    f.text = UI.Text(f, 12, C.cream)
    f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.text:SetPoint("RIGHT", -10, 0)
    f.sub = UI.Text(f, 10, C.dim)
    f.sub:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -4)
    f.sub:SetPoint("RIGHT", -10, 0)

    f.close = UI.CloseButton(f, function() Dismiss(f) end)
    f.close:SetSize(20, 20)
    f.close:SetPoint("TOPRIGHT", -3, -3)

    f.buttons = {}
    for i = 1, 2 do
        local b = UI.Button(f, "", 84, 20)
        if i == 1 then b:SetPoint("BOTTOMRIGHT", -8, 7) else b:SetPoint("RIGHT", f.buttons[1], "LEFT", -6, 0) end
        b:SetScript("OnClick", function(self)
            local fn = self.fn
            Dismiss(f)
            if fn then pcall(fn) end
        end)
        f.buttons[i] = b
    end

    local hl = f:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 0.9, 0.6, 0.06)

    f:SetScript("OnClick", function(self, button)
        if self.dragged then self.dragged = false return end
        local fn = button ~= "RightButton" and self.opts and self.opts.onClick
        Dismiss(self)
        if fn then pcall(fn) end
    end)
    f:SetScript("OnEnter", function(self)
        self.left = math.max(self.left or 0, 2)
        self:SetAlpha(1)
        self.fade = 1
    end)
    f:SetScript("OnDragStart", function(self)
        self.dragged = true
        anchor:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        anchor:StopMovingOrSizing()
        local point, _, _, x, y = anchor:GetPoint(1)
        if ns.db then ns.db.toastPos = { point = point, x = x, y = y } end
        -- the drag stop can come before or without the click; clear the flag a moment later
        C_Timer.After(0.1, function() self.dragged = false end)
    end)
    f:SetScript("OnUpdate", OnUpdate)
    return f
end

local function Fill(f, o)
    f.opts = o
    f.key = o.key
    if o.classFile then
        T.SetClass(f.icon, o.classFile)
    else
        f.icon:Show()
        f.icon:SetTexture(o.icon or T.media.emblemSmall)
        f.icon:SetTexCoord(0, 1, 0, 1)
    end
    f.title:SetText(o.title or "")
    f.text:SetText(o.text or "")
    f.sub:SetText(o.sub or "")
    local n = o.buttons and #o.buttons or 0
    for i, b in ipairs(f.buttons) do
        local spec = o.buttons and o.buttons[i]
        if spec then
            b:SetLabel(spec[1])
            b:SetKind(spec[3] or "normal")
            b.fn = spec[2]
            b:Enable()
            b:Show()
        else
            b.fn = nil
            b:Hide()
        end
    end
    f:SetHeight(HEIGHT + (n > 0 and BTN_ROW or 0))
    f.left = o.duration or 12
end

function Toast.Show(o)
    if type(o) ~= "table" then return end
    Anchor()
    local f
    if o.key then
        for _, a in ipairs(active) do
            if a.key == o.key then f = a break end
        end
    end
    if f then
        Fill(f, o)
        f:SetAlpha(1)
        f.fade = 1
        Layout()
        return f
    end
    while #active >= MAX do Dismiss(active[#active]) end
    f = table.remove(pool) or Build()
    Fill(f, o)
    f.fade = 0
    f:SetAlpha(0)
    f:Show()
    table.insert(active, 1, f)
    Layout()
    return f
end

function Toast.Hide(key)
    for _, a in ipairs(active) do
        if a.key == key then Dismiss(a) return end
    end
end

function Toast.Active(key)
    for _, a in ipairs(active) do
        if a.key == key then return a end
    end
end

function Toast.ResetPosition()
    if ns.db then ns.db.toastPos = nil end
    if anchor then PlaceAnchor() end
end
