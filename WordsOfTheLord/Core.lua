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
    schema = 2,
    channel = "SAY",
    lang = "en",
    favorites = {},
    excluded = {},
    categories = {},
    favoriteWeight = 3,
    quebecShare = 70,
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

-- Settings go back to defaults; the player's own sayings, favorites and exclusions stay.
function ns.ResetSettings()
    local custom, favorites, excluded = ns.db.custom, ns.db.favorites, ns.db.excluded
    wipe(ns.db)
    copyDefaults(defaults, ns.db)
    ns.db.custom, ns.db.favorites, ns.db.excluded = custom, favorites, excluded
end

-- Bring saved settings from older versions up to date. Returns true if the language changed.
local function migrate(db)
    local changed = false
    if (db.schema or 1) < 2 then
        -- 0.1.0 saved lang = "auto" (follow the game client). The default is English now.
        if db.lang == "auto" then
            db.lang = "en"
            changed = true
        end
        db.schema = 2
    end
    if db.lang ~= "en" and db.lang ~= "fr" and db.lang ~= "qc" then
        db.lang = "en"
    end
    return changed
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

-- The text and reference an entry shows in the current language, or nil if it has none.
-- English mode uses the English text; French and Québec modes use the French text.
-- "quebec" entries only exist in Québec mode.
function ns.EntryText(entry, lang)
    lang = lang or ns.GetLang()
    if entry.cat == "quebec" and lang ~= "qc" then
        return nil
    end
    if lang == "en" then
        return entry.en, entry.enRef
    end
    return entry.fr, entry.frRef
end

function ns.CategoryEnabled(cat)
    return ns.db.categories[cat] ~= false
end

function ns.IsFavorite(id)
    return ns.db.favorites[id] == true
end

function ns.IsExcluded(id)
    return ns.db.excluded[id] == true
end

-- A shown entry: { id, text, ref, favorite, excluded, cat }.
local function makeShown(entry, lang)
    local text, ref = ns.EntryText(entry, lang)
    if not text then
        return nil
    end
    return {
        id = entry.id, cat = entry.cat, text = text, ref = ref,
        favorite = ns.IsFavorite(entry.id), excluded = ns.IsExcluded(entry.id),
    }
end

-- Everything available in the current language, in library order, whatever the
-- player's filters say. The library window lists this.
function ns.GetLibrary()
    local lang, list = ns.GetLang(), {}
    for _, entry in ipairs(ns.sayings) do
        local shown = makeShown(entry, lang)
        if shown then
            list[#list + 1] = shown
        end
    end
    return list
end

-- What may actually be preached right now: built-ins (if on) that are in an enabled
-- category and not excluded, plus the player's own sayings.
function ns.GetPool()
    local pool = {}
    if ns.db.useBuiltin then
        for _, shown in ipairs(ns.GetLibrary()) do
            if not shown.excluded and ns.CategoryEnabled(shown.cat) then
                pool[#pool + 1] = shown
            end
        end
    end
    for i, text in ipairs(ns.db.custom) do
        pool[#pool + 1] = { id = "custom:" .. i, cat = "custom", text = text, favorite = false, excluded = false }
    end
    return pool
end

function ns.FavoriteWeight()
    return math.min(5, math.max(1, math.floor(tonumber(ns.db.favoriteWeight) or 3)))
end

-- The last few picks are set aside so the same saying never comes back right away.
local recent = {}

function ns.ResetBag()
    recent = {}
end

-- How many recent picks are set aside: up to 8, at least 1 when there are two or more
-- sayings (so two sayings alternate), and 0 when there is only one.
local function recentWindow(poolSize)
    if poolSize < 2 then
        return 0
    end
    return math.max(1, math.min(8, math.floor(poolSize / 3)))
end

function ns.QuebecShare()
    return math.min(100, math.max(0, math.floor(tonumber(ns.db.quebecShare) or 70)))
end

-- Weighted pick inside one group of sayings: favorites count `favoriteWeight` times,
-- everything else once, skipping the recent picks.
local function pickFrom(group)
    local window = recentWindow(#group)
    local blocked = {}
    for i = math.max(1, #recent - window + 1), #recent do
        blocked[recent[i]] = true
    end

    local weight, candidates, total = ns.FavoriteWeight(), {}, 0
    for _, shown in ipairs(group) do
        if not blocked[shown.id] then
            local w = shown.favorite and weight or 1
            candidates[#candidates + 1] = { shown = shown, w = w }
            total = total + w
        end
    end

    local roll, chosen = math.random() * total, candidates[#candidates].shown
    for _, candidate in ipairs(candidates) do
        roll = roll - candidate.w
        if roll < 0 then
            chosen = candidate.shown
            break
        end
    end
    return chosen
end

-- In Québec mode the pool has two groups: the Québec sayings, and everything else
-- (French verses and the player's own sayings). Each pick goes to the Québec group
-- `quebecShare` percent of the time. If one group is empty the other is used.
-- In English and French mode there is only one group.
function ns.NextSaying()
    local pool = ns.GetPool()
    if #pool == 0 then
        return nil
    end

    local group = pool
    if ns.GetLang() == "qc" then
        local quebec, other = {}, {}
        for _, shown in ipairs(pool) do
            if shown.cat == "quebec" then
                quebec[#quebec + 1] = shown
            else
                other[#other + 1] = shown
            end
        end
        if #quebec > 0 and #other > 0 then
            group = (math.random() * 100 < ns.QuebecShare()) and quebec or other
        elseif #quebec > 0 then
            group = quebec
        else
            group = other
        end
    end

    local chosen = pickFrom(group)
    recent[#recent + 1] = chosen.id
    return chosen
end

-- "« text » — ref" in French and Québec modes, "text" — ref in English.
function ns.FormatSaying(shown)
    local quoted
    if ns.UILang() == "fr" then
        quoted = "« " .. shown.text .. " »"
    else
        quoted = "\"" .. shown.text .. "\""
    end
    if shown.ref and shown.ref ~= "" then
        quoted = quoted .. " — " .. shown.ref
    end
    return ns.Sanitize(quoted)
end

function ns.FindSayingById(id)
    local entry = ns.sayingsById[id]
    return entry and makeShown(entry, ns.GetLang())
end

-- Match a reference typed by the player ("Jean 3:16", "john 3:16") to a saying in the
-- current language. Accents and case are ignored.
local function foldRef(text)
    text = (text or ""):lower():gsub("%s+", " ")
    for from, to in pairs({ ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ï"] = "i", ["à"] = "a",
                          ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ï"] = "i", ["À"] = "a" }) do
        text = text:gsub(from, to)
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function ns.FindSayingByRef(ref)
    local wanted = foldRef(ref)
    if wanted == "" then
        return nil
    end
    for _, shown in ipairs(ns.GetLibrary()) do
        if shown.ref and foldRef(shown.ref) == wanted then
            return shown
        end
    end
end

-- Toggles used by commands now and by the library window later.
function ns.ToggleFavorite(id)
    if ns.db.favorites[id] then
        ns.db.favorites[id] = nil
        return false
    end
    ns.db.favorites[id] = true
    ns.db.excluded[id] = nil   -- a favorite can't also be excluded
    return true
end

function ns.ToggleExcluded(id)
    if ns.db.excluded[id] then
        ns.db.excluded[id] = nil
        return false
    end
    ns.db.excluded[id] = true
    ns.db.favorites[id] = nil
    return true
end

function ns.SetCategory(cat, enabled)
    ns.db.categories[cat] = enabled and true or false
end

-- Category key from a typed name (French or English, accents ignored), or nil.
function ns.FindCategory(word)
    word = foldRef(word)
    for _, category in ipairs(ns.CATEGORIES) do
        if word == category.key or word == foldRef(category.en) or word == foldRef(category.fr) then
            return category
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
    local entry = ns.FindSayingById(ns.reactionIds[kind])
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
        local saved = WordsOfTheLordDB
        -- Settings saved under the addon's former name ("La parole du seigneur") are moved
        -- over once, then the old variable is cleared so it is never read again.
        if saved == nil and LaParoleDuSeigneurDB ~= nil then
            saved = LaParoleDuSeigneurDB
        end
        LaParoleDuSeigneurDB = nil
        local isUpgrade = saved ~= nil and (saved.schema or 1) < 2
        if saved then
            -- Run the migration on the raw saved data first, so "auto" is seen before defaults fill in.
            migrate(saved)
        end
        WordsOfTheLordDB = copyDefaults(defaults, saved or {})
        ns.db = WordsOfTheLordDB
        ns.upgradedFromV1 = isUpgrade
        frame:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        ns.CreateButton()
        ns.UpdateAutoPreach()
        local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        ns.Print(L.LOADED:format(getMeta(addonName, "Version") or "?"))
        if ns.upgradedFromV1 then
            ns.upgradedFromV1 = nil
            ns.Print(L.LANG_MIGRATED)
        end

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

function WordsOfTheLord_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then
        ns.CycleChannel()
    else
        ns.Preach()
    end
end

function WordsOfTheLord_OnAddonCompartmentEnter(_, menuButton)
    ns.ShowTooltip(menuButton)
end

function WordsOfTheLord_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
