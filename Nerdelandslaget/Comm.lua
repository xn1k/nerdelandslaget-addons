-- Comm: addon messages between suite users in <Nerdelandslaget> and <Nerdelandslaget II>.
--
-- GUILD addon messages only reach your own guild, so the two guilds share a hidden chat
-- channel (addon messages only; it never shows in chat). If the channel can't be joined
-- (the 10-channel cap, say), broadcasts fall back to GUILD, which reaches at least your
-- own guild.
--
--   Comm.Register(prefix, fn(text, sender, via))   via: "CHANNEL", "GUILD", "WHISPER", "PARTY"
--   Comm.Broadcast(prefix, text, key)  to both guilds; a newer message with the same key
--                                      replaces one still waiting in the queue
--   Comm.Whisper(prefix, text, target)
--   Comm.Party(prefix, text, key)
--
-- Messages go out through a small token bucket (the game throttles each prefix) and wait
-- out chat lockdowns. Nothing here is verified: a message says what its sender says.

local ADDON_NAME, ns = ...

local Comm = {}
ns.Comm = Comm

local CHANNEL = "NerdelandslagetAddon"
Comm.CHANNEL = CHANNEL

local BURST, REFILL = 6, 1.2     -- messages at once, seconds per new one
local MAX_QUEUE = 60

local IsSecret = ns.IsSecret
local handlers = {}
local queue = {}
local tokens = BURST
local lastRefill = 0

function Comm.Register(prefix, fn)
    assert(#prefix <= 16, "addon prefix too long")
    handlers[prefix] = fn
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix)
    end
end

---------------------------------------------------------------------------
-- The channel
---------------------------------------------------------------------------

function Comm.ChannelID()
    local id = GetChannelName and GetChannelName(CHANNEL)
    if type(id) ~= "number" or IsSecret(id) or id <= 0 then return nil end
    return id
end

function Comm.Join()
    if Comm.ChannelID() then return true end
    local join = JoinTemporaryChannel or JoinChannelByName
    if not join then
        ns.log("comm: no way to join a channel on this client")
        return false
    end
    local ok, err = pcall(join, CHANNEL)
    if not ok then ns.log("comm: joining the channel failed:", err) end
    return ok
end

-- "NerdelandslagetAddon", "6. NerdelandslagetAddon" or "NerdelandslagetAddon - ..."
local function IsOurs(name)
    if type(name) ~= "string" or IsSecret(name) then return false end
    local base = name:gsub("^%d+%.%s*", "")
    base = base:match("^(.-) %- ") or base
    return base:lower() == CHANNEL:lower()
end

-- Keep the channel out of every chat window: its join notices and any stray lines.
local function Filter(_, _, _, _, _, channelString, _, _, _, _, channelBase)
    return IsOurs(channelString) or IsOurs(channelBase)
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function Enqueue(m)
    if m.key then
        for i, q in ipairs(queue) do
            if q.key == m.key then
                queue[i] = m
                return
            end
        end
    end
    if #queue >= MAX_QUEUE then table.remove(queue, 1) end
    queue[#queue + 1] = m
end

local function SendOne(m)
    local dist, target = m.dist, m.target
    if dist == "BROADCAST" then
        local id = Comm.ChannelID()
        if id then
            dist, target = "CHANNEL", id
        elseif IsInGuild() then
            dist, target = "GUILD", nil
        else
            return true                       -- nowhere to send it: drop
        end
    elseif dist == "PARTY" then
        if not IsInGroup() then return true end
        if IsInRaid() then dist = "RAID" end
    end
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, m.prefix, m.text, dist, target)
    if not ok then
        ns.log("comm: send failed", m.prefix, dist, res)
        return true                           -- a bad message: don't retry forever
    end
    local R = Enum and Enum.SendAddonMessageResult
    if R and res ~= nil and res ~= R.Success then
        if res == R.AddonMessageThrottle or res == R.ChannelThrottle then
            return false                      -- try again later
        end
        ns.log("comm: send result", res, m.prefix, dist)
    end
    return true
end

local function Flush()
    local now = GetTime()
    tokens = math.min(BURST, tokens + (now - lastRefill) / REFILL)
    lastRefill = now
    if #queue == 0 then return end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
    while #queue > 0 and tokens >= 1 do
        local m = queue[1]
        if SendOne(m) then
            table.remove(queue, 1)
            tokens = tokens - 1
        else
            tokens = 0
            break
        end
    end
end

-- Messages are ';'-separated fields; keep each under 250 bytes.
function Comm.Broadcast(prefix, text, key)
    Enqueue({ prefix = prefix, text = text, dist = "BROADCAST", key = key and (prefix .. key) })
end

function Comm.Whisper(prefix, text, target)
    Enqueue({ prefix = prefix, text = text, dist = "WHISPER", target = target })
end

function Comm.Party(prefix, text, key)
    Enqueue({ prefix = prefix, text = text, dist = "PARTY", key = key and (prefix .. "P" .. key) })
end

-- Makes free text safe to put in a field: no separators, escapes or line breaks.
function Comm.Clean(text, max)
    if type(text) ~= "string" then return "" end
    text = text:gsub("[;|\r\n\t]", " "):gsub("%s+", " ")
    text = strtrim(text)
    if max and #text > max then text = text:sub(1, max) end
    return text
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

ns.On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    if IsSecret(prefix) or IsSecret(text) or IsSecret(channel) or IsSecret(sender) then return end
    local fn = handlers[prefix]
    if not fn or type(text) ~= "string" then return end
    local from = ns.Full(sender)
    if not from or from == ns.Me() then return end
    local via = channel
    if via == "RAID" or via == "INSTANCE_CHAT" then via = "PARTY" end
    local ok, err = pcall(fn, text, from, via)
    if not ok then ns.log("comm: handler error", prefix, err) end
end)

---------------------------------------------------------------------------
-- Start: join a while after logging in, once General and Trade have their numbers,
-- so ours never takes one of theirs.
---------------------------------------------------------------------------

Comm.ready = false
Comm.onReady = {}

function Comm.WhenReady(fn)
    if Comm.ready then fn() else Comm.onReady[#Comm.onReady + 1] = fn end
end

table.insert(ns.startup, function()
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if add then
        for _, ev in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER",
            "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
            pcall(add, ev, Filter)
        end
    end
    lastRefill = GetTime()
    C_Timer.NewTicker(0.3, Flush)
end)

local joinedOnce = false
ns.On("PLAYER_ENTERING_WORLD", function()
    if joinedOnce then return end
    joinedOnce = true
    C_Timer.After(8, function()
        Comm.Join()
        -- give the server a moment to put us in the channel, then let modules talk
        C_Timer.After(2, function()
            ns.log("comm: ready, channel", Comm.ChannelID(), "guild", ns.MyGuildName())
            Comm.ready = true
            for _, fn in ipairs(Comm.onReady) do pcall(fn) end
            wipe(Comm.onReady)
        end)
    end)
end)

-- Rejoin if something (a chat addon, a /leave) dropped us.
ns.On("CHANNEL_UI_UPDATE", function()
    if Comm.ready and not Comm.ChannelID() then
        C_Timer.After(5, function()
            if not Comm.ChannelID() then Comm.Join() end
        end)
    end
end)
