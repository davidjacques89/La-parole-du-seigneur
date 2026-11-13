-- Offline test harness: stubs the parts of the WoW API the addon uses, loads the addon
-- files in TOC order, and exercises commands. Run from the repo root:  lua5.1 tests/run.lua
local ADDON = "WordsOfTheLord"
local DIR = ADDON .. "/"

---------------------------------------------------------------------------
-- Fake game state and API
---------------------------------------------------------------------------
local state = {
    locale = "enUS",  -- the client's language; tests switch it to frFR where they need French text
    inGuild = true, inGroup = false, inRaid = false, inInstanceGroup = false,
    inInstance = false, combat = false, dead = false, shift = false,
}
local sent, printed, tickers = {}, {}, {}

function GetLocale() return state.locale end
function IsInGuild() return state.inGuild end
function IsShiftKeyDown() return state.shift end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames = {}
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
    -- Unknown methods (capitalised names) do nothing; unknown fields are nil, as on real frames.
    setmetatable(f, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return function() end end
    end })
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetShown(v) self.shown = v and true or false end
    function f:SetPoint(...) self.points = { ... } end
    function f:GetPoint() local p = self.points return p[1], p[2], p[3], p[4], p[5] end
    function f:CreateTexture() return newFrame() end
    function f:CreateFontString() return newFrame() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetText(text) self.text = text end
    function f:GetText() return self.text or "" end
    function f:GetStringWidth() return 50 end
    function f:GetFrameLevel() return 1 end
    function f:SetFont() return true end
    function f:SetWidth(w) self.width = w end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetHeight(h) self.height = h end
    return f
end
local frames = {}
function CreateFrame(kind, name, parent)
    local f = newFrame()
    f.kind, f.name, f.parent = kind, name, parent
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
UIParent = newFrame()
GameTooltip = newFrame()
function GameTooltip:GetOwner() return nil end
-- The minimap: 140 wide, centered at (500, 400); the cursor position is set by tests.
Minimap = newFrame()
function Minimap:GetWidth() return 140 end
function Minimap:GetCenter() return 500, 400 end
function Minimap:GetEffectiveScale() return 1 end
state.cursor = { 500, 400 }
function GetCursorPosition() return state.cursor[1], state.cursor[2] end
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
local slash = SlashCmdList.WORDSOFTHELORD

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
    eq(SLASH_WORDSOFTHELORD1, "/parole")
    eq(type(WordsOfTheLordDB), "table")
    eq(WordsOfTheLordDB.lang, "en")
    eq(WordsOfTheLordDB.channel, "SAY")
    eq(WordsOfTheLordDB.favoriteWeight, 3)
    eq(ns.GetLang(), "en")
    eq(ns.UILang(), "en", "English client")
end)

test("interface language follows the game client, not the saying language", function()
    state.locale = "frFR"
    eq(ns.UILang(), "fr")
    eq(ns.GetLang(), "en", "sayings stay English on a French client")
    eq(ns.L.TAB_LIBRARY, "Bibliothèque")
    slash("help")
    assert(printedContains("/parole livre"), "French help")
    state.locale = "enUS"
    eq(ns.UILang(), "en")
    eq(ns.L.TAB_LIBRARY, "Library")
    for _, locale in ipairs({ "deDE", "esES", "koKR", "ruRU", "zhCN", "ptBR", "itIT" }) do
        state.locale = locale
        eq(ns.UILang(), "en", locale)
    end
    state.locale = "enUS"
    -- the saying language is a separate choice and never changes the interface language
    slash("lang qc")
    eq(ns.UILang(), "en", "Québec sayings on an English client keep the English interface")
    assert(ns.FormatSaying({ text = "Ave", ref = "x" }):find("^« "), "French sayings use guillemets")
    slash("lang en")
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
test("library: 78 verses plus 40+ Québec sayings, ids unique and well formed", function()
    local nQuebec = 0
    for _, e in ipairs(ns.sayings) do if e.cat == "quebec" then nQuebec = nQuebec + 1 end end
    eq(#ns.sayings - nQuebec, 78, "Bible verses")
    assert(nQuebec >= 40, "expected 40+ Québec sayings, got " .. nQuebec)
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
                assert(#v < 500, e.id .. "." .. field .. " is too long")
            end
        end
    end
end)

test("English mode: English text only, no Québec sayings", function()
    WordsOfTheLordDB.lang = "en"
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
    eq(ns.UILang(), "en", "interface language follows the client, not the sayings")
end)

test("Québec mode: full French library plus the Québec sayings", function()
    local frCount = #ns.GetLibrary()
    slash("langue qc")
    eq(ns.GetLang(), "qc")
    eq(ns.UILang(), "en", "Québec sayings do not change the interface language")
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
    WordsOfTheLordDB.lang = "qc"
    ns.ResetBag()
    local sawQuebec = false
    for _ = 1, 400 do
        local s = ns.NextSaying()
        if s.cat == "quebec" then sawQuebec = true break end
    end
    assert(sawQuebec, "no Québec saying picked in 400 tries")
    for _, mode in ipairs({ "en", "fr" }) do
        WordsOfTheLordDB.lang = mode
        ns.ResetBag()
        for _ = 1, 300 do assert(ns.NextSaying().cat ~= "quebec") end
    end
    WordsOfTheLordDB.lang = "en"
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
    WordsOfTheLordDB = {
        channel = "GUILD", lang = "auto", useBuiltin = false, custom = { kept[1], kept[2] },
        autoEnabled = true, autoMinutes = 15, autoChannel = "GROUP", reactions = true,
        button = { shown = false, locked = true, point = "TOP", relPoint = "TOP", x = 5, y = 6 },
    }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    local db = WordsOfTheLordDB
    eq(ns.db, db)
    eq(db.lang, "en", "auto -> en")
    eq(db.schema, 2)
    eq(db.channel, "GUILD")
    eq(db.useBuiltin, false)
    eq(#db.custom, 2); eq(db.custom[1], kept[1]); eq(db.custom[2], kept[2])
    eq(db.autoMinutes, 15); eq(db.autoChannel, "GROUP"); eq(db.reactions, true)
    eq(db.button.shown, false); eq(db.button.locked, true)
    eq(db.button.x, nil, "old floating position dropped"); eq(db.button.point, nil)
    eq(db.button.angle, 215, "minimap angle default")
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
    WordsOfTheLordDB = { lang = "fr", custom = {} }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    eq(WordsOfTheLordDB.lang, "fr")
    eq(WordsOfTheLordDB.schema, 2)
end)

test("settings saved under the former name are moved to the new variable once", function()
    WordsOfTheLordDB = nil
    LaParoleDuSeigneurDB = {
        schema = 2, lang = "qc", quebecShare = 55, channel = "GUILD", custom = { "Ma parole" },
        favorites = { jn3_16 = true }, excluded = { jn14_6 = true },
    }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    local db = WordsOfTheLordDB
    eq(ns.db, db)
    eq(db.lang, "qc"); eq(db.quebecShare, 55); eq(db.channel, "GUILD")
    eq(db.custom[1], "Ma parole"); eq(db.favorites.jn3_16, true); eq(db.excluded.jn14_6, true)
    eq(LaParoleDuSeigneurDB, nil, "old variable must be cleared")
    -- A second load must keep using the new variable.
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    eq(WordsOfTheLordDB.lang, "qc")
end)

test("new variable wins when both exist", function()
    WordsOfTheLordDB = { schema = 2, lang = "fr", custom = {} }
    LaParoleDuSeigneurDB = { schema = 2, lang = "qc", custom = {} }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    eq(WordsOfTheLordDB.lang, "fr")
    eq(LaParoleDuSeigneurDB, nil)
end)

test("garbage saved language falls back to English", function()
    WordsOfTheLordDB = { lang = "klingon", schema = 2 }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    eq(WordsOfTheLordDB.lang, "en")
end)

-- Back to a clean database for the rest of the run.
WordsOfTheLordDB = nil
ns.eventFrame:RegisterEvent("ADDON_LOADED")
fire("ADDON_LOADED", ADDON)
ns.ResetBag()
WordsOfTheLordDB.lang = "en"

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
    eq(WordsOfTheLordDB.useBuiltin, false)
    slash("add Une seule")
    ns.ResetBag()
    for _ = 1, 5 do eq(ns.NextSaying().text, "Une seule") end
    slash("add Une autre")
    ns.ResetBag()
    local a, b = ns.NextSaying().text, ns.NextSaying().text
    assert(a ~= b, "two-saying pool repeated")
    slash("remove 2") slash("remove 1")
    slash("integrees")
    eq(WordsOfTheLordDB.useBuiltin, true)
end)

test("favorite by reference: toggles, English and French spellings, accents ignored", function()
    slash("fav john 3:16")
    eq(ns.IsFavorite("jn3_16"), true)
    assert(printedContains("Favorite added: John 3:16"))
    slash("fav John 3:16")
    eq(ns.IsFavorite("jn3_16"), false)
    assert(printedContains("Favorite removed"))
    slash("langue fr")
    state.locale = "frFR"
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
    state.locale = "enUS"
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
    for _, id in ipairs(favs) do WordsOfTheLordDB.favorites[id] = true end
    local isFav = {}
    for _, id in ipairs(favs) do isFav[id] = true end

    local function ratio(weight)
        WordsOfTheLordDB.favoriteWeight = weight
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
    WordsOfTheLordDB.favorites = {}
    WordsOfTheLordDB.favoriteWeight = 3
end)

test("weight command: valid range only", function()
    slash("weight 5") eq(WordsOfTheLordDB.favoriteWeight, 5)
    slash("poids 2") eq(WordsOfTheLordDB.favoriteWeight, 2)
    slash("weight 9") assert(printedContains("1 to 5")) eq(WordsOfTheLordDB.favoriteWeight, 2)
    slash("weight 0") eq(WordsOfTheLordDB.favoriteWeight, 2)
    slash("weight abc") eq(WordsOfTheLordDB.favoriteWeight, 2)
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
    state.locale = "frFR"
    slash("categorie psaumes")
    eq(ns.CategoryEnabled("psalms"), false)
    slash("categorie psaumes")
    slash("categorie ecclesiaste")   -- accent-free
    eq(ns.CategoryEnabled("ecclesiastes"), false)
    slash("categorie ecclesiaste")
    slash("categorie banane")
    assert(printedContains("inconnue"))
    state.locale = "enUS"
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
    state.locale = "frFR"
    slash("favori Prière traditionnelle")
    assert(printedContains("introuvable") or printedContains("Québec"))
    state.locale = "enUS"
    slash("lang en")
end)

---------------------------------------------------------------------------
-- Québec mode weighting (option A)
---------------------------------------------------------------------------
local function quebecFraction(picks)
    ns.ResetBag()
    local q = 0
    for _ = 1, picks do
        if ns.NextSaying().cat == "quebec" then q = q + 1 end
    end
    return q / picks
end

test("Québec share defaults to 70% and Québec mode picks Québec sayings about 70% of the time", function()
    eq(WordsOfTheLordDB.quebecShare, 70)
    eq(ns.QuebecShare(), 70)
    math.randomseed(2024)
    WordsOfTheLordDB.lang = "qc"
    local f = quebecFraction(20000)
    assert(f > 0.66 and f < 0.74, "expected about 0.70, got " .. f)
    WordsOfTheLordDB.lang = "en"
end)

test("quebec command: set, show, validate; 100 = Québec only, 0 = verses only", function()
    state.locale = "frFR"   -- these messages are checked in French
    slash("lang qc")
    slash("quebec")
    assert(printedContains("70 %"), "info should show 70 %")
    slash("quebec 100")
    eq(WordsOfTheLordDB.quebecShare, 100)
    eq(quebecFraction(3000), 1)
    slash("quebec 0")
    eq(quebecFraction(3000), 0)
    slash("québec 45")
    eq(WordsOfTheLordDB.quebecShare, 45)
    assert(printedContains("45 %") and printedContains("55 %"))
    local f = quebecFraction(20000)
    assert(f > 0.41 and f < 0.49, "expected about 0.45, got " .. f)
    slash("quebec 101")  assert(printedContains("0 à 100")) eq(WordsOfTheLordDB.quebecShare, 45)
    slash("quebec -5")   eq(WordsOfTheLordDB.quebecShare, 45)
    slash("quebec abc")  eq(WordsOfTheLordDB.quebecShare, 45)
    slash("qc 80")       eq(WordsOfTheLordDB.quebecShare, 80)
    state.locale = "enUS"
    slash("lang en")
    slash("quebec 70")
    assert(printedContains("Québec mode: 70% Québec sayings, 30% verses"))
end)

test("the Québec share has no effect in English or French mode (no Québec sayings there)", function()
    WordsOfTheLordDB.quebecShare = 100
    for _, mode in ipairs({ "en", "fr" }) do
        WordsOfTheLordDB.lang = mode
        eq(quebecFraction(2000), 0, mode)
    end
    WordsOfTheLordDB.quebecShare = 70
    WordsOfTheLordDB.lang = "en"
end)

test("Québec mode with the Québec category off falls back to verses; verses off falls back to Québec", function()
    WordsOfTheLordDB.lang = "qc"
    ns.SetCategory("quebec", false)
    eq(quebecFraction(2000), 0)
    ns.SetCategory("quebec", true)
    for _, c in ipairs(ns.CATEGORIES) do
        if c.key ~= "quebec" then ns.SetCategory(c.key, false) end
    end
    eq(quebecFraction(2000), 1, "only Québec sayings left")
    for _, c in ipairs(ns.CATEGORIES) do ns.SetCategory(c.key, true) end
    WordsOfTheLordDB.lang = "en"
end)

test("Québec mode: the player's own sayings share the 30% side with the verses", function()
    WordsOfTheLordDB.lang = "qc"
    slash("add Ma parole perso")
    ns.ResetBag()
    local custom, picks = 0, 20000
    for _ = 1, picks do
        if ns.NextSaying().text == "Ma parole perso" then custom = custom + 1 end
    end
    -- 30% of picks go to the verse group (78 verses + 1 custom), so about 0.3/79 each.
    local expected = picks * 0.30 / 79
    assert(custom > expected * 0.5 and custom < expected * 1.8, ("custom %d vs expected %.0f"):format(custom, expected))
    slash("quebec 0")
    ns.ResetBag()
    local found = false
    for _ = 1, 600 do if ns.NextSaying().text == "Ma parole perso" then found = true break end end
    assert(found, "own saying must still come up when Québec share is 0")
    slash("quebec 70")
    slash("remove 1")
    WordsOfTheLordDB.lang = "en"
end)

test("Québec mode: favorites still weigh more inside the Québec group, and exclusions apply", function()
    math.randomseed(777)
    WordsOfTheLordDB.lang = "qc"
    WordsOfTheLordDB.quebecShare = 100
    WordsOfTheLordDB.favorites = { qc_notre_pere = true }
    WordsOfTheLordDB.excluded = { qc_angelus1 = true }
    WordsOfTheLordDB.favoriteWeight = 5
    ns.ResetBag()
    local counts, picks = {}, 30000
    for _ = 1, picks do
        local s = ns.NextSaying()
        counts[s.id] = (counts[s.id] or 0) + 1
    end
    eq(counts.qc_angelus1, nil, "excluded saying was picked")
    local others, n = 0, 0
    for id, c in pairs(counts) do
        if id ~= "qc_notre_pere" then others = others + c n = n + 1 end
    end
    local ratio = counts.qc_notre_pere / (others / n)
    assert(ratio > 2.5, "favorite ratio too low: " .. ratio)
    WordsOfTheLordDB.favorites, WordsOfTheLordDB.excluded = {}, {}
    WordsOfTheLordDB.favoriteWeight, WordsOfTheLordDB.quebecShare = 3, 70
    WordsOfTheLordDB.lang = "en"
end)

test("Québec mode: no immediate repeats across both groups", function()
    WordsOfTheLordDB.lang = "qc"
    ns.ResetBag()
    local last
    for _ = 1, 5000 do
        local s = ns.NextSaying()
        assert(s.id ~= last, "immediate repeat of " .. s.id)
        last = s.id
    end
    WordsOfTheLordDB.lang = "en"
end)

test("existing 0.2.0 saved settings (no quebecShare) get the 70% default", function()
    WordsOfTheLordDB = { lang = "qc", schema = 2, custom = {}, favorites = { jn3_16 = true } }
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    eq(WordsOfTheLordDB.quebecShare, 70)
    eq(WordsOfTheLordDB.lang, "qc")
    eq(WordsOfTheLordDB.favorites.jn3_16, true)
    WordsOfTheLordDB = nil
    ns.eventFrame:RegisterEvent("ADDON_LOADED")
    fire("ADDON_LOADED", ADDON)
    ns.ResetBag()
end)

test("reset puts the Québec share back to 70", function()
    slash("quebec 20")
    slash("reset")
    eq(WordsOfTheLordDB.quebecShare, 70)
end)

test("the new prayers split into valid chat lines in the right order", function()
    WordsOfTheLordDB.lang = "qc"
    local np = ns.FindSayingById("qc_notre_pere")
    local chunks = ns.SplitMessage(ns.FormatSaying(np))
    assert(#chunks >= 2, "Notre Père should need two chat lines")
    local joined = table.concat(chunks, " ")
    assert(joined:find("^« Notre Père, qui êtes aux cieux"), joined:sub(1, 40))
    assert(joined:find("Ainsi soit%-il%. » — Notre Père %(ancienne version%)$"), joined:sub(-60))
    WordsOfTheLordDB.lang = "en"
end)

---------------------------------------------------------------------------
-- Preaching, channels, splitting (unchanged behavior from 0.1.0)
---------------------------------------------------------------------------
test("/parole guilde sends once to guild, default unchanged", function()
    slash("guilde")
    eq(sent[1].chatType, "GUILD")
    eq(WordsOfTheLordDB.channel, "SAY")
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
    eq(WordsOfTheLordDB.channel, "YELL")
    slash("")
    eq(sent[#sent].chatType, "YELL")
    slash("channel say")
end)

test("add / list / remove custom sayings, pipes sanitized", function()
    slash("add For the Horde | and the Lord")
    eq(#WordsOfTheLordDB.custom, 1)
    eq(WordsOfTheLordDB.custom[1], "For the Horde / and the Lord")
    slash("list")
    assert(printedContains("1. For the Horde"))
    slash("remove 1")
    eq(#WordsOfTheLordDB.custom, 0)
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
        WordsOfTheLordDB.lang = mode
        for _, shown in ipairs(ns.GetLibrary()) do
            for _, chunk in ipairs(ns.SplitMessage(ns.FormatSaying(shown))) do
                assert(#chunk <= 255 and not chunk:find("|", 1, true), shown.id)
            end
        end
    end
    WordsOfTheLordDB.lang = "en"
end)

test("auto-preach: ticker, minimum, channel, combat skip, off", function()
    slash("auto 1 group")
    assert(printedContains("Minimum interval"))
    local t = tickers[#tickers]
    eq(t.seconds, 120)
    eq(WordsOfTheLordDB.autoChannel, "GROUP")
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
    eq(WordsOfTheLordDB.autoEnabled, false)
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
    eq(WordsOfTheLordDB.reactions, true)
    state.inGroup = true
    for mode, want in pairs({ en = { "Father, forgive", "John 11:25" }, fr = { "Père, pardonne", "Jean 11:25" },
                              qc = { "Père, pardonne", "Jean 11:25" } }) do
        WordsOfTheLordDB.lang = mode
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
    WordsOfTheLordDB.lang = "en"
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
    for _, f in ipairs(frames) do if f.name == "WordsOfTheLordButton" then btn = f end end
    assert(btn, "button not created")
    btn.scripts.OnClick(btn, "RightButton")
    eq(WordsOfTheLordDB.channel, "YELL")
    btn.scripts.OnClick(btn, "LeftButton")
    eq(sent[#sent].chatType, "YELL")
    slash("button")
    eq(btn.shown, false)
    slash("button")
    eq(btn.shown, true)
    slash("channel say")
end)

test("minimap button: sits on the minimap, offsets follow the angle and the minimap shape", function()
    local btn
    for _, f in ipairs(frames) do if f.name == "WordsOfTheLordButton" then btn = f end end
    eq(btn.parent, Minimap, "button lives on the minimap")
    local function near(a, b) assert(math.abs(a - b) < 0.001, a .. " vs " .. b) end
    local x, y = ns.MinimapOffset(0, 70)
    near(x, 75) near(y, 0)
    x, y = ns.MinimapOffset(90, 70)
    near(x, 0) near(y, 75)
    x, y = ns.MinimapOffset(180, 70)
    near(x, -75) near(y, 0)
    x, y = ns.MinimapOffset(45, 70, "SQUARE")
    near(x, 75) near(y, 75)
    local p = btn.points
    eq(p[1], "CENTER") eq(p[2], Minimap) eq(p[3], "CENTER")
    local dx, dy = ns.MinimapOffset(WordsOfTheLordDB.button.angle, 70)
    near(p[4], dx) near(p[5], dy)
end)

test("minimap button: dragging slides it around the edge, lock stops it", function()
    local btn
    for _, f in ipairs(frames) do if f.name == "WordsOfTheLordButton" then btn = f end end
    btn.scripts.OnDragStart(btn)
    assert(btn.scripts.OnUpdate, "dragging should start an update loop")
    state.cursor = { 500, 520 }   -- straight above the center
    btn.scripts.OnUpdate(btn)
    assert(math.abs(WordsOfTheLordDB.button.angle - 90) < 0.001, WordsOfTheLordDB.button.angle)
    state.cursor = { 380, 400 }   -- to the left
    btn.scripts.OnUpdate(btn)
    assert(math.abs(WordsOfTheLordDB.button.angle - 180) < 0.001, WordsOfTheLordDB.button.angle)
    state.cursor = { 500, 300 }   -- below: angles stay in 0-360
    btn.scripts.OnUpdate(btn)
    assert(math.abs(WordsOfTheLordDB.button.angle - 270) < 0.001, WordsOfTheLordDB.button.angle)
    local p = btn.points
    assert(math.abs(p[4]) < 0.001 and math.abs(p[5] + 75) < 0.001, "button moved to the bottom of the minimap")
    btn.scripts.OnDragStop(btn)
    eq(btn.scripts.OnUpdate, nil, "update loop stops with the drag")
    -- locked: dragging does nothing
    slash("lock")
    btn.scripts.OnDragStart(btn)
    eq(btn.scripts.OnUpdate, nil)
    slash("lock")
    -- the angle survives in the saved variables
    eq(type(WordsOfTheLordDB.button.angle), "number")
    state.cursor = { 500, 400 }
end)

test("addon compartment: left-click opens the book, right-click changes channel", function()
    WordsOfTheLord_OnAddonCompartmentClick(ADDON, "LeftButton")
    eq(#sent, 0, "opening the book does not preach")
    eq(WordsOfTheLordWindow:IsShown(), true)
    WordsOfTheLord_OnAddonCompartmentClick(ADDON, "LeftButton")
    eq(WordsOfTheLordWindow:IsShown(), false)
    WordsOfTheLord_OnAddonCompartmentClick(ADDON, "RightButton")
    eq(WordsOfTheLordDB.channel, "YELL")
    slash("channel say")
end)

test("help text mentions the new commands in both interface languages", function()
    slash("help")
    assert(printedContains("/parole fav") and printedContains("/parole weight") and printedContains("/parole category") and printedContains("/parole quebec"))
    state.locale = "frFR"
    printed = {}
    slash("aide")
    state.locale = "enUS"
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
    eq(WordsOfTheLordDB.channel, "SAY")
    eq(WordsOfTheLordDB.favoriteWeight, 3)
    eq(WordsOfTheLordDB.lang, "en", "reset goes back to English")
    eq(#WordsOfTheLordDB.custom, 1)
    eq(WordsOfTheLordDB.favorites.jn3_16, true)
    eq(WordsOfTheLordDB.excluded.jn14_6, true)
    slash("remove 1")
    slash("fav John 3:16")
    slash("exclude John 14:6")
end)

test("unknown word shows help", function()
    slash("banane")
    assert(printedContains("/parole add"))
end)


---------------------------------------------------------------------------
-- The book (tabbed window)
---------------------------------------------------------------------------
local function buttonByLabel(text)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.label and f.label.text == text then return f end
    end
end
local function choice(key)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.choice == key then return f end
    end
end
local function click(button, ...) button.scripts.OnClick(button, ...) end
local function visibleGroups()
    local n = 0
    for _, g in ipairs(ns.ui.allGroups) do if g:IsShown() then n = n + 1 end end
    return n
end

-- start the window tests from a clean slate
slash("reset")
wipe(WordsOfTheLordDB.favorites) wipe(WordsOfTheLordDB.excluded) wipe(WordsOfTheLordDB.custom)
state.locale = "enUS"

test("book: /parole book opens it on the Library, toggles closed, closes with Escape", function()
    slash("book")
    local win = WordsOfTheLordWindow
    assert(win, "window not built")
    eq(win:IsShown(), true)
    eq(ns.ui.tab, "lib")
    eq(visibleGroups(), 2, "left page plus reader")
    local found = false
    for _, name in ipairs(UISpecialFrames) do if name == "WordsOfTheLordWindow" then found = true end end
    assert(found, "not registered for Escape")
    slash("livre")
    eq(win:IsShown(), false)
    slash("window")
    eq(win:IsShown(), true)
    slash("settings")
    eq(win:IsShown(), false)
    slash("book")
end)

test("book: four ribbons switch tabs and each tab shows its own pages", function()
    local ribbons = ns.ui.ribbons
    eq(#ribbons, 4)
    eq(ribbons[1].label.text, "Library")
    eq(ribbons[2].label.text, "Favorites")
    eq(ribbons[3].label.text, "Settings")
    eq(ribbons[4].label.text, "My sayings")
    click(ribbons[2]) eq(ns.ui.tab, "fav") eq(visibleGroups(), 2)
    click(ribbons[3]) eq(ns.ui.tab, "set") eq(visibleGroups(), 2)
    click(ribbons[4]) eq(ns.ui.tab, "mine") eq(visibleGroups(), 2)
    click(ribbons[1]) eq(ns.ui.tab, "lib")
    -- the open tab's ribbon hangs lower than the others
    assert(ribbons[1].height > ribbons[2].height, "active ribbon should be taller")
end)

test("book: the whole interface follows the game's language", function()
    state.locale = "frFR"
    ns.ui.Refresh()
    eq(ns.ui.ribbons[1].label.text, "Bibliothèque")
    eq(ns.ui.ribbons[2].label.text, "Favoris")
    eq(ns.ui.ribbons[3].label.text, "Réglages")
    eq(ns.ui.ribbons[4].label.text, "Mes paroles")
    eq(ns.GetLang(), "en", "the sayings are still English")
    state.locale = "enUS"
    ns.ui.Refresh()
    eq(ns.ui.ribbons[1].label.text, "Library")
    -- every French key exists in English and the other way round
    for key in pairs(ns.strings.en) do assert(ns.strings.fr[key] ~= nil, "missing fr: " .. key) end
    for key in pairs(ns.strings.fr) do assert(ns.strings.en[key] ~= nil, "missing en: " .. key) end
end)

test("book: library lists the sayings, search and category chips filter them", function()
    local total = #ns.GetLibrary()
    eq(#ns.ui.Rows("lib"), total)
    eq(#ns.ui.libList.data, total)
    ns.ui.searchBox:SetText("shepherd")
    ns.ui.searchBox.scripts.OnTextChanged(ns.ui.searchBox)
    local rows = ns.ui.Rows("lib")
    assert(#rows >= 1 and #rows < total, "search should narrow the list, got " .. #rows)
    for _, r in ipairs(rows) do assert((r.text .. r.ref):lower():find("shepherd", 1, true), r.id) end
    ns.ui.searchBox:SetText("")
    ns.ui.searchBox.scripts.OnTextChanged(ns.ui.searchBox)
    eq(#ns.ui.Rows("lib"), total)
    -- chips: All plus categories; Québec does not show outside Québec mode
    local chipByKey = {}
    for _, chip in ipairs(ns.ui.chips) do chipByKey[chip.key or "all"] = chip end
    click(chipByKey.psalms)
    eq(ns.ui.cat, "psalms")
    for _, r in ipairs(ns.ui.Rows("lib")) do eq(r.cat, "psalms") end
    click(chipByKey.psalms)
    eq(ns.ui.cat, nil, "clicking the active chip clears it")
    eq(chipByKey.quebec.shown, false)
    slash("lang qc")
    ns.ui.Refresh()
    eq(chipByKey.quebec.shown, true)
    click(chipByKey.quebec)
    for _, r in ipairs(ns.ui.Rows("lib")) do eq(r.cat, "quebec") end
    slash("lang en")
    eq(ns.ui.cat, nil, "a category that no longer exists is dropped")
end)

test("book: search ignores accents and case in French", function()
    slash("lang fr")
    ns.ui.searchBox:SetText("ESAIE")
    ns.ui.searchBox.scripts.OnTextChanged(ns.ui.searchBox)
    local rows = ns.ui.Rows("lib")
    assert(#rows >= 1, "Ésaïe should match esaie")
    for _, r in ipairs(rows) do assert(ns.Fold(r.ref):find("esaie", 1, true), r.ref) end
    ns.ui.searchBox:SetText("")
    ns.ui.searchBox.scripts.OnTextChanged(ns.ui.searchBox)
    slash("lang en")
end)

test("book: selecting a saying shows it in the reader; preach sends it", function()
    local row = ns.ui.libList.rows[3]
    click(row)
    eq(ns.ui.selected, row.item.id)
    local selected = ns.ui.Selected()
    eq(selected.id, row.item.id)
    local preach = buttonByLabel("PREACH THIS")
    assert(preach, "preach button missing")
    click(preach)
    eq(#sent, 1)
    assert(sent[1].msg:find(selected.ref, 1, true), sent[1].msg)
end)

test("book: diamond marks a favorite, Favorites tab lists it, reader buttons toggle", function()
    local row = ns.ui.libList.rows[2]
    local id = row.item.id
    click(row.mark)
    eq(ns.IsFavorite(id), true)
    click(ns.ui.ribbons[2])
    eq(#ns.ui.favList.data, 1)
    eq(ns.ui.favList.data[1].id, id)
    eq(ns.ui.Selected().id, id, "selection moves to the favorite")
    local fav = buttonByLabel("FAVORITED")
    assert(fav, "reader should say FAVORITED")
    click(fav)
    eq(ns.IsFavorite(id), false)
    eq(#ns.ui.favList.data, 0)
    eq(ns.ui.selected, nil)
    click(ns.ui.ribbons[1])
    -- never say: excluded and favorite are mutually exclusive
    local first = ns.ui.libList.rows[1]
    click(first)
    click(buttonByLabel("NEVER SAY"))
    eq(ns.IsExcluded(first.item.id), true)
    assert(buttonByLabel("EXCLUDED"), "reader should say EXCLUDED")
    click(first.mark)
    eq(ns.IsFavorite(first.item.id), true)
    eq(ns.IsExcluded(first.item.id), false)
    click(first.mark)
end)

test("book: mouse wheel and scrollbar move the list and stay in range", function()
    local list = ns.ui.libList
    list:SetData(ns.ui.Rows("lib"))
    local maxOffset = #list.data - list.rowCount
    assert(maxOffset > 0)
    list.holder.scripts.OnMouseWheel(list.holder, -1)
    eq(list.offset, 1)
    list.holder.scripts.OnMouseWheel(list.holder, -1000)
    eq(list.offset, maxOffset)
    list.holder.scripts.OnMouseWheel(list.holder, 1000)
    eq(list.offset, 0)
    list.slider.scripts.OnValueChanged(list.slider, 4)
    eq(list.offset, 4)
    eq(list.rows[1].item.id, list.data[5].id)
end)

test("book: settings buttons change the real settings", function()
    click(ns.ui.ribbons[3])
    -- sayings language
    click(choice("fr"))
    eq(ns.GetLang(), "fr")
    eq(ns.UILang(), "en", "interface language stays with the client")
    click(choice("qc"))
    eq(ns.GetLang(), "qc")
    click(choice("en"))
    eq(ns.GetLang(), "en")
    eq(choice("fr").label.text, "Français")
    -- channel
    click(choice("GUILD"))
    eq(WordsOfTheLordDB.channel, "GUILD")
    eq(choice("GUILD").label.text, "Guild")
    click(choice("SAY"))
    eq(WordsOfTheLordDB.channel, "SAY")
    -- favorite weight
    click(choice(5))
    eq(ns.FavoriteWeight(), 5)
    click(choice(3))
    eq(ns.FavoriteWeight(), 3)
end)

test("book: switches and steppers: auto-preach, reactions, categories, Québec share, button", function()
    local function stepperButtons()
        local plus, minus = {}, {}
        for _, f in ipairs(frames) do
            if f.kind == "Button" and f.label then
                if f.label.text == "+" then plus[#plus + 1] = f end
                if f.label.text == "-" then minus[#minus + 1] = f end
            end
        end
        return plus, minus
    end
    local plus, minus = stepperButtons()
    -- order of creation: auto-preach minutes, then Québec share
    local before = WordsOfTheLordDB.autoMinutes
    click(plus[1]) eq(WordsOfTheLordDB.autoMinutes, before + 1)
    click(minus[1]) eq(WordsOfTheLordDB.autoMinutes, before)
    for _ = 1, 100 do click(minus[1]) end
    eq(WordsOfTheLordDB.autoMinutes, ns.AUTO_MIN_MINUTES, "never below the floor")
    click(plus[1]) click(plus[1]) click(plus[1]) click(plus[1]) click(plus[1]) click(plus[1]) click(plus[1]) click(plus[1])
    local share = WordsOfTheLordDB.quebecShare
    click(plus[2]) eq(WordsOfTheLordDB.quebecShare, share + 5)
    for _ = 1, 40 do click(plus[2]) end
    eq(WordsOfTheLordDB.quebecShare, 100)
    for _ = 1, 40 do click(minus[2]) end
    eq(WordsOfTheLordDB.quebecShare, 0)
    WordsOfTheLordDB.quebecShare = 70

    -- switches are the only Buttons of size 42x22
    local switches = {}
    for _, f in ipairs(frames) do if f.kind == "Button" and f.width == 42 and f.height == 22 then switches[#switches + 1] = f end end
    eq(#switches, 5, "auto-preach, reactions, built-in, button shown, button locked")
    local ticksBefore = #tickers
    click(switches[1])
    eq(WordsOfTheLordDB.autoEnabled, true)
    assert(#tickers > ticksBefore and not tickers[#tickers].cancelled, "auto-preach timer started")
    click(switches[1])
    eq(WordsOfTheLordDB.autoEnabled, false)
    assert(tickers[#tickers].cancelled, "auto-preach timer stopped")
    click(switches[2]) eq(WordsOfTheLordDB.reactions, true)
    click(switches[2]) eq(WordsOfTheLordDB.reactions, false)
    click(switches[3]) eq(WordsOfTheLordDB.useBuiltin, false)
    click(switches[3]) eq(WordsOfTheLordDB.useBuiltin, true)
    click(switches[4]) eq(WordsOfTheLordDB.button.shown, false)
    click(switches[4]) eq(WordsOfTheLordDB.button.shown, true)
    click(switches[5]) eq(WordsOfTheLordDB.button.locked, true)
    click(switches[5]) eq(WordsOfTheLordDB.button.locked, false)

    -- category checkboxes: the six category buttons are 'Button' frames of width 151 x 24
    local boxes = {}
    for _, f in ipairs(frames) do if f.kind == "Button" and f.width == 151 and f.height == 24 then boxes[#boxes + 1] = f end end
    eq(#boxes, #ns.CATEGORIES)
    click(boxes[1])
    eq(ns.CategoryEnabled(ns.CATEGORIES[1].key), false)
    click(boxes[1])
    eq(ns.CategoryEnabled(ns.CATEGORIES[1].key), true)
end)

test("book: auto-preach channel button steps through the channels", function()
    local start = WordsOfTheLordDB.autoChannel
    click(ns.ui.autoChannelButton)
    assert(WordsOfTheLordDB.autoChannel ~= start)
    for _ = 1, #ns.CHANNEL_ORDER - 1 do click(ns.ui.autoChannelButton) end
    eq(WordsOfTheLordDB.autoChannel, start, "steps through every channel and comes back")
end)

test("book: My sayings adds and removes your own sayings", function()
    click(ns.ui.ribbons[4])
    eq(#ns.ui.ownList.data, 0)
    ns.ui.editBox:SetText("Be kind.")
    click(buttonByLabel("ADD TO THE BOOK"))
    eq(#WordsOfTheLordDB.custom, 1)
    eq(WordsOfTheLordDB.custom[1], "Be kind.")
    eq(ns.ui.editBox:GetText(), "", "box is emptied after adding")
    eq(#ns.ui.ownList.data, 1)
    ns.ui.editBox:SetText("   ")
    click(buttonByLabel("ADD TO THE BOOK"))
    eq(#WordsOfTheLordDB.custom, 1, "blank text is not added")
    ns.ui.editBox:SetText("Go in peace.")
    click(buttonByLabel("ADD TO THE BOOK"))
    eq(#ns.ui.ownList.data, 2)
    click(ns.ui.ownList.rows[1].remove)
    eq(#WordsOfTheLordDB.custom, 1)
    eq(WordsOfTheLordDB.custom[1], "Go in peace.")
    click(ns.ui.ownList.rows[1].remove)
    eq(#WordsOfTheLordDB.custom, 0)
end)

test("book: a slash command updates an open book", function()
    click(ns.ui.ribbons[1])
    local id = ns.ui.libList.rows[1].item.id
    local ref = ns.FindSayingById(id).ref
    assert(not ns.IsFavorite(id))
    slash("fav " .. ref)
    eq(ns.ui.libList.rows[1].item.favorite, true, "row shows the new favorite without reopening")
    slash("fav " .. ref)
end)

test("button: shift-click opens the book instead of preaching", function()
    local btn
    for _, f in ipairs(frames) do if f.name == "WordsOfTheLordButton" then btn = f end end
    ns.CloseWindow()
    local before = #sent
    state.shift = true
    click(btn, "LeftButton")
    state.shift = false
    eq(#sent, before, "nothing preached")
    eq(WordsOfTheLordWindow:IsShown(), true)
    ns.CloseWindow()
end)

test("book: opening a French client's window works end to end", function()
    state.locale = "frFR"
    ns.OpenWindow("set")
    eq(ns.ui.tab, "set")
    eq(choice("fr").label.text, "Français")
    eq(choice("GUILD").label.text, "Guilde", "channel names follow the client language")
    state.locale = "enUS"
    ns.CloseWindow()
    ns.ui.tab = "lib"
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
