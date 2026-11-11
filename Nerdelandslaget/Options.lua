-- Options: the suite's page in Options > AddOns, headed by the NERDE-LANDSLAGET wordmark.
-- It lists the modules (each with an Open button) and the suite-wide settings. Modules add
-- their own pages under it with ns.OptionsPage + ns.AddOptionsSubpage.

local ADDON_NAME, ns = ...
local T = ns.Theme
local C = T.c
local UI = ns.UI

local category

-- A blank canvas page with the wordmark across the top. Returns the frame and the y offset
-- (negative) where content can start.
function ns.OptionsPage(subtitle)
    local f = CreateFrame("Frame")
    f:Hide()
    local head = UI.Header(f, 340)
    head:SetPoint("TOPLEFT", 16, -12)
    local y = -12 - head:GetHeight() - 6
    if subtitle then
        local s = UI.Title(f, 16)
        s:SetPoint("TOPLEFT", 18, y)
        s:SetText(subtitle)
        y = y - 26
    end
    return f, y
end

-- A checkbox bound to tbl[key] at (x, y) on page; onChange runs after the value is stored.
function ns.OptionCheck(page, x, y, tbl, key, label, tip, onChange)
    local cb = UI.Check(page, label, function(on)
        tbl[key] = on
        if onChange then onChange(on) end
    end, tip)
    cb:SetPoint("TOPLEFT", x, y)
    page:HookScript("OnShow", function() cb:SetChecked(tbl[key] and true or false) end)
    return cb
end

function ns.AddOptionsSubpage(frame, name)
    if not (category and Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ok, sub = pcall(Settings.RegisterCanvasLayoutSubcategory, category, frame, name)
    if ok then return sub end
    ns.log("options: subpage failed", name, sub)
    return nil
end

function ns.OpenOptions(sub)
    local target = sub or category
    if target and Settings and Settings.OpenToCategory then
        local ok = pcall(Settings.OpenToCategory, target:GetID())
        if ok then return end
    end
    ns.Print("The options page isn't available on this client. Try /nl " .. ((ns.DefaultModule() or {}).key or ""))
end

local function Build()
    local page, y = ns.OptionsPage()

    local blurb = UI.Text(page, 13, C.text)
    blurb:SetPoint("TOPLEFT", 18, y)
    blurb:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    blurb:SetWordWrap(true)
    blurb:SetText("Addons for the Nerdelandslaget podcast community, made for the guilds "
        .. T.Color("<Nerdelandslaget>", C.gold) .. " and " .. T.Color("<Nerdelandslaget II>", C.gold) .. ".")
    y = y - 40

    local guild = UI.Text(page, 12, C.dim)
    guild:SetPoint("TOPLEFT", 18, y)
    y = y - 30

    local head = UI.Title(page, 15)
    head:SetPoint("TOPLEFT", 18, y)
    head:SetText("Modules")
    y = y - 26

    local cards = {}
    local function Cards()
        local cy = y
        for i, m in ipairs(ns.modules) do
            local card = cards[i]
            if not card then
                card = UI.Frame(page, C.bgLight, C.edgeDim)
                card:SetSize(520, 54)
                card.icon = card:CreateTexture(nil, "ARTWORK")
                card.icon:SetSize(38, 38)
                card.icon:SetPoint("LEFT", 8, 0)
                card.title = UI.Text(card, 14, C.cream)
                card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -2)
                card.desc = UI.Text(card, 11, C.dim)
                card.desc:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
                card.desc:SetPoint("RIGHT", card, "RIGHT", -110, 0)
                card.open = UI.Button(card, "Open", 84, 24, "primary")
                card.open:SetPoint("RIGHT", -10, 0)
                cards[i] = card
            end
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", 18, cy)
            card.icon:SetTexture(m.icon or T.media.emblemSmall)
            card.title:SetText(m.title or m.key)
            card.desc:SetText(m.desc or "")
            card.open:SetScript("OnClick", function()
                if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel) end
                ;(m.open or m.toggle)()
            end)
            card:Show()
            cy = cy - 60
        end
        return cy
    end

    local general = UI.Title(page, 15)
    general:SetText("General")
    local mapCheck = UI.Check(page, "Show the minimap button", function(on)
        ns.db.mapButton = on
        ns.MapButton.Refresh()
    end)
    local debugCheck = UI.Check(page, "Keep a debug log (for addon development)", function(on)
        ns.db.debug = on
    end, "Prints the log to chat as well. The log is saved in the SavedVariables file either way.")

    page:SetScript("OnShow", function()
        local g = ns.MyGuildName()
        if ns.GuildIndex(g) then
            guild:SetText("You're in " .. T.Color("<" .. g .. ">", C.gold) .. ". Everything is unlocked.")
        elseif g then
            guild:SetText(T.Color("You're in <" .. g .. ">. ", C.orange)
                .. "The suite only talks to members of the two Nerdelandslaget guilds.")
        else
            guild:SetText(T.Color("You're not in a guild. ", C.orange)
                .. "The suite only talks to members of the two Nerdelandslaget guilds.")
        end
        local gy = Cards() - 14
        general:ClearAllPoints()
        general:SetPoint("TOPLEFT", 18, gy)
        mapCheck:ClearAllPoints()
        mapCheck:SetPoint("TOPLEFT", 20, gy - 28)
        mapCheck:SetChecked(ns.db.mapButton)
        debugCheck:ClearAllPoints()
        debugCheck:SetPoint("TOPLEFT", 20, gy - 54)
        debugCheck:SetChecked(ns.db.debug)
    end)

    local ver = UI.Text(page, 10, C.dim, "RIGHT")
    ver:SetPoint("BOTTOMRIGHT", -16, 12)
    ver:SetText("v" .. ns.VERSION)

    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        ns.log("options: no Settings canvas API")
        return
    end
    category = Settings.RegisterCanvasLayoutCategory(page, "Nerdelandslaget")
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
end

-- Modules load after the core, so pages are built at login, when every module is in.
table.insert(ns.startup, 1, function()
    local ok, err = pcall(Build)
    if not ok then ns.log("options: build failed", err) return end
    for _, m in ipairs(ns.modules) do
        if m.options then
            local ok2, err2 = pcall(m.options)
            if not ok2 then ns.log("options: module page failed", m.key, err2) end
        end
    end
end)
