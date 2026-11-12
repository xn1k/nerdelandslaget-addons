-- Sign up: list yourself. Pick your roles (any of the three), every dungeon you'd run, a
-- comment, and go. Changes while listed go out on their own a moment later.

local ADDON_NAME, ns = ...
local NL = Nerdelandslaget
local UI, T = NL.UI, NL.Theme
local C = T.c
local L = ns.LFG
local D = ns.Dungeons

function ns.BuildSignUp(parent)
    local page = CreateFrame("Frame", nil, parent)

    local left = CreateFrame("Frame", nil, page)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(300)

    local function Changed()
        if L.char.listed then L.SendSoon(1.5) end
        L.Changed()
    end

    local h1 = UI.Title(left, 14)
    h1:SetPoint("TOPLEFT", 4, -4)
    h1:SetText("Your roles")
    local h1b = UI.Text(left, 11, C.dim)
    h1b:SetPoint("LEFT", h1, "RIGHT", 8, -1)
    h1b:SetText("pick all you're happy to play")

    local roles = {}
    for i, r in ipairs(T.ROLES) do
        local b = UI.RoleToggle(left, r, 48, function(self)
            L.char.roles[r] = (not L.char.roles[r]) or nil
            Changed()
        end)
        if i == 1 then b:SetPoint("TOPLEFT", 4, -28) else b:SetPoint("LEFT", roles[i - 1], "RIGHT", 10, 0) end
        roles[i] = b
    end

    local h2 = UI.Title(left, 14)
    h2:SetPoint("TOPLEFT", 4, -136)
    h2:SetText("Comment")
    local comment = UI.Input(left, 292, 26, {
        max = L.COMMENT_MAX,
        placeholder = "Optional, e.g. \"evenings only\"",
        onCommit = function(self)
            local text = NL.Comm.Clean(self:GetText(), L.COMMENT_MAX)
            if text ~= L.char.comment then
                L.char.comment = text
                Changed()
            end
        end,
    })
    comment:SetPoint("TOPLEFT", 4, -158)

    local status = UI.Text(left, 12, C.text)
    status:SetPoint("TOPLEFT", 4, -200)
    status:SetWidth(292)
    status:SetWordWrap(true)

    local listBtn = UI.Button(left, "List me", 140, 30, "primary")
    listBtn:SetPoint("TOPLEFT", 4, -250)
    listBtn:SetScript("OnClick", function()
        comment:ClearFocus()
        if L.char.listed then L.DelistSelf() else L.ListSelf() end
    end)

    local tip = UI.Text(left, 11, C.dim)
    tip:SetPoint("TOPLEFT", 4, -300)
    tip:SetWidth(292)
    tip:SetWordWrap(true)
    tip:SetText("Pick every dungeon you'd happily run. Leaders see you if any of them match, groups that "
        .. "fit you come first under Browse, and you get a ping when a new one is listed.\n\n"
        .. "Joining a group takes you off the list.")

    local picker = ns.Picker(page, "Dungeons I'd run", function() return L.char.dungeons end, Changed)
    picker:SetPoint("TOPLEFT", left, "TOPRIGHT", 16, 0)
    picker:SetPoint("BOTTOMRIGHT", 0, 0)

    function page:Refresh()
        local c = L.char
        for i, r in ipairs(T.ROLES) do roles[i]:SetOn(c.roles[r]) end
        if not comment:HasFocus() then
            comment:SetText(c.comment or "")
            if comment.UpdatePlaceholder then comment.UpdatePlaceholder() end
        end
        local n = D.Count(c.dungeons)
        if c.listed then
            status:SetText(T.Color("You're listed", C.green) .. " for "
                .. (n > 0 and (n .. " dungeon" .. (n == 1 and "" or "s")) or "any dungeon")
                .. " as " .. L.RoleNames(c.roles) .. ". Listed " .. ns.Win.Age(c.listedAt) .. (ns.Win.Age(c.listedAt) == "now" and "" or " ago") .. ".")
            listBtn:SetLabel("Delist me")
            listBtn:SetKind("danger")
            listBtn:Enable()
        else
            local ok, why = L.CanListSelf()
            if L.char.group.listed then
                ok, why = false, "Your group is listed. Delist it under My group to sign up alone."
            end
            status:SetText(ok and ("Not listed. " .. (n == 0 and "With no dungeons picked you're up for anything." or ""))
                or T.Color(why, C.orange))
            listBtn:SetLabel("List me")
            listBtn:SetKind("primary")
            listBtn:SetEnabled(ok)
        end
        picker:Refresh()
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)
    return page
end
