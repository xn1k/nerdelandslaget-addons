-- Options: the Dungeon Finder's page under Nerdelandslaget in Options > AddOns.

local ADDON_NAME, ns = ...
local NL = Nerdelandslaget
local UI, T = NL.UI, NL.Theme
local C = T.c
local L = ns.LFG

function ns.BuildOptions()
    local page, y = NL.OptionsPage("Dungeon Finder")
    local db = L.db

    local open = UI.Button(page, "Open the Dungeon Finder", 200, 26, "primary")
    open:SetPoint("TOPLEFT", 18, y)
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel) end
        ns.Win.Open()
    end)
    y = y - 44

    local function Section(text)
        local h = UI.Title(page, 14)
        h:SetPoint("TOPLEFT", 18, y)
        h:SetText(text)
        y = y - 26
    end
    local function Check(key, label, tip)
        NL.OptionCheck(page, 22, y, db, key, label, tip, function() L.Changed() end)
        y = y - 26
    end

    Section("Pop-ups")
    local alerts = ns.BuildAlerts(page, function()
        -- the dungeon list lives in the Dungeon Finder's Pop-ups panel
        if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel) end
        ns.Win.Open(1)
        if ns.Win.ShowAlerts then ns.Win.ShowAlerts() end
    end)
    alerts:SetPoint("TOPLEFT", 22, y)
    y = y - 222

    Section("Chat")
    Check("notifyGroups", "Tell me about new groups that fit me", "While you're listed: a chat line (and a sound) when a group you fit is listed.")
    Check("notifyApplicants", "Tell me when someone asks to join my group", "A chat line and a sound; the minimap button pulses.")
    Check("notifyPlayers", "Tell me about new players that fit my group", "While your group is listed: a chat line when a player who fits it signs up.")
    Check("sound", "Play a sound with notifications")
    y = y - 8

    Section("Listing")
    Check("autoDelistOnJoin", "Take me off the list when I join a group")
    Check("autoDelistWhenFull", "Delist my group when it's full")
    y = y - 8

    local note = UI.Text(page, 11, C.dim)
    note:SetPoint("TOPLEFT", 18, y)
    note:SetWidth(560)
    note:SetWordWrap(true)
    note:SetText("Only members of <Nerdelandslaget> and <Nerdelandslaget II> who have the addon see your listing. "
        .. "The two guilds share a hidden channel for this; it never shows in your chat.\n\n"
        .. "/nl  opens the Dungeon Finder   ·   /nl lfg demo  fills it with made-up listings to try it out")

    ns.optionsCategory = NL.AddOptionsSubpage(page, "Dungeon Finder")
end
