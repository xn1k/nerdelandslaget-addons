-- Alerts: the pop-up settings.
--
--   ns.BuildAlerts(parent, onPick)   the settings block: the Browse tab's "Pop-ups" panel puts
--                                    a dungeon picker beside it; the options page has no room
--                                    for one and passes onPick for a "Pick dungeons" button
--   ns.BuildAlertsPanel(parent)      block + picker, as the Browse panel uses it
--
--   [x] Pop up when a new group is listed
--       (o) For my level                 groups whose range includes your level
--       (o) For levels [30] to [40]
--       (o) For dungeons I pick          SM Lib, SM Arm +2
--   [x] Pop up when someone asks to join my group
--   [Show a test pop-up]  [Reset position]

local ADDON_NAME, ns = ...
local NL = Nerdelandslaget
local UI, T = NL.UI, NL.Theme
local C = T.c
local L = ns.LFG
local D = ns.Dungeons

local BLOCK_W, BLOCK_H = 332, 214
local blocks = {}

function ns.RefreshAlerts()
    for _, b in ipairs(blocks) do if b:IsVisible() then b:Refresh() end end
end

local function SetMode(mode)
    L.db.toastMode = mode
    ns.RefreshAlerts()
end

function ns.BuildAlerts(parent, onPick)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(BLOCK_W, BLOCK_H)
    local db = L.db

    local groups = UI.Check(f, "Pop up when a new group is listed", function(on)
        db.toastGroups = on
        ns.RefreshAlerts()
    end, "A small pop-up, like a friend logging on, when someone in the guilds lists a group you'd want. "
        .. "Click it to see the group, or ask to join right on it. Not while you're in a group or leading one.")
    groups:SetPoint("TOPLEFT", 0, 0)

    local mine = UI.Check(f, "For my level", function() SetMode("level") end,
        "Groups whose level range includes your level. It follows you as you level.")
    mine:SetPoint("TOPLEFT", 22, -26)

    local range = UI.Check(f, "For levels", function() SetMode("range") end,
        "Groups whose level range overlaps the one you set here.")
    range:SetPoint("TOPLEFT", 22, -52)

    local minBox, maxBox
    local function Commit()
        local lo, hi = tonumber(minBox:GetText()), tonumber(maxBox:GetText())
        if lo then db.toastMin = math.max(1, math.min(D.MAX_LEVEL, math.floor(lo))) end
        if hi then db.toastMax = math.max(1, math.min(D.MAX_LEVEL, math.floor(hi))) end
        if db.toastMin > db.toastMax then db.toastMin, db.toastMax = db.toastMax, db.toastMin end
        ns.RefreshAlerts()
    end
    minBox = UI.Input(f, 36, 22, { numeric = true, max = 2, justify = "CENTER", onCommit = Commit })
    minBox:SetPoint("LEFT", range.text, "RIGHT", 10, 0)
    local to = UI.Text(f, 12, C.dim)
    to:SetPoint("LEFT", minBox, "RIGHT", 6, 0)
    to:SetText("to")
    maxBox = UI.Input(f, 36, 22, { numeric = true, max = 2, justify = "CENTER", onCommit = Commit })
    maxBox:SetPoint("LEFT", to, "RIGHT", 6, 0)
    -- typing a range means you want the range
    for _, box in ipairs({ minBox, maxBox }) do
        box:HookScript("OnEditFocusGained", function()
            if db.toastMode ~= "range" then SetMode("range") end
        end)
    end
    minBox:SetScript("OnTabPressed", function() maxBox:SetFocus() end)
    maxBox:SetScript("OnTabPressed", function() minBox:SetFocus() end)

    local dung = UI.Check(f, "For dungeons I pick", function() SetMode("dungeons") end,
        "Groups for any of the dungeons you pick. A group listed for no dungeon in particular pops up if it takes your level.")
    dung:SetPoint("TOPLEFT", 22, -78)
    local picked = UI.Text(f, 11, C.dim)
    picked:SetPoint("TOPLEFT", 46, -98)
    picked:SetPoint("RIGHT", f, "RIGHT", onPick and -96 or 0, 0)
    if onPick then
        local pick = UI.Button(f, "Pick dungeons", 90, 20)
        pick:SetPoint("TOPRIGHT", 0, -94)
        pick:SetScript("OnClick", function()
            SetMode("dungeons")
            onPick()
        end)
    end

    local apps = UI.Check(f, "Pop up when someone asks to join my group", function(on)
        db.toastApplicants = on
        ns.RefreshAlerts()
    end, "With Invite and Whisper right on it. The minimap button glows and the My group tab shows a count too.")
    apps:SetPoint("TOPLEFT", 0, -126)

    local test = UI.Button(f, "Show a test pop-up", 140, 22)
    test:SetPoint("TOPLEFT", 0, -160)
    test:SetScript("OnClick", function() L.TestToasts() end)
    local reset = UI.Button(f, "Reset position", 110, 22)
    reset:SetPoint("LEFT", test, "RIGHT", 6, 0)
    reset:SetScript("OnClick", function() NL.Toast.ResetPosition() end)
    reset:SetScript("OnEnter", function(self)
        UI.Tip(self, "Reset position", { "Pop-ups show above the chat. Drag one to move them; this puts them back." })
    end)

    local note = UI.Text(f, 10, C.dim)
    note:SetPoint("TOPLEFT", 0, -192)
    note:SetWidth(BLOCK_W)

    local function Dim(check, on)
        check:SetEnabled(on)
        check.text:SetTextColor(C.text[1], C.text[2], C.text[3], on and 1 or 0.4)
    end

    function f:Refresh()
        local mode, on = db.toastMode, db.toastGroups
        groups:SetChecked(on)
        mine:SetChecked(mode ~= "range" and mode ~= "dungeons")
        range:SetChecked(mode == "range")
        dung:SetChecked(mode == "dungeons")
        Dim(mine, on)
        Dim(range, on)
        Dim(dung, on)
        minBox:SetAlpha((on and mode == "range") and 1 or 0.5)
        maxBox:SetAlpha((on and mode == "range") and 1 or 0.5)
        if not minBox:HasFocus() then minBox:SetText(tostring(db.toastMin or 1)) end
        if not maxBox:HasFocus() then maxBox:SetText(tostring(db.toastMax or D.MAX_LEVEL)) end
        local n = D.Count(db.toastDungeons)
        picked:SetText(n > 0 and D.Summary(db.toastDungeons, 3) or "None picked yet")
        picked:SetAlpha((on and mode == "dungeons") and 1 or 0.6)
        apps:SetChecked(db.toastApplicants)

        local which
        if mode == "dungeons" then
            which = n > 0 and ("groups for " .. n .. " dungeon" .. (n == 1 and "" or "s")) or "pick some dungeons"
        else
            local lo, hi = L.ToastRange()
            which = lo == hi and ("groups that take level " .. lo) or ("groups for levels in " .. lo .. "-" .. hi)
        end
        note:SetText(on and ("New-group pop-ups: " .. which .. ".") or "No pop-ups for new groups.")
    end
    f:SetScript("OnShow", function(self) self:Refresh() end)
    f:Refresh()
    blocks[#blocks + 1] = f
    return f
end

-- The settings with the dungeon list beside them. Ticking a dungeon switches to "For
-- dungeons I pick".
function ns.BuildAlertsPanel(parent)
    local f = UI.Frame(parent, C.bg, C.edge)
    f:SetSize(12 + BLOCK_W + 14 + 320 + 12, 340)
    f:EnableMouse(true)
    local block = ns.BuildAlerts(f)
    block:SetPoint("TOPLEFT", 12, -14)

    local picker
    picker = ns.Picker(f, "Dungeons", function() return L.db.toastDungeons end, function()
        L.db.toastMode = "dungeons"
        picker:Refresh()
        ns.RefreshAlerts()
    end)
    picker:SetPoint("TOPLEFT", 12 + BLOCK_W + 14, -30)
    picker:SetPoint("BOTTOMRIGHT", -12, 12)

    local close = UI.CloseButton(f, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetFrameLevel(picker:GetFrameLevel() + 5)
    f.picker = picker
    return f
end
