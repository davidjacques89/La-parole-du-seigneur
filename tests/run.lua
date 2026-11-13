-- Offline test harness: stubs the parts of the WoW API the addon uses, loads the addon
-- files in TOC order, and exercises commands. Run from the repo root:  lua5.1 tests/run.lua
local ADDON = "LaParoleDuSeigneur"
local DIR = ADDON .. "/"

---------------------------------------------------------------------------
-- Fake game state and API
---------------------------------------------------------------------------
local state = {
    locale = "frFR", inGuild = true, inGroup = false, inRaid = false, inInstanceGroup = false,
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
C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "0.1.0" or nil end }
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

fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")

test("globals and slash commands registered", function()
    eq(type(slash), "function")
    eq(SLASH_LAPAROLEDUSEIGNEUR1, "/parole")
    eq(type(LaParoleDuSeigneurDB), "table")
    eq(LaParoleDuSeigneurDB.channel, "SAY")
end)

test("/parole preaches a French saying on /say", function()
    slash("")
    eq(#sent, 1)
    eq(sent[1].chatType, "SAY")
    assert(sent[1].msg:find("^« ") and sent[1].msg:find(" — "), sent[1].msg)
end)

test("shuffle bag: no repeats before the pool is exhausted", function()
    local seen, n = {}, #ns.sayings.fr
    ns.ResetBag()
    for _ = 1, n do slash("") end
    -- crossing into the next round must not repeat the last saying
    local last = sent[#sent].msg
    slash("")
    assert(sent[#sent].msg ~= last, "immediate repeat across rounds")
    sent[#sent] = nil
    eq(#sent, n)
    for _, s in ipairs(sent) do
        assert(not seen[s.msg], "repeat: " .. s.msg)
        seen[s.msg] = true
    end
end)

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
    slash("groupe")
    eq(#sent, 0)
    assert(printedContains("pas en groupe"))
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
    slash("ajouter Pour la Horde | et pour le Seigneur")
    eq(#LaParoleDuSeigneurDB.custom, 1)
    eq(LaParoleDuSeigneurDB.custom[1], "Pour la Horde / et pour le Seigneur")
    slash("liste")
    assert(printedContains("1. Pour la Horde"))
    slash("retirer 1")
    eq(#LaParoleDuSeigneurDB.custom, 0)
    slash("retirer 9")
    assert(printedContains("invalide"))
end)

test("builtin off + only custom sayings", function()
    slash("integrees")
    eq(LaParoleDuSeigneurDB.useBuiltin, false)
    slash("")
    assert(printedContains("Aucune parole"))
    slash("add Ma parole")
    slash("")
    eq(sent[#sent].msg, "« Ma parole »")
    slash("remove 1")
    slash("builtin")
    eq(LaParoleDuSeigneurDB.useBuiltin, true)
end)

test("long messages split under 255 bytes on word boundaries, UTF-8 safe", function()
    local long = string.rep("épée lumière ", 60)
    slash("add " .. long)
    slash("integrees")
    slash("guilde")
    assert(#sent >= 2, "expected several chunks, got " .. #sent)
    for _, s in ipairs(sent) do
        assert(#s.msg <= 255)
        assert(not s.msg:find("^%s") and not s.msg:find("%s$"))
    end
    slash("integrees")
    slash("retirer 1")
    -- giant single word gets hard-cut without breaking a 2-byte character
    local chunks = ns.SplitMessage(string.rep("é", 300))
    for _, c in ipairs(chunks) do
        assert(#c <= 255 and #c % 2 == 0, "split inside a character")
    end
end)

test("auto-preach: ticker, minimum, channel, combat skip, off", function()
    slash("auto 1 groupe")
    assert(printedContains("minimal"))
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
    slash("auto 5 dire")
    local t = tickers[#tickers]
    t.fn()
    eq(#sent, 0)
    assert(printedContains("exige un clic"))
    state.inInstance = true
    t.fn()
    eq(sent[#sent].chatType, "SAY")
    state.inInstance = false
    slash("auto off")
end)

test("reactions: death and revive in group", function()
    slash("reactions")
    eq(LaParoleDuSeigneurDB.reactions, true)
    state.inGroup = true
    state.dead = true
    fire("PLAYER_DEAD")
    assert(sent[#sent].msg:find("Luc 23:34"), "death saying")
    fire("PLAYER_ALIVE")  -- released to ghost: still dead, no revive message
    local before = #sent
    eq(#sent, before)
    state.dead = false
    fire("PLAYER_UNGHOST")
    assert(sent[#sent].msg:find("Jean 11:25"), "revive saying")
    fire("PLAYER_ALIVE")  -- must not fire twice
    eq(#sent, before + 1)
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
    slash("bouton")
    eq(btn.shown, false)
    slash("bouton")
    eq(btn.shown, true)
    slash("canal dire")
end)

test("addon compartment click works", function()
    LaParoleDuSeigneur_OnAddonCompartmentClick(ADDON, "LeftButton")
    eq(#sent, 1)
end)

test("English: language switch, quotes and help", function()
    slash("lang en")
    slash("")
    assert(sent[#sent].msg:find('^"') and sent[#sent].msg:find("— %a+ %d+:%d+$"), sent[#sent].msg)
    slash("help")
    assert(printedContains("/parole add"))
    slash("langue auto")
end)

test("reset keeps custom sayings", function()
    slash("add garde-moi")
    slash("canal guilde")
    slash("reset")
    eq(LaParoleDuSeigneurDB.channel, "SAY")
    eq(#LaParoleDuSeigneurDB.custom, 1)
    slash("retirer 1")
end)

test("unknown word shows help", function()
    slash("banane")
    assert(printedContains("/parole aide") or printedContains("/parole ajouter"))
end)

test("every built-in saying fits and has a reference", function()
    for lang, list in pairs(ns.sayings) do
        eq(#list, #ns.sayings.fr, lang .. " list length")
        for _, e in ipairs(list) do
            assert(e[2] and e[2] ~= "", "missing reference")
            assert(not e[1]:find("|", 1, true))
        end
    end
    for _, refs in pairs(ns.reactionRefs) do
        for lang, ref in pairs(refs) do
            state.locale = (lang == "fr") and "frFR" or "enUS"
            assert(ns.FindSayingByRef(ref), "reaction ref not found: " .. ref)
        end
    end
    state.locale = "frFR"
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
