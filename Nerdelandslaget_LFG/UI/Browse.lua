-- Browse: everyone listed. Groups looking for members, or players looking for a group,
-- filtered by dungeon and (optionally) by what fits you. Listings that fit come first and
-- carry a green edge. Whisper, Invite and Ask to join are one click; right-click for a menu.

local ADDON_NAME, ns = ...
local NL = Nerdelandslaget
local UI, T = NL.UI, NL.Theme
local C = T.c
local L = ns.LFG
local D = ns.Dungeons
local W = ns.Win

local ROW_H = 50

local function DungeonLines(set)
    local lines = {}
    for _, d in ipairs(D.Sorted(set)) do
        lines[#lines + 1] = { d.name, D.RangeText(d) }
    end
    if #lines == 0 then lines[1] = "Any dungeon" end
    return lines
end

local function Tooltip(row)
    local e, kind = row.item, row.kind
    local lines = {}
    local guild = "<" .. (NL.GUILDS[e.guild] or "?") .. ">"
    lines[#lines + 1] = { "Level " .. (e.level or "?"), guild }
    if kind == "group" then
        lines[#lines + 1] = { "Levels wanted", (e.min or 0) .. "-" .. (e.max or 0) }
        local needs, open = L.Needs(e.role, e.members)
        local want = {}
        for _, r in ipairs(T.ROLES) do
            if needs[r] > 0 then want[#want + 1] = needs[r] .. " " .. T.ROLE_NAME[r]:lower() end
        end
        lines[#lines + 1] = { "Needs", #want > 0 and table.concat(want, ", ") or (open > 0 and "anyone" or "full") }
        lines[#lines + 1] = { "Members", (1 + #(e.members or {})) .. " of 5" }
    else
        local roles = {}
        for _, r in ipairs(T.ROLES) do if e.roles and e.roles[r] then roles[#roles + 1] = T.ROLE_NAME[r] end end
        lines[#lines + 1] = { "Roles", table.concat(roles, ", ") }
    end
    if e.comment and e.comment ~= "" then lines[#lines + 1] = "|cffF6E7B0\"" .. e.comment .. "\"|r" end
    lines[#lines + 1] = " "
    for _, l in ipairs(DungeonLines(e.dungeons)) do lines[#lines + 1] = l end
    if not e.self then
        local fits, why
        if kind == "group" then fits, why = L.GroupFitsMe(e)
        elseif L.Leading() then fits, why = L.PlayerFitsMyGroup(e) end
        if fits ~= nil then
            lines[#lines + 1] = " "
            lines[#lines + 1] = fits and "|cff7bd65eFits you.|r" or ("|cffef8a3aDoesn't fit: " .. table.concat(why, ", ") .. ".|r")
        end
    end
    lines[#lines + 1] = "|cff8a8a8aListed " .. W.Age(e.since) .. (W.Age(e.since) == "now" and "" or " ago") .. "|r"
    UI.Tip(row, NL.ClassName(e.name, e.classFile) .. (e.self and " (you)" or ""), lines)
end

local function RowMenu(row)
    local e, kind = row.item, row.kind
    if e.self then return end
    UI.Menu(row, function(root)
        root:CreateTitle(NL.Short(e.name))
        root:CreateButton("Whisper", function() if not e.demo then NL.Whisper(e.name) end end)
        root:CreateButton("Invite", function() if not e.demo then NL.Invite(e.name) end end)
        if kind == "group" then
            root:CreateButton("Ask to join", function() if not e.demo then L.Apply(e.name) end end)
        end
    end)
end

function ns.BuildBrowse(parent)
    local page = CreateFrame("Frame", nil, parent)

    -- controls
    local groupsBtn = UI.Button(page, "Groups", 110, 24)
    groupsBtn:SetPoint("TOPLEFT", 0, 0)
    local playersBtn = UI.Button(page, "Players", 110, 24)
    playersBtn:SetPoint("LEFT", groupsBtn, "RIGHT", 4, 0)

    local function DungeonLabel()
        local id = L.db.browseDungeon or 0
        local d = D.byId[id]
        return d and d.name or "All dungeons"
    end
    local dd = UI.Dropdown(page, 230, function(root)
        root:CreateRadio("All dungeons", function() return (L.db.browseDungeon or 0) == 0 end,
            function() L.db.browseDungeon = 0 page:Refresh() end)
        root:CreateRadio("Mine (Sign up)", function() return L.db.browseDungeon == -1 end,
            function() L.db.browseDungeon = -1 page:Refresh() end)
        root:CreateDivider()
        for _, d in ipairs(D.list) do
            root:CreateRadio(d.name .. "  " .. D.RangeText(d), function() return L.db.browseDungeon == d.id end,
                function() L.db.browseDungeon = d.id page:Refresh() end)
        end
    end)
    dd:SetPoint("LEFT", playersBtn, "RIGHT", 16, 0)

    local fits = UI.Check(page, "Only what fits me", function(on)
        L.db.onlyFits = on
        page:Refresh()
    end, "Hides groups you're outside the level range of, that don't need your roles, or that are for none of the dungeons you signed up for. For players: the same, measured against the group you're setting up.")
    fits:SetPoint("LEFT", dd, "RIGHT", 16, 0)

    local refresh = UI.Button(page, "Refresh", 80, 24)
    refresh:SetPoint("TOPRIGHT", 0, 0)

    -- pop-up settings, in a small panel under their button
    local alertsBtn = UI.Button(page, "Pop-ups", 80, 24)
    alertsBtn:SetPoint("RIGHT", refresh, "LEFT", -6, 0)
    local pop = ns.BuildAlertsPanel(page)
    pop:SetPoint("TOPRIGHT", refresh, "BOTTOMRIGHT", 0, -4)
    pop:SetFrameLevel(page:GetFrameLevel() + 30)
    pop:Hide()
    alertsBtn:SetScript("OnClick", function() pop:SetShown(not pop:IsShown()) end)
    alertsBtn:SetScript("OnEnter", function(self)
        UI.Tip(self, "Pop-ups", { "A small pop-up when a group is listed for your level or your dungeons, and when someone asks to join yours." })
    end)
    function ns.Win.ShowAlerts() pop:Show() end
    page:HookScript("OnHide", function() pop:Hide() end)
    refresh:SetScript("OnClick", function()
        L.Query(true)
        refresh:Disable()
        C_Timer.After(5, function() refresh:Enable() end)
    end)

    groupsBtn:SetScript("OnClick", function() L.db.browseKind = "groups" page:Refresh() end)
    playersBtn:SetScript("OnClick", function() L.db.browseKind = "players" page:Refresh() end)

    -- the list
    local list = UI.List(page, ROW_H, function(row)
        row.bg = UI.RowBackground(row)
        row.fit = row:CreateTexture(nil, "ARTWORK")
        row.fit:SetPoint("TOPLEFT", 0, -1)
        row.fit:SetPoint("BOTTOMLEFT", 0, 1)
        row.fit:SetWidth(3)
        row.fit:SetColorTexture(C.green[1], C.green[2], C.green[3], 1)

        -- the glow on a group you came to from a pop-up
        row.flash = row:CreateTexture(nil, "BACKGROUND", nil, 2)
        row.flash:SetPoint("TOPLEFT", 0, -1)
        row.flash:SetPoint("BOTTOMRIGHT", 0, 1)
        row.flash:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.22)
        local ag = row.flash:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0.25)
        a:SetDuration(0.6)
        row.flash.pulse = ag
        row.flash:Hide()

        row.class = row:CreateTexture(nil, "ARTWORK")
        row.class:SetSize(30, 30)
        row.class:SetPoint("LEFT", 10, 0)
        row.name = UI.Text(row, 13, C.cream)
        row.name:SetPoint("TOPLEFT", 48, -8)
        row.name:SetWidth(190)
        row.info = UI.Text(row, 11, C.dim)
        row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.info:SetWidth(190)

        row.dungeons = UI.Text(row, 12, C.text)
        row.dungeons:SetPoint("TOPLEFT", 248, -8)
        row.dungeons:SetWidth(250)
        row.comment = UI.Text(row, 11, C.dim)
        row.comment:SetPoint("TOPLEFT", row.dungeons, "BOTTOMLEFT", 0, -4)
        row.comment:SetWidth(250)

        row.slots = {}
        for i = 1, 5 do
            local s = row:CreateTexture(nil, "ARTWORK")
            s:SetSize(20, 20)
            if i == 1 then s:SetPoint("LEFT", 512, 4) else s:SetPoint("LEFT", row.slots[i - 1], "RIGHT", 2, 0) end
            row.slots[i] = s
        end
        row.roles = W.RoleIcons(row, 20)
        row.roles[1]:SetPoint("LEFT", 512, 4)
        row.age = UI.Text(row, 10, C.dim)
        row.age:SetPoint("TOPLEFT", 512, -34)

        row.b2 = UI.Button(row, "", 92, 24, "primary")
        row.b2:SetPoint("RIGHT", -8, 0)
        row.b1 = UI.Button(row, "Whisper", 72, 24)
        row.b1:SetPoint("RIGHT", row.b2, "LEFT", -6, 0)
        row.b1:SetScript("OnClick", function(self)
            local e = self:GetParent().item
            if e and not e.demo then NL.Whisper(e.name) end
        end)
        row.b2:SetScript("OnClick", function(self)
            local r = self:GetParent()
            local e = r.item
            if not e or e.demo then return end
            if r.kind == "group" then L.Apply(e.name) else NL.Invite(e.name) end
        end)

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button) if button == "RightButton" then RowMenu(self) end end)
        row:SetScript("OnEnter", Tooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(row, e)
        local kind = L.db.browseKind == "players" and "player" or "group"
        row.kind = kind
        T.SetClass(row.class, e.classFile)
        row.name:SetText(NL.ClassName(e.name, e.classFile) .. (e.self and T.Color("  (you)", C.gold) or ""))
        local info = "Level " .. (e.level or "?") .. "  ·  " .. NL.GuildTag(e.guild)
        if kind == "group" then
            info = info .. "  ·  " .. (1 + #(e.members or {})) .. "/5"
        end
        row.info:SetText(info)
        local summary = D.Summary(e.dungeons, 4)
        if kind == "group" then
            summary = summary .. T.Color("   Lvl " .. (e.min or 0) .. "-" .. (e.max or 0), C.gold)
        end
        row.dungeons:SetText(summary)
        row.comment:SetText((e.comment and e.comment ~= "") and ("\"" .. e.comment .. "\"") or "")
        row.age:SetText(W.Age(e.since))
        local glow = kind == "group" and e.name == W.Highlighted()
        if glow ~= row.flash:IsShown() then
            row.flash:SetShown(glow)
            if glow then row.flash.pulse:Play() else row.flash.pulse:Stop() end
        end
        local fits = e.fitsShown
        row.fit:SetShown(fits and not e.self and true or false)
        row.bg:SetAlpha((fits ~= false or e.self) and 1 or 0.45)

        if kind == "group" then
            for i = 1, 3 do row.roles[i]:Hide() end
            -- slots: the roles filled (bright), then the roles still needed (dim)
            local needs, open = L.Needs(e.role, e.members)
            local shown = {}
            local filled = { e.role }
            for _, m in ipairs(e.members or {}) do filled[#filled + 1] = m.role or "?" end
            for _, r in ipairs({ "T", "H", "D", "?" }) do
                for _, f in ipairs(filled) do if f == r then shown[#shown + 1] = { r, false } end end
            end
            for _, r in ipairs(T.ROLES) do
                for _ = 1, needs[r] do shown[#shown + 1] = { r, true } end
            end
            for i = 1, 5 do
                local s = shown[i]
                row.slots[i]:Show()
                if s and s[1] ~= "?" then T.SetRole(row.slots[i], s[1], s[2])
                elseif s then T.SetRole(row.slots[i], nil) row.slots[i]:SetVertexColor(1, 1, 1, 0.5)
                else T.SetRole(row.slots[i], nil) end
            end
            if e.self then
                row.b1:Hide() row.b2:Hide()
            else
                row.b1:Show() row.b2:Show()
                local applied = L.applied[e.name]
                if applied and applied.declined then
                    row.b2:SetLabel("Declined")
                    row.b2:Disable()
                elseif applied then
                    row.b2:SetLabel("Asked")
                    row.b2:Disable()
                elseif open <= 0 or IsInGroup() then
                    row.b2:SetLabel("Ask to join")
                    row.b2:Disable()
                else
                    row.b2:SetLabel("Ask to join")
                    row.b2:Enable()
                end
            end
        else
            for i = 1, 5 do row.slots[i]:Hide() end
            row.roles:Set(e.roles, false)
            if e.self then
                row.b1:Hide() row.b2:Hide()
            else
                row.b1:Show() row.b2:Show()
                row.b2:SetLabel("Invite")
                row.b2:SetEnabled(not L.InGroupNotLeader())
            end
        end
    end)
    list:SetPoint("TOPLEFT", 0, -34)
    list:SetPoint("BOTTOMRIGHT", 0, 0)

    local function Matches(e)
        local f = L.db.browseDungeon or 0
        if f == -1 then
            if next(L.char.dungeons) and next(e.dungeons or {}) and not D.Overlaps(L.char.dungeons, e.dungeons) then
                return false
            end
        elseif f > 0 and next(e.dungeons or {}) and not (e.dungeons and e.dungeons[f]) then
            return false
        end
        return true
    end

    function page:Refresh()
        local players = L.db.browseKind == "players"
        groupsBtn:SetKind(players and "normal" or "primary")
        playersBtn:SetKind(players and "primary" or "normal")
        local nG, nP = 0, 0
        for _ in pairs(L.groups) do nG = nG + 1 end
        for _ in pairs(L.players) do nP = nP + 1 end
        groupsBtn:SetLabel("Groups (" .. nG + (L.char.group.listed and 1 or 0) .. ")")
        playersBtn:SetLabel("Players (" .. nP + (L.char.listed and 1 or 0) .. ")")
        dd:SetLabel(L.db.browseDungeon == -1 and "My dungeons" or DungeonLabel())
        fits:SetChecked(L.db.onlyFits)

        local items = {}
        local src = players and L.players or L.groups
        local hl = not players and W.Highlighted()
        local mine = players and L.MyPlayerEntry() or L.MyGroupEntry()
        if mine then items[#items + 1] = mine end
        for _, e in pairs(src) do
            if e.name == hl then
                e._fits = L.GroupFitsMe(e)
                items[#items + 1] = e
            elseif Matches(e) then
                local ok
                if players then
                    if L.Leading() then ok = L.PlayerFitsMyGroup(e) end
                else
                    ok = L.GroupFitsMe(e)
                end
                e._fits = ok
                if not (L.db.onlyFits and ok == false) then items[#items + 1] = e end
            end
        end
        table.sort(items, function(a, b)
            if a.self ~= b.self then return a.self and true or false end
            if hl and (a.name == hl) ~= (b.name == hl) then return a.name == hl end
            local fa, fb = a._fits and 1 or 0, b._fits and 1 or 0
            if fa ~= fb then return fa > fb end
            return (a.since or 0) > (b.since or 0)
        end)
        for _, e in ipairs(items) do e.fitsShown = e._fits end
        list:SetEmptyText(players
            and "Nobody is looking for a group right now.\n\nSign up yourself, or start a group under My group."
            or "No groups are listed right now.\n\nStart one under My group, or sign up and get a ping when one appears.")
        if W.scrollTop then
            W.scrollTop = nil
            list.offset = 0
        end
        list:SetItems(items)
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)
    return page
end
