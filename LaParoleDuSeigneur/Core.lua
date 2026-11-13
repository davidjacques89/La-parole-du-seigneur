-- Core: saved settings, choosing a saying, sending it to chat, auto-preach and reactions.
local addonName, ns = ...
local L = ns.L

local MAX_CHAT_BYTES = 255   -- WoW's limit for one chat message (in bytes, accents count double)
ns.AUTO_MIN_MINUTES = 2      -- floor for auto-preach, to stay well clear of spam

-- Channels the player can pick. "GROUP" resolves to instance, raid or party chat.
ns.CHANNEL_ORDER = { "SAY", "YELL", "EMOTE", "GROUP", "RAID", "GUILD", "SELF" }

-- Outside instances, Blizzard only lets these go out on a click or typed command.
local NEEDS_HARDWARE_EVENT = { SAY = true, YELL = true, EMOTE = true }

local defaults = {
    channel = "SAY",
    lang = "auto",
    useBuiltin = true,
    custom = {},
    autoEnabled = false,
    autoMinutes = 10,
    autoChannel = "GUILD",
    reactions = false,
    button = { shown = true, locked = false, point = "CENTER", relPoint = "CENTER", x = 0, y = -180 },
}

local function copyDefaults(src, dst)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            copyDefaults(value, dst[key])
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
    return dst
end
ns.copyDefaults = copyDefaults

function ns.ResetSettings()
    local custom = ns.db.custom
    wipe(ns.db)
    copyDefaults(defaults, ns.db)
    ns.db.custom = custom
end

---------------------------------------------------------------------------
-- Output helpers
---------------------------------------------------------------------------

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(L.PREFIX .. " " .. tostring(msg))
end

-- Chat API moved into C_ChatInfo in the modern client; keep the old global as fallback.
local function sendChat(msg, chatType)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    send(msg, chatType)
end

-- "|" starts an escape code in WoW chat and breaks the message; line breaks are not allowed.
function ns.Sanitize(text)
    text = tostring(text or "")
    text = text:gsub("|", "/"):gsub("[\r\n]+", " "):gsub("%s+", " ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Cut a byte string at most `limit` bytes long without splitting a UTF-8 character.
local function utf8Cut(text, limit)
    if #text <= limit then
        return text, ""
    end
    local cut = limit
    -- Bytes 0x80-0xBF are continuation bytes: back up until we are on a character start.
    while cut > 0 and text:byte(cut + 1) and text:byte(cut + 1) >= 0x80 and text:byte(cut + 1) < 0xC0 do
        cut = cut - 1
    end
    return text:sub(1, cut), text:sub(cut + 1)
end

-- Split a message into chunks that each fit in one chat line, breaking between words.
function ns.SplitMessage(text, limit)
    limit = limit or MAX_CHAT_BYTES
    local chunks, current = {}, ""
    for word in text:gmatch("%S+") do
        while #word > limit do  -- a single enormous "word": hard cut it
            if current ~= "" then
                chunks[#chunks + 1] = current
                current = ""
            end
            local head, rest = utf8Cut(word, limit)
            chunks[#chunks + 1] = head
            word = rest
        end
        if current == "" then
            current = word
        elseif #current + 1 + #word <= limit then
            current = current .. " " .. word
        else
            chunks[#chunks + 1] = current
            current = word
        end
    end
    if current ~= "" then
        chunks[#chunks + 1] = current
    end
    return chunks
end

---------------------------------------------------------------------------
-- Sayings
---------------------------------------------------------------------------

function ns.FormatSaying(entry)
    local text, ref = entry[1], entry[2]
    local quoted
    if ns.GetLang() == "fr" then
        quoted = "« " .. text .. " »"
    else
        quoted = "\"" .. text .. "\""
    end
    if ref and ref ~= "" then
        quoted = quoted .. " — " .. ref
    end
    return ns.Sanitize(quoted)
end

-- Everything the addon may preach right now: built-ins (if on) plus the player's own.
function ns.GetPool()
    local pool = {}
    if ns.db.useBuiltin then
        for _, entry in ipairs(ns.sayings[ns.GetLang()] or {}) do
            pool[#pool + 1] = entry
        end
    end
    for _, text in ipairs(ns.db.custom) do
        pool[#pool + 1] = { text }
    end
    return pool
end

-- Shuffle bag: every saying comes up once before any repeats.
local bag, bagSignature, lastIndex = {}, nil, nil

local function poolSignature(pool)
    return ns.GetLang() .. ":" .. #pool .. ":" .. tostring(ns.db.useBuiltin) .. ":" .. #ns.db.custom
end

function ns.ResetBag()
    bag, bagSignature, lastIndex = {}, nil, nil
end

function ns.NextSaying()
    local pool = ns.GetPool()
    if #pool == 0 then
        return nil
    end
    local signature = poolSignature(pool)
    if signature ~= bagSignature or #bag == 0 then
        bagSignature = signature
        bag = {}
        for i = 1, #pool do
            bag[i] = i
        end
        for i = #bag, 2, -1 do
            local j = math.random(i)
            bag[i], bag[j] = bag[j], bag[i]
        end
        -- Don't open the new round with the saying that closed the last one.
        if #bag > 1 and bag[#bag] == lastIndex then
            bag[#bag], bag[1] = bag[1], bag[#bag]
        end
    end
    local index = table.remove(bag)
    lastIndex = index
    return pool[index]
end

function ns.FindSayingByRef(ref)
    for _, entry in ipairs(ns.sayings[ns.GetLang()] or {}) do
        if entry[2] == ref then
            return entry
        end
    end
end

---------------------------------------------------------------------------
-- Preaching
---------------------------------------------------------------------------

-- Turn a channel choice into a real chat type, or nil plus a reason to print instead.
function ns.ResolveChannel(channel)
    if channel == "SELF" then
        return nil
    elseif channel == "GUILD" then
        if IsInGuild() then return "GUILD" end
        return nil, L.NOT_IN_GUILD
    elseif channel == "RAID" then
        if IsInRaid() then return "RAID" end
        channel = "GROUP"
    end
    if channel == "GROUP" then
        if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            return "INSTANCE_CHAT"
        elseif IsInRaid() then
            return "RAID"
        elseif IsInGroup() then
            return "PARTY"
        end
        return nil, L.NOT_IN_GROUP
    end
    return channel
end

-- Preach one saying (or a given entry). `automatic` is true for the timer and reactions,
-- which have no click behind them and so cannot use say, yell or emote outdoors.
function ns.Preach(channel, entry, automatic)
    entry = entry or ns.NextSaying()
    if not entry then
        ns.Print(L.NO_SAYINGS)
        return
    end
    local message = ns.FormatSaying(entry)
    channel = channel or ns.db.channel

    if automatic and NEEDS_HARDWARE_EVENT[channel] then
        local inInstance = IsInInstance()
        if not inInstance then
            ns.Print(L.NEEDS_CLICK:format(ns.ChannelLabel(channel)))
            ns.Print(message)
            return
        end
    end

    local chatType, reason = ns.ResolveChannel(channel)
    if not chatType then
        if reason then ns.Print(reason) end
        ns.Print(message)
        return
    end

    for _, chunk in ipairs(ns.SplitMessage(message)) do
        sendChat(chunk, chatType)
    end
end

function ns.ChannelLabel(channel)
    return L.CHANNELS[channel] or channel
end

-- Map a typed word (French or English) to a channel key.
local channelAliases = {
    dire = "SAY", say = "SAY", s = "SAY",
    crier = "YELL", yell = "YELL", y = "YELL",
    emote = "EMOTE", e = "EMOTE", me = "EMOTE",
    groupe = "GROUP", group = "GROUP", party = "GROUP", p = "GROUP", instance = "GROUP", i = "GROUP",
    raid = "RAID", r = "RAID",
    guilde = "GUILD", guild = "GUILD", g = "GUILD",
    moi = "SELF", self = "SELF",
}
function ns.ParseChannel(word)
    return word and channelAliases[word:lower()]
end

---------------------------------------------------------------------------
-- Auto-preach
---------------------------------------------------------------------------

local ticker

function ns.UpdateAutoPreach()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if not ns.db.autoEnabled then
        return
    end
    local minutes = math.max(ns.AUTO_MIN_MINUTES, tonumber(ns.db.autoMinutes) or 10)
    ns.db.autoMinutes = minutes
    ticker = C_Timer.NewTicker(minutes * 60, function()
        if InCombatLockdown() then
            return  -- quietly skip this round; the next tick will try again
        end
        ns.Preach(ns.db.autoChannel, nil, true)
    end)
end

---------------------------------------------------------------------------
-- Reactions (death and resurrection)
---------------------------------------------------------------------------

local wasDead = false

local function react(kind)
    if not ns.db.reactions or not IsInGroup() then
        return
    end
    local ref = ns.reactionRefs[kind][ns.GetLang()]
    local entry = ns.FindSayingByRef(ref)
    if entry then
        ns.Preach("GROUP", entry, true)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
ns.eventFrame = frame

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        LaParoleDuSeigneurDB = copyDefaults(defaults, LaParoleDuSeigneurDB or {})
        ns.db = LaParoleDuSeigneurDB
        frame:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        ns.CreateButton()
        ns.UpdateAutoPreach()
        local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        ns.Print(L.LOADED:format(getMeta(addonName, "Version") or "?"))

    elseif event == "PLAYER_DEAD" then
        wasDead = true
        react("death")

    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        -- PLAYER_ALIVE also fires when releasing to a ghost, so check we are truly back.
        if wasDead and not UnitIsDeadOrGhost("player") then
            wasDead = false
            react("revive")
        end
    end
end)

---------------------------------------------------------------------------
-- Addon compartment (the addon list button by the minimap)
---------------------------------------------------------------------------

function LaParoleDuSeigneur_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then
        ns.CycleChannel()
    else
        ns.Preach()
    end
end

function LaParoleDuSeigneur_OnAddonCompartmentEnter(_, menuButton)
    ns.ShowTooltip(menuButton)
end

function LaParoleDuSeigneur_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
