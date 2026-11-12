-- Widgets: the suite's own controls in the NL colours, so every module looks the same and
-- none of them borrows Blizzard templates that move around between builds.
--
--   UI.Window(name, w, h, title, pos)   movable window with the emblem badge, closes on Escape
--   UI.Header(parent, width)            the NERDE-LANDSLAGET wordmark
--   UI.Text, UI.Button, UI.Check, UI.Input, UI.RoleToggle, UI.Tabs, UI.Dropdown
--   UI.List(parent, rowH, create, update)  a scrolling list over a pool of rows
--   UI.QuickWhisper(name)               a small whisper box (when the chat box can't be opened)

local ADDON_NAME, ns = ...
local T = ns.Theme
local C = T.c

local UI = {}
ns.UI = UI

local function Unpack(c, a) return c[1], c[2], c[3], a or c[4] or 1 end

function UI.Backdrop(f, bg, edge, size)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = T.media.white, edgeFile = T.media.white, edgeSize = size or 1 })
    f:SetBackdropColor(Unpack(bg or C.bg))
    f:SetBackdropBorderColor(Unpack(edge or C.edgeDim))
end

function UI.Frame(parent, bg, edge, size)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Backdrop(f, bg, edge, size)
    return f
end

function UI.Text(parent, size, color, justify, font, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or T.FONT, size or 12, flags or "")
    fs:SetTextColor(Unpack(color or C.text))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- Shadowed headline text in gold.
function UI.Title(parent, size)
    local fs = UI.Text(parent, size or 16, C.gold, "LEFT", T.FONT_HEAD, "")
    fs:SetShadowColor(0.02, 0.07, 0.09, 1)
    fs:SetShadowOffset(2, -2)
    return fs
end

function UI.Tip(owner, title, lines, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", Unpack(C.gold))
    for _, l in ipairs(lines or {}) do
        if type(l) == "table" then
            GameTooltip:AddDoubleLine(l[1], l[2], 0.9, 0.87, 0.76, 1, 1, 1)
        else
            GameTooltip:AddLine(l, 0.9, 0.87, 0.76, true)
        end
    end
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- The wordmark
---------------------------------------------------------------------------

function UI.Header(parent, width)
    local wm = T.media.wordmark
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(wm.file)
    tex:SetTexCoord(0, wm.u, 0, wm.v)
    width = width or 300
    tex:SetSize(width, width * wm.h / wm.w)
    return tex
end

function UI.Emblem(parent, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(T.media.emblem)
    tex:SetSize(size, size)
    return tex
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

-- kind: "primary" (orange, the main action), "normal", "danger"
function UI.Button(parent, label, w, h, kind)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 90, h or 22)
    b.kind = kind or "normal"
    UI.Backdrop(b, C.bgLight, C.edgeDim)
    local grad = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    grad:SetPoint("TOPLEFT", 1, -1)
    grad:SetPoint("BOTTOMRIGHT", -1, 1)
    grad:SetTexture(T.media.white)
    b.grad = grad
    b.label = UI.Text(b, 12, C.cream, "CENTER")
    b.label:SetPoint("LEFT", 4, 0)
    b.label:SetPoint("RIGHT", -4, 0)
    b.label:SetText(label or "")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 0.9, 0.6, 0.12)

    function b:Paint()
        local on = self:IsEnabled()
        local top, bottom
        if self.kind == "primary" then
            top, bottom = C.gold, C.orange
        elseif self.kind == "danger" then
            top, bottom = { 0.62, 0.22, 0.18 }, { 0.40, 0.12, 0.10 }
        else
            top, bottom = { 0.10, 0.30, 0.35 }, { 0.06, 0.19, 0.23 }
        end
        -- a disabled button of any kind goes flat and grey-teal instead of a muddy faded colour
        if not on then top, bottom = { 0.09, 0.20, 0.23 }, { 0.06, 0.15, 0.18 } end
        local a = 1
        if self.grad.SetGradient and CreateColor then
            self.grad:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], a),
                CreateColor(top[1], top[2], top[3], a))
        else
            self.grad:SetVertexColor(bottom[1], bottom[2], bottom[3], a)
        end
        local tc = (on and self.kind == "primary") and { 0.06, 0.12, 0.14 } or (on and C.cream or C.dim)
        self.label:SetTextColor(tc[1], tc[2], tc[3], on and 1 or 0.6)
        self:SetBackdropBorderColor(Unpack(on and C.edge or C.edgeDim))
    end
    function b:SetLabel(text) self.label:SetText(text) end
    function b:SetKind(k) self.kind = k self:Paint() end
    b:SetScript("OnEnable", b.Paint)
    b:SetScript("OnDisable", b.Paint)
    b:SetScript("OnLeave", HideTip)
    b:Paint()
    return b
end

-- A small square close button with an X.
function UI.CloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(24, 24)
    b:RegisterForClicks("LeftButtonUp")
    local x = UI.Text(b, 16, C.cream, "CENTER")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("×")
    b:SetScript("OnEnter", function() x:SetTextColor(Unpack(C.orange)) end)
    b:SetScript("OnLeave", function() x:SetTextColor(Unpack(C.cream)) end)
    b:SetScript("OnClick", onClick or function() parent:Hide() end)
    return b
end

---------------------------------------------------------------------------
-- Checkbox
---------------------------------------------------------------------------

function UI.Check(parent, label, onChange, tip)
    local b = CreateFrame("CheckButton", nil, parent)
    b:SetSize(18, 18)
    local box = UI.Frame(b, C.bgLight, C.edge)
    box:SetAllPoints()
    box:EnableMouse(false)
    local mark = b:CreateTexture(nil, "OVERLAY")
    mark:SetPoint("TOPLEFT", 4, -4)
    mark:SetPoint("BOTTOMRIGHT", -4, 4)
    mark:SetColorTexture(Unpack(C.gold))
    b:SetCheckedTexture(mark)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.9, 0.6, 0.15)
    b.text = UI.Text(b, 12, C.text)
    b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
    b.text:SetText(label or "")
    b:SetHitRectInsets(0, -(b.text:GetStringWidth() + 8), 0, 0)
    b:SetScript("OnClick", function(self)
        if onChange then onChange(self:GetChecked() and true or false, self) end
    end)
    if tip then
        b:SetScript("OnEnter", function(self) UI.Tip(self, label, { tip }) end)
        b:SetScript("OnLeave", HideTip)
    end
    return b
end

---------------------------------------------------------------------------
-- Text input
---------------------------------------------------------------------------

function UI.Input(parent, w, h, opts)
    opts = opts or {}
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(w or 120, h or 22)
    UI.Backdrop(e, { 0.02, 0.07, 0.09, 1 }, C.edgeDim)
    e:SetFont(T.FONT, 12, "")
    e:SetTextColor(Unpack(C.cream))
    e:SetTextInsets(6, 6, 0, 0)
    e:SetAutoFocus(false)
    if opts.numeric then e:SetNumeric(true) end
    if opts.max then e:SetMaxLetters(opts.max) end
    if opts.justify then e:SetJustifyH(opts.justify) end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if opts.onEnter then opts.onEnter(self) end
    end)
    e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(Unpack(C.gold)) end)
    e:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(Unpack(C.edgeDim))
        if opts.onCommit then opts.onCommit(self) end
    end)
    if opts.placeholder then
        local ph = UI.Text(e, 12, C.dim)
        ph:SetPoint("LEFT", 6, 0)
        ph:SetPoint("RIGHT", -6, 0)          -- clipped to the box (ends in "...") if too long
        ph:SetWordWrap(false)
        ph:SetText(opts.placeholder)
        local function Update() ph:SetShown(e:GetText() == "" and not e:HasFocus()) end
        e:HookScript("OnTextChanged", Update)
        e:HookScript("OnEditFocusGained", Update)
        e:HookScript("OnEditFocusLost", Update)
        e.UpdatePlaceholder = Update
    end
    return e
end

---------------------------------------------------------------------------
-- Role toggle: a big role icon with its name under it
---------------------------------------------------------------------------

function UI.RoleToggle(parent, role, size, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    size = size or 52
    -- wide enough for "Damage" whatever the icon size
    b:SetSize(math.max(size + 18, 64), size + 28)
    UI.Backdrop(b, C.bgLight, C.edgeDim)
    b.role = role
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(size, size)
    b.icon:SetPoint("TOP", 0, -6)
    b.label = UI.Text(b, 11, C.text, "CENTER")
    b.label:SetPoint("BOTTOMLEFT", 3, 6)
    b.label:SetPoint("BOTTOMRIGHT", -3, 6)
    b.label:SetWordWrap(false)
    b.label:SetText(T.ROLE_NAME[role])
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 0.9, 0.6, 0.10)
    function b:SetOn(on)
        self.on = on and true or false
        T.SetRole(self.icon, role, not self.on)
        self:SetBackdropBorderColor(Unpack(self.on and C.gold or C.edgeDim))
        self:SetBackdropColor(Unpack(self.on and { 0.12, 0.28, 0.26, 1 } or C.bgLight))
        self.label:SetTextColor(Unpack(self.on and C.cream or C.dim))
    end
    b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    b:SetOn(false)
    return b
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

function UI.Tabs(parent, labels, onSelect)
    local tabs = { buttons = {} }
    local prev
    for i, label in ipairs(labels) do
        local b = CreateFrame("Button", nil, parent)
        b:SetHeight(26)
        b.text = UI.Text(b, 13, C.dim, "CENTER")
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(label)
        b:SetWidth(b.text:GetStringWidth() + 28)
        b.line = b:CreateTexture(nil, "ARTWORK")
        b.line:SetPoint("BOTTOMLEFT", 6, 0)
        b.line:SetPoint("BOTTOMRIGHT", -6, 0)
        b.line:SetHeight(2)
        b.line:SetColorTexture(Unpack(C.gold))
        -- a count in an orange pill that pulses while it's showing (new applicants, say)
        b.badge = CreateFrame("Frame", nil, b)
        b.badge:SetSize(16, 14)
        b.badge:SetPoint("LEFT", b.text, "RIGHT", 4, 5)
        local pill = b.badge:CreateTexture(nil, "BACKGROUND")
        pill:SetAllPoints()
        pill:SetColorTexture(Unpack(C.orange))
        b.badge.text = UI.Text(b.badge, 10, { 0.06, 0.12, 0.14 }, "CENTER")
        b.badge.text:SetPoint("CENTER", 0, 0)
        local ag = b.badge:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.45)
        fade:SetDuration(0.7)
        b.badge.pulse = ag
        b.badge:Hide()
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.9, 0.6, 0.06)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) end
        b:SetScript("OnClick", function() tabs:Select(i) end)
        tabs.buttons[i] = b
        prev = b
    end
    function tabs:Select(i)
        self.selected = i
        for k, b in ipairs(self.buttons) do
            local on = k == i
            b.line:SetShown(on)
            b.text:SetTextColor(Unpack(on and C.cream or C.dim))
        end
        if onSelect then onSelect(i) end
    end
    function tabs:SetBadge(i, text)
        local badge = self.buttons[i].badge
        text = text and tostring(text) or ""
        if text == "" then
            badge.pulse:Stop()
            badge:Hide()
            return
        end
        badge.text:SetText(text)
        badge:SetWidth(math.max(16, badge.text:GetStringWidth() + 8))
        if not badge:IsShown() then
            badge:Show()
            badge.pulse:Play()
        end
    end
    return tabs
end

---------------------------------------------------------------------------
-- Dropdown (a button that opens the game's context menu)
---------------------------------------------------------------------------

function UI.Dropdown(parent, w, build)
    local b = UI.Button(parent, "", w, 22)
    b.label:SetJustifyH("LEFT")
    -- the game font has no ▼; a scrollbar arrow it is
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    arrow:SetTexCoord(0.2, 0.8, 0.25, 0.75)
    arrow:SetSize(14, 12)
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3])
    b.label:SetPoint("RIGHT", -18, 0)
    b:SetScript("OnClick", function(self)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root) build(root) end)
        end
    end)
    return b
end

-- A context menu at the cursor: build(root) adds root:CreateButton/CreateTitle/... entries.
function UI.Menu(owner, build)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root) build(root) end)
    end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- pos: a table to keep the window's place in ({ point, x, y }).
function UI.Window(name, w, h, title, pos)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    UI.Backdrop(f, C.bg, C.edge, 2)
    f:Hide()

    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", 0, 40)
    end

    -- title bar: a darker strip with a gold line under it
    local bar = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetPoint("TOPRIGHT", -2, -2)
    bar:SetHeight(44)
    bar:SetColorTexture(0.02, 0.07, 0.09, 0.9)
    local line = f:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
    line:SetHeight(2)
    line:SetColorTexture(Unpack(C.orange))
    f.titleBar = bar

    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", bar)
    drag:SetPoint("BOTTOMRIGHT", bar)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        if pos then
            local point, _, _, x, y = f:GetPoint(1)
            pos.point, pos.x, pos.y = point, x, y
        end
    end)

    -- the emblem badge breaks out of the top-left corner
    local badge = CreateFrame("Frame", nil, f)
    badge:SetSize(78, 78)
    badge:SetPoint("TOPLEFT", -26, 26)
    badge:SetFrameLevel(f:GetFrameLevel() + 10)
    local em = UI.Emblem(badge, 78)
    em:SetAllPoints()
    f.badge = badge

    f.title = UI.Title(f, 18)
    f.title:SetPoint("LEFT", bar, "LEFT", 60, 6)
    f.title:SetText(title or "")
    f.subtitle = UI.Text(f, 11, C.dim)
    f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)

    -- above the drag strip, which would otherwise take its clicks
    f.close = UI.CloseButton(f)
    f.close:SetPoint("TOPRIGHT", -6, -6)
    f.close:SetFrameLevel(drag:GetFrameLevel() + 5)

    if name then tinsert(UISpecialFrames, name) end
    return f
end

---------------------------------------------------------------------------
-- Scrolling list over a pool of rows
---------------------------------------------------------------------------

-- create(row) builds a row's widgets once; update(row, item, index) fills it.
function UI.List(parent, rowH, create, update)
    local list = CreateFrame("Frame", nil, parent)
    list.rowH = rowH
    list.items = {}
    list.rows = {}
    list.offset = 0
    list:SetClipsChildren(true)

    local bar = CreateFrame("Slider", nil, list, "BackdropTemplate")
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(8)
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    UI.Backdrop(bar, { 0.02, 0.07, 0.09, 0.8 }, { 0, 0, 0, 0 })
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Unpack(C.edge))
    thumb:SetSize(8, 30)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        if v ~= list.offset then
            list.offset = v
            list:Refresh()
        end
    end)
    list.bar = bar

    list.empty = UI.Text(list, 12, C.dim, "CENTER")
    list.empty:SetPoint("TOPLEFT", 10, -30)
    list.empty:SetPoint("TOPRIGHT", -18, -30)
    list.empty:SetWordWrap(true)

    local function Visible()
        local h = list:GetHeight() or 0
        return math.max(1, math.floor(h / rowH))
    end

    function list:Refresh()
        local n = Visible()
        local maxOff = math.max(0, #self.items - n)
        if self.offset > maxOff then self.offset = maxOff end
        self.bar:SetMinMaxValues(0, maxOff)
        self.bar:SetShown(maxOff > 0)
        if self.bar:GetValue() ~= self.offset then self.bar:SetValue(self.offset) end
        local width = (self:GetWidth() or 0) - (maxOff > 0 and 12 or 0)
        for i = 1, n do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, self)
                row:SetHeight(rowH)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
                create(row)
                self.rows[i] = row
            end
            row:SetWidth(width)
            local idx = self.offset + i
            local item = self.items[idx]
            if item then
                row.item = item
                update(row, item, idx)
                row:Show()
            else
                row.item = nil
                row:Hide()
            end
        end
        for i = n + 1, #self.rows do self.rows[i]:Hide() end
        self.empty:SetShown(#self.items == 0)
    end

    function list:SetItems(items)
        self.items = items or {}
        self:Refresh()
    end

    function list:SetEmptyText(text) self.empty:SetText(text) end

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta)
        local _, maxOff = self.bar:GetMinMaxValues()
        local v = math.max(0, math.min(maxOff, self.offset - delta * 2))
        self.bar:SetValue(v)
    end)
    list:SetScript("OnSizeChanged", function(self) self:Refresh() end)
    list:SetScript("OnShow", function(self) self:Refresh() end)
    return list
end

-- A row background that lights up on hover; returns the texture.
function UI.RowBackground(row, alt)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 0, -1)
    bg:SetPoint("BOTTOMRIGHT", 0, 1)
    bg:SetColorTexture(Unpack(C.bgRow))
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(bg)
    hl:SetColorTexture(1, 0.9, 0.6, 0.07)
    return bg
end

---------------------------------------------------------------------------
-- Quick whisper box
---------------------------------------------------------------------------

local qw
function UI.QuickWhisper(name)
    if not qw then
        qw = UI.Window("NerdelandslagetQuickWhisper", 360, 96, "Whisper")
        qw.badge:SetScale(0.6)
        qw.badge:ClearAllPoints()
        qw.badge:SetPoint("TOPLEFT", -14, 14)
        qw.title:SetPoint("LEFT", qw.titleBar, "LEFT", 40, 0)
        qw.subtitle:Hide()
        qw.input = UI.Input(qw, 330, 26, { max = 255, placeholder = "Type a message and press Enter",
            onEnter = function(self)
                ns.SendWhisper(self:GetText(), qw.target)
                self:SetText("")
                qw:Hide()
            end })
        qw.input:SetPoint("BOTTOM", 0, 14)
    end
    qw.target = name
    qw.title:SetText("Whisper " .. ns.Short(name))
    qw:Show()
    qw.input:SetFocus()
end
