-- Slash commands: /parole and /wotl. Every subcommand has a French and an English name.
local _, ns = ...
local L = ns.L

local function toggle(key, onMsg, offMsg)
    ns.db[key] = not ns.db[key]
    ns.Print(ns.db[key] and onMsg or offMsg)
end

local function preview(text, maxLen)
    maxLen = maxLen or 60
    if #text > maxLen then
        return text:sub(1, maxLen) .. "…"
    end
    return text
end

local commands = {}

commands.help = function()
    for _, line in ipairs(L.HELP) do
        ns.Print(line)
    end
end

commands.channel = function(rest)
    local channel = ns.ParseChannel(rest)
    if not channel then
        ns.Print(L.CHANNEL_UNKNOWN:format(rest or ""))
        return
    end
    ns.db.channel = channel
    ns.Print(L.CHANNEL_SET:format(ns.ChannelLabel(channel)))
end

commands.add = function(rest)
    local text = ns.Sanitize(rest)
    if text == "" then
        commands.help()
        return
    end
    table.insert(ns.db.custom, text)
    ns.Print(L.ADDED:format(#ns.db.custom))
end

commands.list = function()
    if #ns.db.custom == 0 then
        ns.Print(L.LIST_EMPTY)
    else
        ns.Print(L.LIST_HEADER)
        for i, text in ipairs(ns.db.custom) do
            ns.Print(("%d. %s"):format(i, preview(text, 120)))
        end
    end
    ns.Print(L.LIST_BUILTIN:format(#ns.GetLibrary(), ns.db.useBuiltin and "on" or "off"))
end

commands.remove = function(rest)
    local index = tonumber(rest)
    if not index or not ns.db.custom[index] then
        ns.Print(L.BAD_INDEX)
        return
    end
    local removed = table.remove(ns.db.custom, index)
    ns.Print(L.REMOVED:format(preview(removed)))
end

commands.builtin = function()
    toggle("useBuiltin", L.BUILTIN_ON, L.BUILTIN_OFF)
end

-- /parole auto 15        -> every 15 minutes on the current auto channel
-- /parole auto 15 groupe -> every 15 minutes on group chat
-- /parole auto off
commands.auto = function(rest)
    local first, second = (rest or ""):match("^(%S*)%s*(%S*)")
    first = first:lower()
    if first == "off" or first == "non" or first == "stop" then
        ns.db.autoEnabled = false
        ns.UpdateAutoPreach()
        ns.Print(L.AUTO_OFF)
        return
    end
    local minutes = tonumber(first)
    local channel = ns.ParseChannel(second) or ns.ParseChannel(first)
    if channel then
        ns.db.autoChannel = channel
    end
    if minutes then
        if minutes < ns.AUTO_MIN_MINUTES then
            ns.Print(L.AUTO_MIN:format(ns.AUTO_MIN_MINUTES))
        end
        ns.db.autoMinutes = math.max(ns.AUTO_MIN_MINUTES, math.floor(minutes))
    end
    -- Bare "/parole auto" toggles; anything else turns it on with the new values.
    if first == "" then
        ns.db.autoEnabled = not ns.db.autoEnabled
    else
        ns.db.autoEnabled = true
    end
    ns.UpdateAutoPreach()
    if ns.db.autoEnabled then
        ns.Print(L.AUTO_ON:format(ns.db.autoMinutes, ns.ChannelLabel(ns.db.autoChannel)))
    else
        ns.Print(L.AUTO_OFF)
    end
end

commands.button = function()
    ns.db.button.shown = not ns.db.button.shown
    ns.UpdateButton()
    ns.Print(ns.db.button.shown and L.BUTTON_SHOWN or L.BUTTON_HIDDEN)
end

commands.lock = function()
    ns.db.button.locked = not ns.db.button.locked
    ns.Print(ns.db.button.locked and L.LOCKED or L.UNLOCKED)
end

commands.reactions = function()
    toggle("reactions", L.REACTIONS_ON, L.REACTIONS_OFF)
end

commands.lang = function(rest)
    rest = (rest or ""):lower()
    local aliases = { en = "en", english = "en", anglais = "en", fr = "fr", ["français"] = "fr", francais = "fr",
                      qc = "qc", quebec = "qc", ["québec"] = "qc" }
    local choice = aliases[rest]
    if not choice then
        -- No valid name: step through English, French, Québec.
        local order = { en = "fr", fr = "qc", qc = "en" }
        choice = order[ns.GetLang()]
    end
    ns.db.lang = choice
    ns.ResetBag()
    ns.Print(L.LANG_SET:format(({ en = "English", fr = "Français", qc = "Québec" })[choice]))
end

-- Find a saying from a typed reference, or print why not.
local function findByRef(rest)
    local shown = ns.FindSayingByRef(rest)
    if not shown then
        if ns.db.lang ~= "qc" and rest and rest:lower():find("^qu") then
            ns.Print(L.QUEBEC_NEEDS_QC)
        else
            ns.Print(L.FAV_NOT_FOUND:format(rest or ""))
        end
    end
    return shown
end

commands.fav = function(rest)
    local shown = findByRef(rest)
    if not shown then return end
    if ns.ToggleFavorite(shown.id) then
        ns.Print(L.FAV_ADDED:format(shown.ref))
    else
        ns.Print(L.FAV_REMOVED:format(shown.ref))
    end
end

commands.favs = function()
    local names = {}
    for _, shown in ipairs(ns.GetLibrary()) do
        if shown.favorite then
            names[#names + 1] = shown.ref .. " — " .. preview(shown.text, 50)
        end
    end
    if #names == 0 then
        ns.Print(L.FAV_LIST_EMPTY)
        return
    end
    ns.Print(L.FAV_LIST_HEADER:format(ns.FavoriteWeight()))
    for _, line in ipairs(names) do
        ns.Print(line)
    end
end

commands.exclude = function(rest)
    local shown = findByRef(rest)
    if not shown then return end
    if ns.ToggleExcluded(shown.id) then
        ns.Print(L.EXCLUDED_ON:format(shown.ref))
    else
        ns.Print(L.EXCLUDED_OFF:format(shown.ref))
    end
end

commands.weight = function(rest)
    local n = tonumber(rest)
    if not n or n < 1 or n > 5 then
        ns.Print(L.WEIGHT_BAD)
        return
    end
    ns.db.favoriteWeight = math.floor(n)
    ns.Print(L.WEIGHT_SET:format(ns.db.favoriteWeight))
end

-- /parole category            -> list categories and whether each is on
-- /parole category proverbes  -> toggle one
commands.category = function(rest)
    if not rest or rest == "" then
        local parts = {}
        for _, category in ipairs(ns.CATEGORIES) do
            local name = category[ns.UILang()]
            parts[#parts + 1] = (ns.CategoryEnabled(category.key) and "+" or "-") .. name
        end
        ns.Print(L.CAT_LIST:format(table.concat(parts, ", ")))
        return
    end
    local category = ns.FindCategory(rest)
    if not category then
        ns.Print(L.CAT_UNKNOWN:format(rest))
        return
    end
    local enable = not ns.CategoryEnabled(category.key)
    ns.SetCategory(category.key, enable)
    ns.Print((enable and L.CAT_ON or L.CAT_OFF):format(category[ns.UILang()]))
end

-- /parole quebec       -> show the share of Québec sayings in Québec mode
-- /parole quebec 70    -> set it (0 = verses only, 100 = Québec sayings only)
commands.quebec = function(rest)
    if not rest or rest == "" then
        ns.Print(L.QC_SHARE_INFO:format(ns.QuebecShare()))
        return
    end
    local n = tonumber(rest)
    if not n or n < 0 or n > 100 then
        ns.Print(L.QC_SHARE_BAD)
        return
    end
    ns.db.quebecShare = math.floor(n)
    ns.Print(L.QC_SHARE_SET:format(ns.db.quebecShare, 100 - ns.db.quebecShare))
end

commands.reset = function()
    ns.ResetSettings()
    ns.UpdateButton()
    ns.UpdateAutoPreach()
    ns.Print(L.RESET_DONE)
end

-- French and English names for each subcommand.
local aliases = {
    aide = "help", help = "help", ["?"] = "help",
    canal = "channel", channel = "channel",
    ajouter = "add", add = "add",
    liste = "list", list = "list",
    retirer = "remove", remove = "remove", supprimer = "remove", del = "remove",
    integrees = "builtin", ["intégrées"] = "builtin", builtin = "builtin",
    auto = "auto",
    bouton = "button", button = "button",
    verrou = "lock", lock = "lock",
    reactions = "reactions", ["réactions"] = "reactions",
    langue = "lang", lang = "lang", language = "lang",
    favori = "fav", fav = "fav", favorite = "fav",
    favoris = "favs", favs = "favs", favorites = "favs",
    exclure = "exclude", exclude = "exclude",
    poids = "weight", weight = "weight",
    categorie = "category", ["catégorie"] = "category", category = "category",
    categories = "category", ["catégories"] = "category",
    quebec = "quebec", ["québec"] = "quebec", qc = "quebec",
    reset = "reset",
}

function ns.HandleSlash(input)
    input = input or ""
    local word, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
    word = (word or ""):lower()

    if word == "" then
        ns.Preach()
        return
    end

    local name = aliases[word]
    if name then
        commands[name](rest)
        return
    end

    -- "/parole guilde" preaches once on that channel without changing the default.
    local channel = ns.ParseChannel(word)
    if channel then
        ns.Preach(channel)
        return
    end

    commands.help()
end

SLASH_WORDSOFTHELORD1 = "/parole"
SLASH_WORDSOFTHELORD2 = "/wotl"
SlashCmdList.WORDSOFTHELORD = ns.HandleSlash
