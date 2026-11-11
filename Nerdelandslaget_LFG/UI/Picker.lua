-- Picker: a checklist of every dungeon, by level, with the range coloured for your level.
-- Used by Sign up (the dungeons you'd run) and My group (the dungeons the group is for).
--
--   local p = ns.Picker(parent, getSet, onChange)   getSet() returns the { [id] = true } table
--   p:Refresh()

local ADDON_NAME, ns = ...
local NL = Nerdelandslaget
local UI, T = NL.UI, NL.Theme
local C = T.c
local D = ns.Dungeons

function ns.Picker(parent, title, getSet, onChange)
    local f = UI.Frame(parent, { 0.02, 0.07, 0.09, 0.6 }, C.edgeDim)

    local head = UI.Title(f, 14)
    head:SetPoint("TOPLEFT", 10, -10)
    head:SetText(title)
    local count = UI.Text(f, 11, C.dim)
    count:SetPoint("LEFT", head, "RIGHT", 8, -1)

    local clear = UI.Button(f, "Clear", 60, 20)
    clear:SetPoint("TOPRIGHT", -10, -8)
    local mine = UI.Button(f, "My level", 76, 20)
    mine:SetPoint("RIGHT", clear, "LEFT", -6, 0)
    mine:SetScript("OnEnter", function(self)
        UI.Tip(self, "My level", { "Picks every dungeon in range for your level (or a level below it)." })
    end)

    local list = UI.List(f, 30, function(row)
        UI.RowBackground(row)
        row.box = UI.Frame(row, C.bgLight, C.edge)
        row.box:SetSize(16, 16)
        row.box:SetPoint("LEFT", 6, 0)
        row.box:EnableMouse(false)
        row.mark = row.box:CreateTexture(nil, "OVERLAY")
        row.mark:SetPoint("TOPLEFT", 3, -3)
        row.mark:SetPoint("BOTTOMRIGHT", -3, 3)
        row.mark:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
        row.name = UI.Text(row, 12, C.cream)
        row.name:SetPoint("TOPLEFT", row.box, "TOPRIGHT", 8, 5)
        row.zone = UI.Text(row, 10, C.dim)
        row.zone:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.tag = UI.Text(row, 9, C.orange)
        row.tag:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.range = UI.Text(row, 12, C.text, "RIGHT")
        row.range:SetPoint("RIGHT", -8, 0)
        row:SetScript("OnClick", function(self)
            local set = getSet()
            local id = self.item.id
            set[id] = (not set[id]) or nil
            onChange()
        end)
        row:SetScript("OnEnter", function(self)
            local d = self.item
            local lines = { d.zone, { "Levels", d.min .. "-" .. d.max } }
            if d.new then lines[#lines + 1] = "New in Forever. ForeverDungeonJournal listed it as not open yet." end
            UI.Tip(self, d.name, lines)
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(row, d)
        local on = getSet()[d.id] and true or false
        row.mark:SetShown(on)
        row.name:SetText(d.name)
        row.name:SetTextColor(C.cream[1], C.cream[2], C.cream[3], on and 1 or 0.85)
        row.zone:SetText(d.zone)
        row.tag:SetText(d.new and "NEW" or "")
        row.range:SetText(D.RangeText(d))
    end)
    list:SetPoint("TOPLEFT", 6, -36)
    list:SetPoint("BOTTOMRIGHT", -6, 6)
    f.list = list

    function f:Refresh()
        count:SetText(D.Count(getSet()) .. " picked")
        list:SetItems(D.list)
    end

    mine:SetScript("OnClick", function()
        local set = getSet()
        wipe(set)
        for _, d in ipairs(D.list) do
            if D.Suits(d) then set[d.id] = true end
        end
        onChange()
    end)
    clear:SetScript("OnClick", function()
        wipe(getSet())
        onChange()
    end)

    -- start on the first dungeon that suits the player
    f:SetScript("OnShow", function()
        local level = UnitLevel("player")
        for i, d in ipairs(D.list) do
            if d.max >= level - 1 then
                list.offset = math.max(0, i - 2)
                break
            end
        end
        f:Refresh()
        f:SetScript("OnShow", function() f:Refresh() end)
    end)
    return f
end
