-- My group: start a group and list it. Your role, a level range (follows the dungeons you
-- pick unless you type one), the dungeons, a comment. While it's listed: the members with
-- their roles (click a member's role to change it), the open places, and the players asking
-- to join, each with Invite, Whisper and Decline.

local ADDON_NAME, ns = ...
local NL = Nerdelandslaget
local UI, T = NL.UI, NL.Theme
local C = T.c
local L = ns.LFG
local D = ns.Dungeons
local W = ns.Win

local LEFT_W = 336

local function Changed()
    if L.char.group.listed then L.SendSoon(1.5) end
    L.Changed()
end

-- The level range follows the dungeons until the leader types one.
local function AutoLevels()
    local g = L.char.group
    if g.manualLevels then return end
    local lo, hi = D.Span(g.dungeons)
    if lo then
        g.min, g.max = lo, hi
    else
        local lvl = UnitLevel("player")
        g.min, g.max = math.max(1, lvl - 4), math.min(D.MAX_LEVEL, lvl + 4)
    end
end

function ns.BuildGroup(parent)
    local page = CreateFrame("Frame", nil, parent)
    local left = CreateFrame("Frame", nil, page)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(LEFT_W)

    -- my role
    local h1 = UI.Title(left, 14)
    h1:SetPoint("TOPLEFT", 4, -4)
    h1:SetText("Your role")
    local roles = {}
    for i, r in ipairs(T.ROLES) do
        local b = UI.RoleToggle(left, r, 26, function()
            L.char.group.role = r
            Changed()
        end)
        if i == 1 then b:SetPoint("TOPLEFT", 4, -24) else b:SetPoint("LEFT", roles[i - 1], "RIGHT", 6, 0) end
        roles[i] = b
    end

    -- levels
    local h2 = UI.Title(left, 14)
    h2:SetPoint("TOPLEFT", 160, -4)
    h2:SetText("Levels")
    local function CommitLevels()
        local g = L.char.group
        local lo, hi = tonumber(page.minBox:GetText()), tonumber(page.maxBox:GetText())
        lo = lo and math.max(1, math.min(D.MAX_LEVEL, lo)) or g.min
        hi = hi and math.max(1, math.min(D.MAX_LEVEL, hi)) or g.max
        if lo ~= g.min or hi ~= g.max then
            g.min, g.max = lo, hi
            g.manualLevels = true
            Changed()
        end
    end
    page.minBox = UI.Input(left, 44, 24, { numeric = true, max = 2, justify = "CENTER", onCommit = CommitLevels })
    page.minBox:SetPoint("TOPLEFT", 160, -28)
    local to = UI.Text(left, 12, C.dim)
    to:SetPoint("LEFT", page.minBox, "RIGHT", 6, 0)
    to:SetText("to")
    page.maxBox = UI.Input(left, 44, 24, { numeric = true, max = 2, justify = "CENTER", onCommit = CommitLevels })
    page.maxBox:SetPoint("LEFT", to, "RIGHT", 6, 0)
    page.minBox:SetScript("OnTabPressed", function() page.maxBox:SetFocus() end)
    page.maxBox:SetScript("OnTabPressed", function() page.minBox:SetFocus() end)
    local match = UI.Button(left, "From dungeons", 118, 20)
    match:SetPoint("TOPLEFT", 160, -58)
    match:SetScript("OnClick", function()
        L.char.group.manualLevels = false
        AutoLevels()
        Changed()
    end)
    match:SetScript("OnEnter", function(self)
        UI.Tip(self, "From dungeons", { "Sets the range to cover the dungeons you picked, and keeps it following them." })
    end)

    -- comment + list button
    local comment = UI.Input(left, LEFT_W - 8, 26, {
        max = L.COMMENT_MAX,
        placeholder = "Comment: \"SM GY then Lib\", \"need a healer\"",
        onCommit = function(self)
            local text = NL.Comm.Clean(self:GetText(), L.COMMENT_MAX)
            if text ~= L.char.group.comment then
                L.char.group.comment = text
                Changed()
            end
        end,
    })
    comment:SetPoint("TOPLEFT", 4, -96)

    local listBtn = UI.Button(left, "List group", 130, 28, "primary")
    listBtn:SetPoint("TOPLEFT", 4, -130)
    listBtn:SetScript("OnClick", function()
        comment:ClearFocus()
        page.minBox:ClearFocus()
        page.maxBox:ClearFocus()
        if L.char.group.listed then L.DelistGroup() else L.ListGroup() end
    end)
    local status = UI.Text(left, 11, C.text)
    status:SetPoint("LEFT", listBtn, "RIGHT", 10, 0)
    status:SetWidth(LEFT_W - 150)
    status:SetWordWrap(true)

    -- members
    local h3 = UI.Title(left, 14)
    h3:SetPoint("TOPLEFT", 4, -172)
    h3:SetText("Group")
    local need = UI.Text(left, 11, C.dim)
    need:SetPoint("LEFT", h3, "RIGHT", 8, -1)

    local slots = {}
    for i = 1, 5 do
        local s = CreateFrame("Button", nil, left)
        s:SetSize(LEFT_W - 8, 22)
        s:SetPoint("TOPLEFT", 4, -192 - (i - 1) * 23)
        s.bg = UI.RowBackground(s)
        s.role = s:CreateTexture(nil, "ARTWORK")
        s.role:SetSize(18, 18)
        s.role:SetPoint("LEFT", 4, 0)
        s.class = s:CreateTexture(nil, "ARTWORK")
        s.class:SetSize(16, 16)
        s.class:SetPoint("LEFT", s.role, "RIGHT", 6, 0)
        s.name = UI.Text(s, 12, C.cream)
        s.name:SetPoint("LEFT", s.class, "RIGHT", 6, 0)
        s.level = UI.Text(s, 11, C.dim, "RIGHT")
        s.level:SetPoint("RIGHT", -6, 0)
        s:SetScript("OnClick", function(self)
            if self.member and self.member.name then
                L.CycleMemberRole(self.member.name, self.member.role)
            end
        end)
        s:SetScript("OnEnter", function(self)
            if self.member and self.member.name then
                UI.Tip(self, NL.Short(self.member.name), { "Click to change the role they play: tank, healer, damage.",
                    "Members with the addon tell you their roles themselves." })
            end
        end)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slots[i] = s
    end

    -- applicants
    local h4 = UI.Title(left, 14)
    h4:SetPoint("TOPLEFT", 4, -312)
    h4:SetText("Asking to join")
    local appList = UI.List(left, 46, function(row)
        UI.RowBackground(row)
        row.class = row:CreateTexture(nil, "ARTWORK")
        row.class:SetSize(24, 24)
        row.class:SetPoint("LEFT", 4, 0)
        row.name = UI.Text(row, 12, C.cream)
        row.name:SetPoint("TOPLEFT", 34, -6)
        row.name:SetWidth(150)
        row.roles = W.RoleIcons(row, 16)
        row.roles[1]:SetPoint("TOPLEFT", 34, -24)
        row.comment = UI.Text(row, 10, C.dim)
        row.comment:SetPoint("LEFT", row.roles[3], "RIGHT", 6, 0)
        row.comment:SetWidth(110)
        row.decline = UI.Button(row, "×", 22, 22, "danger")
        row.decline:SetPoint("RIGHT", -4, 0)
        row.whisper = UI.Button(row, "Whisper", 58, 22)
        row.whisper:SetPoint("RIGHT", row.decline, "LEFT", -4, 0)
        row.invite = UI.Button(row, "Invite", 52, 22, "primary")
        row.invite:SetPoint("RIGHT", row.whisper, "LEFT", -4, 0)
        row.invite:SetScript("OnClick", function(self) L.InviteApplicant(self:GetParent().item.name) end)
        row.whisper:SetScript("OnClick", function(self) NL.Whisper(self:GetParent().item.name) end)
        row.decline:SetScript("OnClick", function(self) L.Decline(self:GetParent().item.name) end)
        row.decline:SetScript("OnEnter", function(self) UI.Tip(self, "Decline", { "Tells them no, kindly." }) end)
        row:SetScript("OnEnter", function(self)
            local a = self.item
            local fits, why = L.PlayerFitsMyGroup(a)
            local lines = { { "Level", a.level }, { "Roles", L.RoleNames(a.roles) } }
            if a.comment ~= "" then lines[#lines + 1] = "\"" .. a.comment .. "\"" end
            lines[#lines + 1] = fits and "|cff7bd65eFits your group.|r"
                or ("|cffef8a3aDoesn't fit: " .. table.concat(why, ", ") .. ".|r")
            UI.Tip(self, NL.ClassName(a.name, a.classFile), lines)
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(row, a)
        T.SetClass(row.class, a.classFile)
        row.name:SetText(NL.ClassName(a.name, a.classFile) .. T.Color("  " .. a.level, C.dim))
        row.roles:Set(a.roles, false)
        row.comment:SetText(a.comment or "")
        row.invite:SetLabel(a.invited and "Sent" or "Invite")
    end)
    appList:SetPoint("TOPLEFT", 4, -332)
    appList:SetPoint("BOTTOMRIGHT", 0, 0)
    appList:SetEmptyText("Nobody yet. Players who click Ask to join on your group show up here.")

    -- dungeons
    local picker = ns.Picker(page, "Dungeons for the group", function() return L.char.group.dungeons end, function()
        AutoLevels()
        Changed()
    end)
    picker:SetPoint("TOPLEFT", left, "TOPRIGHT", 14, 0)
    picker:SetPoint("BOTTOMRIGHT", 0, 0)

    function page:Refresh()
        local g = L.char.group
        if (g.min or 0) == 0 or (g.max or 0) == 0 then AutoLevels() end
        for i, r in ipairs(T.ROLES) do roles[i]:SetOn(g.role == r) end
        if not page.minBox:HasFocus() then page.minBox:SetText(tostring(g.min or "")) end
        if not page.maxBox:HasFocus() then page.maxBox:SetText(tostring(g.max or "")) end
        if not comment:HasFocus() then
            comment:SetText(g.comment or "")
            if comment.UpdatePlaceholder then comment.UpdatePlaceholder() end
        end

        if g.listed then
            listBtn:SetLabel("Delist group")
            listBtn:SetKind("danger")
            listBtn:Enable()
            status:SetText(T.Color("Listed", C.green) .. " " .. W.Age(g.listedAt)
                .. (W.Age(g.listedAt) == "now" and "" or " ago") .. ". Changes go out by themselves.")
        else
            local ok, why = L.CanListGroup()
            listBtn:SetLabel("List group")
            listBtn:SetKind("primary")
            listBtn:SetEnabled(ok)
            status:SetText(ok and "Not listed." or T.Color(why, C.orange))
        end

        -- members: me, then the party, then the open places
        local members = L.Members()
        local needs, open = L.Needs(g.role, members)
        local rows = { { me = true, name = NL.Me(), classFile = select(2, UnitClass("player")),
            level = UnitLevel("player"), role = g.role } }
        for _, m in ipairs(members) do rows[#rows + 1] = m end
        local want = {}
        for _, r in ipairs(T.ROLES) do
            for _ = 1, needs[r] do want[#want + 1] = r end
        end
        for i = 1, 5 do
            local s = slots[i]
            local m = rows[i]
            s.member = (m and not m.me) and m or nil
            if m then
                T.SetRole(s.role, m.role or nil)
                if not m.role then s.role:SetVertexColor(1, 1, 1, 0.5) end
                T.SetClass(s.class, m.classFile)
                s.name:SetText(m.name and (NL.ClassName(m.name, m.classFile) .. (m.me and T.Color("  (you)", C.gold) or ""))
                    or T.Color("(unknown)", C.dim))
                s.level:SetText(m.level and ("Level " .. m.level) or "")
                s.bg:SetAlpha(1)
            else
                local r = want[i - #rows]
                T.SetRole(s.role, r, true)
                s.class:Hide()
                s.name:SetText(T.Color(r and ("Looking for a " .. T.ROLE_NAME[r]:lower()) or "Open", C.dim))
                s.level:SetText("")
                s.bg:SetAlpha(0.4)
            end
        end
        local parts = {}
        for _, r in ipairs(T.ROLES) do
            if needs[r] > 0 then parts[#parts + 1] = needs[r] .. " " .. T.ROLE_NAME[r]:lower() end
        end
        need:SetText((1 + #members) .. "/5" .. (#parts > 0 and ("  ·  needs " .. table.concat(parts, ", ")) or ""))

        local apps = {}
        for _, a in pairs(L.applicants) do apps[#apps + 1] = a end
        table.sort(apps, function(a, b) return a.at < b.at end)
        h4:SetText("Asking to join" .. (#apps > 0 and (" (" .. #apps .. ")") or ""))
        appList:SetItems(apps)
        picker:Refresh()
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)
    return page
end
