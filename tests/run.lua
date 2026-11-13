-- Offline test harness: stubs the parts of the WoW API the addon uses, loads the addon
-- files in TOC order, and exercises commands. Run from the repo root:  lua5.1 tests/run.lua
local ADDON = "LaParoleDuSeigneur"
local DIR = ADDON .. "/"

---------------------------------------------------------------------------
-- Fake game state and API
---------------------------------------------------------------------------
local state = {
    locale = "frFR",  -- a French client: the addon must still start in English
    inGuild = true, inGroup = false, inRaid = false, inInstanceGroup = false,
    inInstance = false, combat = false, dead = false,
}
local sent, printed, tickers = {}, {}, {}

function GetLocale() return state.locale end
function IsInGuild() return state.inGuild end
function IsInRaid() return state.inRaid end
function IsInGroup(category)
    if category == LE_PARTY_CATEGORY_INSTANCE then return state.inInstanceGroup end
    return state.inGroup or state.inRaid
end
LE_PARTY_CATEGORY_INSTANCE = 2
function IsInInstance() return state.inInstance end
function InCombatLockdown() return state.combat end
function UnitIsDeadOrGhost() return state.dead end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

C_ChatInfo = {
    SendChatMessage = function(msg, chatType)
        assert(#msg <= 255, "message over 255 bytes: " .. #msg)
        assert(not msg:find("|", 1, true), "pipe character in chat message")
        sent[#sent + 1] = { msg = msg, chatType = chatType }
    end,
}
C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "0.2.0" or nil end }
C_Timer = {
    NewTicker = function(seconds, fn)
        local t = { seconds = seconds, fn = fn, cancelled = false }
        function t:Cancel() self.cancelled = true end
        tickers[#tickers + 1] = t
        return t
    end,
}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) printed[#printed + 1] = msg end }

-- Minimal frame object: records scripts and points, ignores the rest.
local function newFrame()
    local f = { scripts = {}, events = {}, shown = true, points = {} }
    setmetatable(f, { __index = function() return function() end end })
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetShown(v) self.shown = v and true or false end
    function f:SetPoint(...) self.points = { ... } end
    function f:GetPoint() local p = self.points return p[1], p[2], p[3], p[4], p[5] end
    function f:CreateTexture() return newFrame() end
    return f
end
local frames = {}
function CreateFrame() local f = newFrame() frames[#frames + 1] = f return f end
UIParent = newFrame()
GameTooltip = newFrame()
function GameTooltip:GetOwner() return nil end
SlashCmdList = {}

---------------------------------------------------------------------------
-- Load the addon like the client does
---------------------------------------------------------------------------
local ns = {}
local function loadToc()
    local files = {}
    for line in io.lines(DIR .. ADDON .. ".toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end
for _, file in ipairs(loadToc()) do
    local chunk = assert(loadfile(DIR .. file))
    chunk(ADDON, ns)
end

local function fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
local slash = SlashCmdList.LAPAROLEDUSEIGNEUR

---------------------------------------------------------------------------
-- Tiny test runner
---------------------------------------------------------------------------
local passed, failed = 0, 0
local function test(name, fn)
    sent, printed = {}, {}
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 print("FAIL  " .. name .. "\n      " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function printedContains(s)
    for _, m in ipairs(printed) do if m:find(s, 1, true) then return true end end
    return false
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- First login on a fresh install (no saved variables), on a French client.
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
local freshPrinted = printed

---------------------------------------------------------------------------
-- Fresh install and defaults
---------------------------------------------------------------------------
test("fresh install: globals, slash commands, English default even on a French client", function()
    eq(type(slash), "function")
    eq(SLASH_LAPAROLEDUSEIGNEUR1, "/parole")
    eq(type(LaParoleDuSeigneurDB), "table")
    eq(LaParoleDuSeigneurDB.lang, "en")
    eq(LaParoleDuSeigneurDB.channel, "SAY")
    eq(LaParoleDuSeigneurDB.favoriteWeight, 3)
    eq(ns.GetLang(), "en")
    eq(ns.UILang(), "en")
end)

test("first preach on a fresh install is English with straight quotes", function()
    slash("")
    eq(#sent, 1)
    eq(sent[1].chatType, "SAY")
    assert(sent[1].msg:find('^"') and sent[1].msg:find(" — %S+ %d+:%d+$"), sent[1].msg)
    assert(not sent[1].msg:find("«"))
end)

test("fresh install prints no upgrade notice", function()
    for _, m in ipairs(freshPrinted) do assert(not m:find("Default language"), m) end
end)

---------------------------------------------------------------------------
-- Library, languages and data integrity
---------------------------------------------------------------------------
test("library size is about 100 and ids are unique and well formed", function()
    assert(#ns.sayings >= 95 and #ns.sayings <= 110, "got " .. #ns.sayings)
    local seen = {}
    local cats = {}
    for _, c in ipairs(ns.CATEGORIES) do cats[c.key] = true end
    for _, e in ipairs(ns.sayings) do
        assert(not seen[e.id], "dup " .. e.id)
        seen[e.id] = true
        assert(cats[e.cat], "unknown category " .. tostring(e.cat) .. " in " .. e.id)
        assert(e.fr and e.fr ~= "" and e.frRef and e.frRef ~= "", "missing French in " .. e.id)
        if e.cat ~= "quebec" then
            assert(e.en and e.en ~= "" and e.enRef and e.enRef ~= "", "missing English in " .. e.id)
        end
        for _, field in ipairs({ "fr", "en", "frRef", "enRef" }) do
            local v = e[field]
            if v then
                assert(not v:find("|", 1, true), e.id .. "." .. field .. " has a pipe")
                assert(not v:find("[\r\n]"), e.id .. "." .. field .. " has a line break")
                assert(#v < 250, e.id .. "." .. field .. " is too long")
            end
        end
    end
end)

test("English mode: English text only, no Québec sayings", function()
    LaParoleDuSeigneurDB.lang = "en"
    local lib = ns.GetLibrary()
    for _, s in ipairs(lib) do assert(s.cat ~= "quebec", s.id) end
    local jn = ns.FindSayingById("jn3_16")
    assert(jn.text:find("^For God so loved"), jn.text)
    eq(jn.ref, "John 3:16")
end)

test("French mode: French Bible only, no Québec sayings", function()
    slash("langue fr")
    eq(ns.GetLang(), "fr")
    for _, s in ipairs(ns.GetLibrary()) do
        assert(s.cat ~= "quebec", s.id)
    end
    local jn = ns.FindSayingById("jn3_16")
    assert(jn.text:find("^Car Dieu a tant aimé"), jn.text)
    eq(jn.ref, "Jean 3:16")
    eq(ns.UILang(), "fr")
end)

test("Québec mode: full French library plus the Québec sayings", function()
    local frCount = #ns.GetLibrary()
    slash("langue qc")
    eq(ns.GetLang(), "qc")
    eq(ns.UILang(), "fr", "Québec mode uses French interface text")
    local lib = ns.GetLibrary()
    local quebec = 0
    for _, s in ipairs(lib) do if s.cat == "quebec" then quebec = quebec + 1 end end
    assert(quebec >= 20, "expected 20+ Québec sayings, got " .. quebec)
    eq(#lib, frCount + quebec, "Québec mode = French library + Québec sayings")
    -- every French saying is still there
    local ids = {}
    for _, s in ipairs(lib) do ids[s.id] = true end
    assert(ids.jn3_16 and ids.ps23_1 and ids.qc_aide_toi)
    -- and Québec sayings carry a label as reference
    local q = ns.FindSayingById("qc_marie")
    assert(q.text:find("Sainte Marie"), q.text)
    eq(q.ref, "Prière traditionnelle")
end)

test("Québec sayings are preachable in Québec mode and absent from the other modes", function()
    LaParoleDuSeigneurDB.lang = "qc"
    ns.ResetBag()
    local sawQuebec = false
    for _ = 1, 400 do
        local s = ns.NextSaying()
        if s.cat == "quebec" then sawQuebec = true break end
    end
    assert(sawQuebec, "no Québec saying picked in 400 tries")
    for _, mode in ipairs({ "en", "fr" }) do
        LaParoleDuSeigneurDB.lang = mode
        ns.ResetBag()
        for _ = 1, 300 do assert(ns.NextSaying().cat ~= "quebec") end
    end
    LaParoleDuSeigneurDB.lang = "en"
end)

test("French and Québec output uses guillemets", function()
    slash("langue fr")
    slash("")
    assert(sent[#sent].msg:find("^« ") and sent[#sent].msg:find(" »"), sent[#sent].msg)
    slash("lang en")
end)

test("lang command: names in several spellings, bare command steps through modes", function()
    slash("lang english") eq(ns.GetLang(), "en")
    slash("langue Français") eq(ns.GetLang(), "fr")
    slash("lang québec") eq(ns.GetLang(), "qc")
    slash("lang quebec") eq(ns.GetLang(), "qc")
    slash("lang") eq(ns.GetLang(), "en")
    slash("lang") eq(ns.GetLang(), "fr")
    slash("lang") eq(ns.GetLang(), "qc")
    slash("lang en")
end)

---------------------------------------------------------------------------
-- Migration from 0.1.0
---------------------------------------------------------------------------
test("upgrade from 0.1.0: auto language becomes English, own data kept, notice shown once", function()
    local kept = { "Pour la Horde", "Que la Lumière nous guide" }
    LaParoleDuSeigneurDB = {
        channel = "GUILD", lang = "auto", useBuiltin = false, custom = { kept[1], kept[2] },
        autoEnabled = true, autoMinutes = 15, autoChannel = "GROUP", reactions = true,
        button = { shown = false, locked = true, point = "TOP", relPoint = "TOP", x = 5, y = 6 },
    }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    local db = LaParoleDuSeigneurDB
    eq(ns.db, db)
    eq(db.lang, "en", "auto -> en")
    eq(db.schema, 2)
    eq(db.channel, "GUILD")
    eq(db.useBuiltin, false)
    eq(#db.custom, 2); eq(db.custom[1], kept[1]); eq(db.custom[2], kept[2])
    eq(db.autoMinutes, 15); eq(db.autoChannel, "GROUP"); eq(db.reactions, true)
    eq(db.button.shown, false); eq(db.button.locked, true); eq(db.button.x, 5)
    eq(type(db.favorites), "table"); eq(type(db.excluded), "table"); eq(type(db.categories), "table")
    eq(db.favoriteWeight, 3)
    printed = {}
    fire("PLAYER_LOGIN")
    assert(printedContains("Default language is now English"), "upgrade notice missing")
    printed = {}
    fire("PLAYER_LOGIN")
    assert(not printedContains("Default language"), "notice repeated")
end)

test("upgrade from 0.1.0: an explicit French choice is kept", function()
    LaParoleDuSeigneurDB = { lang = "fr", custom = {} }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    eq(LaParoleDuSeigneurDB.lang, "fr")
    eq(LaParoleDuSeigneurDB.schema, 2)
end)

test("garbage saved language falls back to English", function()
    LaParoleDuSeigneurDB = { lang = "klingon", schema = 2 }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    eq(LaParoleDuSeigneurDB.lang, "en")
end)

-- Back to a clean database for the rest of the run.
LaParoleDuSeigneurDB = nil
ns.eventFrame:RegisterEvent("ADDON_LOADED")
fire("ADDON_LOADED", ADDON)
ns.ResetBag()
LaParoleDuSeigneurDB.lang = "en"

---------------------------------------------------------------------------
-- Picking: favorites, exclusions, categories, repeats
---------------------------------------------------------------------------
test("never the same saying twice in a row, and the recent window is respected", function()
    ns.ResetBag()
    local last
    local window = {}
    for i = 1, 3000 do
        local s = ns.NextSaying()
        assert(s.id ~= last, "immediate repeat of " .. s.id)
        for _, id in ipairs(window) do assert(s.id ~= id, "repeat inside the recent window") end
        window[#window + 1] = s.id
        if #window > 8 then table.remove(window, 1) end
        last = s.id
    end
end)

test("tiny pools still work (1 saying and 2 sayings)", function()
    slash("integrees")  -- built-ins off
    eq(LaParoleDuSeigneurDB.useBuiltin, false)
    slash("add Une seule")
    ns.ResetBag()
    for _ = 1, 5 do eq(ns.NextSaying().text, "Une seule") end
    slash("add Une autre")
    ns.ResetBag()
    local a, b = ns.NextSaying().text, ns.NextSaying().text
    assert(a ~= b, "two-saying pool repeated")
    slash("remove 2") slash("remove 1")
    slash("integrees")
    eq(LaParoleDuSeigneurDB.useBuiltin, true)
end)

test("favorite by reference: toggles, English and French spellings, accents ignored", function()
    slash("fav john 3:16")
    eq(ns.IsFavorite("jn3_16"), true)
    assert(printedContains("Favorite added: John 3:16"))
    slash("fav John 3:16")
    eq(ns.IsFavorite("jn3_16"), false)
    assert(printedContains("Favorite removed"))
    slash("langue fr")
    slash("favori jean 3:16")
    eq(ns.IsFavorite("jn3_16"), true)
    slash("favori esaie 40:31")   -- Ésaïe, typed without accents
    eq(ns.IsFavorite("is40_31"), true)
    slash("favori Ésaïe 40:31")   -- toggles off with the accents
    eq(ns.IsFavorite("is40_31"), false)
    slash("favori jean 3:16")
    eq(ns.IsFavorite("jn3_16"), false)
    slash("favori Nulle part 1:1")
    assert(printedContains("introuvable"))
    slash("lang en")
end)

test("favorites list", function()
    slash("favs")
    assert(printedContains("No favorites yet"))
    slash("fav Psalm 23:1")
    slash("fav John 8:12")
    printed = {}
    slash("favs")
    assert(printedContains("3x more often"))
    assert(printedContains("Psalm 23:1") and printedContains("John 8:12"))
    slash("fav Psalm 23:1") slash("fav John 8:12")
end)

test("favorites are saved by id, so they keep working after switching language", function()
    slash("fav John 14:6")
    slash("lang fr")
    eq(ns.FindSayingById("jn14_6").favorite, true)
    slash("lang qc")
    eq(ns.FindSayingById("jn14_6").favorite, true)
    slash("lang en")
    slash("fav John 14:6")
end)

test("favorites come up more often: weight 5 gives roughly 3x or more, weight 1 is neutral", function()
    math.randomseed(12345)
    local favs = { "jn3_16", "ps23_1", "jn14_6" }
    for _, id in ipairs(favs) do LaParoleDuSeigneurDB.favorites[id] = true end
    local isFav = {}
    for _, id in ipairs(favs) do isFav[id] = true end

    local function ratio(weight)
        LaParoleDuSeigneurDB.favoriteWeight = weight
        ns.ResetBag()
        local favCount, otherCount, picks = 0, 0, 30000
        for _ = 1, picks do
            local s = ns.NextSaying()
            if isFav[s.id] then favCount = favCount + 1 else otherCount = otherCount + 1 end
        end
        local pool = #ns.GetPool()
        return (favCount / #favs) / (otherCount / (pool - #favs))
    end

    local r5, r3, r1 = ratio(5), ratio(3), ratio(1)
    assert(r5 > 2.5, "weight 5 ratio too low: " .. r5)
    assert(r3 > 1.8, "weight 3 ratio too low: " .. r3)
    assert(r5 > r3 and r3 > r1, ("ratios should rise with weight: %.2f %.2f %.2f"):format(r1, r3, r5))
    assert(r1 > 0.7 and r1 < 1.4, "weight 1 should be neutral: " .. r1)
    LaParoleDuSeigneurDB.favorites = {}
    LaParoleDuSeigneurDB.favoriteWeight = 3
end)

test("weight command: valid range only", function()
    slash("weight 5") eq(LaParoleDuSeigneurDB.favoriteWeight, 5)
    slash("poids 2") eq(LaParoleDuSeigneurDB.favoriteWeight, 2)
    slash("weight 9") assert(printedContains("1 to 5")) eq(LaParoleDuSeigneurDB.favoriteWeight, 2)
    slash("weight 0") eq(LaParoleDuSeigneurDB.favoriteWeight, 2)
    slash("weight abc") eq(LaParoleDuSeigneurDB.favoriteWeight, 2)
    slash("weight 3")
end)

test("excluded sayings are never picked; favorite and exclude are mutually exclusive", function()
    slash("exclude John 3:16")
    eq(ns.IsExcluded("jn3_16"), true)
    ns.ResetBag()
    for _ = 1, 2000 do assert(ns.NextSaying().id ~= "jn3_16") end
    slash("fav John 3:16")
    eq(ns.IsFavorite("jn3_16"), true)
    eq(ns.IsExcluded("jn3_16"), false, "favoriting clears the exclusion")
    slash("exclude John 3:16")
    eq(ns.IsFavorite("jn3_16"), false, "excluding clears the favorite")
    slash("exclude John 3:16")
    eq(ns.IsExcluded("jn3_16"), false)
end)

test("categories: toggle by English or French name, disabled ones are never picked", function()
    slash("category")
    assert(printedContains("+Words of Jesus"))
    slash("category proverbs")
    eq(ns.CategoryEnabled("proverbs"), false)
    assert(printedContains("Category off: Proverbs"))
    ns.ResetBag()
    for _ = 1, 2000 do assert(ns.NextSaying().cat ~= "proverbs") end
    slash("category Proverbs")
    eq(ns.CategoryEnabled("proverbs"), true)
    slash("lang fr")
    slash("categorie psaumes")
    eq(ns.CategoryEnabled("psalms"), false)
    slash("categorie psaumes")
    slash("categorie ecclesiaste")   -- accent-free
    eq(ns.CategoryEnabled("ecclesiastes"), false)
    slash("categorie ecclesiaste")
    slash("categorie banane")
    assert(printedContains("inconnue"))
    slash("lang en")
end)

test("all categories off leaves only custom sayings, or a clear message when there are none", function()
    for _, c in ipairs(ns.CATEGORIES) do ns.SetCategory(c.key, false) end
    slash("")
    assert(printedContains("No sayings to preach"), "message missing")
    eq(#sent, 0)
    for _, c in ipairs(ns.CATEGORIES) do ns.SetCategory(c.key, true) end
end)

test("Québec sayings need Québec mode: favoring one in French mode explains why", function()
    slash("lang fr")
    slash("favori Prière traditionnelle")
    assert(printedContains("introuvable") or printedContains("Québec"))
    slash("lang en")
end)

---------------------------------------------------------------------------
-- Preaching, channels, splitting (unchanged behavior from 0.1.0)
---------------------------------------------------------------------------
test("/parole guilde sends once to guild, default unchanged", function()
    slash("guilde")
    eq(sent[1].chatType, "GUILD")
    eq(LaParoleDuSeigneurDB.channel, "SAY")
end)

test("group resolves to party / raid / instance", function()
    state.inGroup = true
    slash("groupe") eq(sent[#sent].chatType, "PARTY")
    state.inRaid = true
    slash("groupe") eq(sent[#sent].chatType, "RAID")
    state.inInstanceGroup = true
    slash("groupe") eq(sent[#sent].chatType, "INSTANCE_CHAT")
    state.inGroup, state.inRaid, state.inInstanceGroup = false, false, false
end)

test("not in group: prints locally instead of sending", function()
    slash("group")
    eq(#sent, 0)
    assert(printedContains("not in a group"))
end)

test("not in guild: prints locally", function()
    state.inGuild = false
    slash("guild")
    eq(#sent, 0)
    state.inGuild = true
end)

test("/parole canal crier changes default", function()
    slash("canal crier")
    eq(LaParoleDuSeigneurDB.channel, "YELL")
    slash("")
    eq(sent[#sent].chatType, "YELL")
    slash("channel say")
end)

test("add / list / remove custom sayings, pipes sanitized", function()
    slash("add For the Horde | and the Lord")
    eq(#LaParoleDuSeigneurDB.custom, 1)
    eq(LaParoleDuSeigneurDB.custom[1], "For the Horde / and the Lord")
    slash("list")
    assert(printedContains("1. For the Horde"))
    slash("remove 1")
    eq(#LaParoleDuSeigneurDB.custom, 0)
    slash("remove 9")
    assert(printedContains("Invalid number"))
end)

test("custom sayings are picked alongside built-ins", function()
    slash("add Ma parole perso")
    ns.ResetBag()
    local found = false
    for _ = 1, 600 do
        if ns.NextSaying().text == "Ma parole perso" then found = true break end
    end
    assert(found, "custom saying never picked")
    slash("remove 1")
end)

test("long messages split under 255 bytes on word boundaries, UTF-8 safe", function()
    local long = string.rep("épée lumière ", 60)
    slash("integrees")
    slash("add " .. long)
    slash("guilde")
    assert(#sent >= 2, "expected several chunks, got " .. #sent)
    for _, s in ipairs(sent) do
        assert(#s.msg <= 255)
        assert(not s.msg:find("^%s") and not s.msg:find("%s$"))
    end
    slash("remove 1")
    slash("integrees")
    local chunks = ns.SplitMessage(string.rep("é", 300))
    for _, c in ipairs(chunks) do
        assert(#c <= 255 and #c % 2 == 0, "split inside a character")
    end
end)

test("every saying in every language fits in chat after formatting (split if needed)", function()
    for _, mode in ipairs({ "en", "fr", "qc" }) do
        LaParoleDuSeigneurDB.lang = mode
        for _, shown in ipairs(ns.GetLibrary()) do
            for _, chunk in ipairs(ns.SplitMessage(ns.FormatSaying(shown))) do
                assert(#chunk <= 255 and not chunk:find("|", 1, true), shown.id)
            end
        end
    end
    LaParoleDuSeigneurDB.lang = "en"
end)

test("auto-preach: ticker, minimum, channel, combat skip, off", function()
    slash("auto 1 group")
    assert(printedContains("Minimum interval"))
    local t = tickers[#tickers]
    eq(t.seconds, 120)
    eq(LaParoleDuSeigneurDB.autoChannel, "GROUP")
    state.inGroup = true
    t.fn()
    eq(sent[#sent].chatType, "PARTY")
    local before = #sent
    state.combat = true
    t.fn()
    eq(#sent, before, "should skip in combat")
    state.combat, state.inGroup = false, false
    slash("auto off")
    eq(t.cancelled, true)
    eq(LaParoleDuSeigneurDB.autoEnabled, false)
end)

test("auto-preach on /say outdoors only prints (needs a click)", function()
    slash("auto 5 say")
    local t = tickers[#tickers]
    t.fn()
    eq(#sent, 0)
    assert(printedContains("needs a click"))
    state.inInstance = true
    t.fn()
    eq(sent[#sent].chatType, "SAY")
    state.inInstance = false
    slash("auto off")
end)

test("reactions: death and revive in group, in each language", function()
    slash("reactions")
    eq(LaParoleDuSeigneurDB.reactions, true)
    state.inGroup = true
    for mode, want in pairs({ en = { "Father, forgive", "John 11:25" }, fr = { "Père, pardonne", "Jean 11:25" },
                              qc = { "Père, pardonne", "Jean 11:25" } }) do
        LaParoleDuSeigneurDB.lang = mode
        state.dead = true
        fire("PLAYER_DEAD")
        assert(sent[#sent].msg:find(want[1], 1, true), mode .. " death: " .. sent[#sent].msg)
        fire("PLAYER_ALIVE")  -- released to ghost: still dead, no revive message
        local before = #sent
        state.dead = false
        fire("PLAYER_UNGHOST")
        assert(sent[#sent].msg:find(want[2], 1, true), mode .. " revive: " .. sent[#sent].msg)
        fire("PLAYER_ALIVE")  -- must not fire twice
        eq(#sent, before + 1)
    end
    LaParoleDuSeigneurDB.lang = "en"
    state.inGroup = false
    slash("reactions")
end)

test("reactions fire even if the reaction saying is excluded or its category is off", function()
    -- Reactions are a fixed saying chosen by the addon, not drawn from the pool.
    slash("reactions")
    state.inGroup = true
    slash("exclude Luke 23:34")
    ns.SetCategory("jesus", false)
    state.dead = true
    fire("PLAYER_DEAD")
    assert(sent[#sent].msg:find("Father, forgive", 1, true), "death reaction missing")
    state.dead = false
    fire("PLAYER_UNGHOST")
    ns.SetCategory("jesus", true)
    slash("exclude Luke 23:34")
    state.inGroup = false
    slash("reactions")
end)

test("button: right-click cycles channel, left-click preaches, toggle", function()
    local btn
    for _, f in ipairs(frames) do if f.scripts.OnClick then btn = f end end
    assert(btn, "button not created")
    btn.scripts.OnClick(btn, "RightButton")
    eq(LaParoleDuSeigneurDB.channel, "YELL")
    btn.scripts.OnClick(btn, "LeftButton")
    eq(sent[#sent].chatType, "YELL")
    slash("button")
    eq(btn.shown, false)
    slash("button")
    eq(btn.shown, true)
    slash("channel say")
end)

test("addon compartment click works", function()
    LaParoleDuSeigneur_OnAddonCompartmentClick(ADDON, "LeftButton")
    eq(#sent, 1)
end)

test("help text mentions the new commands in both interface languages", function()
    slash("help")
    assert(printedContains("/parole fav") and printedContains("/parole weight") and printedContains("/parole category"))
    slash("lang fr")
    printed = {}
    slash("aide")
    assert(printedContains("/parole favori") and printedContains("/parole poids") and printedContains("/parole categorie"))
    slash("lang en")
end)

test("reset keeps custom sayings, favorites and exclusions but resets settings", function()
    slash("add garde-moi")
    slash("fav John 3:16")
    slash("exclude John 14:6")
    slash("channel guild")
    slash("weight 5")
    slash("lang qc")
    slash("reset")
    eq(LaParoleDuSeigneurDB.channel, "SAY")
    eq(LaParoleDuSeigneurDB.favoriteWeight, 3)
    eq(LaParoleDuSeigneurDB.lang, "en", "reset goes back to English")
    eq(#LaParoleDuSeigneurDB.custom, 1)
    eq(LaParoleDuSeigneurDB.favorites.jn3_16, true)
    eq(LaParoleDuSeigneurDB.excluded.jn14_6, true)
    slash("remove 1")
    slash("fav John 3:16")
    slash("exclude John 14:6")
end)

test("unknown word shows help", function()
    slash("banane")
    assert(printedContains("/parole add"))
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
