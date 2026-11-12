-- Theme: the suite's colours (taken from the NL emblem and wordmark), media paths, and the
-- role and class icons every module uses.

local ADDON_NAME, ns = ...

local T = {}
ns.Theme = T

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

T.media = {
    emblem = MEDIA .. "emblem.png",
    emblemSmall = MEDIA .. "emblem_64.png",
    -- the wordmark sits in the top-left 800x273 of a 1024x512 texture
    wordmark = { file = MEDIA .. "wordmark.png", w = 800, h = 273, u = 800 / 1024, v = 273 / 512 },
    white = "Interface\\Buttons\\WHITE8X8",
}

-- r, g, b, a
T.c = {
    bg       = { 0.035, 0.105, 0.125, 0.97 },  -- deep teal-navy (the wordmark's shadow)
    bgLight  = { 0.055, 0.180, 0.215, 1 },     -- the emblem's teal disc, darkened
    bgRow    = { 0.070, 0.215, 0.255, 0.55 },
    bgRowHi  = { 0.090, 0.290, 0.340, 0.85 },
    edge     = { 0.788, 0.706, 0.541, 1 },     -- the emblem's tan star
    edgeDim  = { 0.380, 0.360, 0.300, 1 },
    cream    = { 0.965, 0.906, 0.690, 1 },     -- the wordmark's outline
    text     = { 0.910, 0.870, 0.760, 1 },
    dim      = { 0.600, 0.620, 0.580, 1 },
    gold     = { 0.969, 0.757, 0.184, 1 },     -- top of the letters
    orange   = { 0.910, 0.392, 0.169, 1 },     -- bottom of the letters
    green    = { 0.450, 0.820, 0.380, 1 },
    red      = { 0.900, 0.300, 0.250, 1 },
    yellow   = { 1.000, 0.850, 0.250, 1 },
    gray     = { 0.550, 0.550, 0.550, 1 },
}

function T.Hex(c)
    return string.format("ff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

function T.Color(text, c)
    return "|c" .. T.Hex(c) .. tostring(text) .. "|r"
end

T.FONT = (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
T.FONT_HEAD = "Fonts\\FRIZQT__.TTF"

---------------------------------------------------------------------------
-- Roles. Stored and sent as the letters T, H and D.
---------------------------------------------------------------------------

T.ROLES = { "T", "H", "D" }
T.ROLE_NAME = { T = "Tank", H = "Healer", D = "Damage" }
T.ROLE_COLOR = { T = { 0.38, 0.62, 1 }, H = { 0.40, 0.92, 0.45 }, D = { 1, 0.42, 0.32 } }

-- The suite's own role icons (Media/role_*.png, built by tools/build_media.py): 128px for the
-- big toggles, a pre-shrunk 32px copy for the small icons in rows so they stay crisp.
local ROLE_FILE = { T = "tank", H = "healer", D = "damage" }

local function AtlasExists(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- Paints tex as role ("T", "H", "D"); dim = not chosen / not filled; nil role = an empty slot.
function T.SetRole(tex, role, dim)
    if not role or not ROLE_FILE[role] then
        tex:SetTexture(T.media.white)
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetVertexColor(1, 1, 1, 0.08)
        tex:SetDesaturated(false)
        return
    end
    local w = tex:GetWidth() or 0
    local small = w > 0 and w <= 28
    tex:SetTexture(MEDIA .. "role_" .. ROLE_FILE[role] .. (small and "_32" or "") .. ".png")
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetDesaturated(dim and true or false)
    tex:SetVertexColor(1, 1, 1, dim and 0.3 or 1)
end

---------------------------------------------------------------------------
-- Class icons
---------------------------------------------------------------------------

function T.SetClass(tex, classFile)
    if not classFile then tex:Hide() return end
    tex:Show()
    local atlas = "classicon-" .. classFile:lower()
    if AtlasExists(atlas) then
        tex:SetAtlas(atlas)
        return
    end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if coords then
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        tex:Hide()
    end
end
