-- Interface strings. The language follows the "lang" setting (auto = client locale).
local _, ns = ...

local strings = {
    fr = {
        PREFIX = "|cffffd100Words of the Lord|r",
        LOADED = "chargé (v%s). Tapez |cffffff00/parole aide|r pour les commandes.",
        NO_SAYINGS = "Aucune parole à prêcher. Ajoutez-en avec /parole ajouter <texte>.",
        NOT_IN_GUILD = "Vous n'êtes pas dans une guilde, la parole reste avec vous :",
        NOT_IN_GROUP = "Vous n'êtes pas en groupe, la parole reste avec vous :",
        NEEDS_CLICK = "Le canal « %s » exige un clic ou une commande tapée; le prêche automatique vous l'affiche seulement :",
        COMBAT_SKIP = "En combat : prêche automatique reporté.",
        CHANNEL_SET = "Canal par défaut : %s",
        CHANNEL_UNKNOWN = "Canal inconnu : « %s ». Choix : dire, crier, emote, groupe, raid, guilde, moi.",
        ADDED = "Parole ajoutée (n° %d).",
        REMOVED = "Parole retirée : %s",
        BAD_INDEX = "Numéro invalide. Voyez /parole liste.",
        LIST_HEADER = "Vos paroles personnelles :",
        LIST_EMPTY = "Aucune parole personnelle. Ajoutez-en avec /parole ajouter <texte>.",
        LIST_BUILTIN = "Plus %d paroles intégrées (%s).",
        BUILTIN_ON = "Paroles intégrées : activées",
        BUILTIN_OFF = "Paroles intégrées : désactivées (seulement les vôtres)",
        AUTO_ON = "Prêche automatique toutes les %d minutes sur « %s ».",
        AUTO_OFF = "Prêche automatique désactivé.",
        AUTO_MIN = "Intervalle minimal : %d minutes.",
        BUTTON_SHOWN = "Bouton affiché.",
        BUTTON_HIDDEN = "Bouton masqué. /parole bouton pour le réafficher.",
        LOCKED = "Bouton verrouillé.",
        UNLOCKED = "Bouton déverrouillé (glisser pour déplacer).",
        REACTIONS_ON = "Réactions activées (mort et résurrection, dans le groupe).",
        REACTIONS_OFF = "Réactions désactivées.",
        LANG_SET = "Langue : %s",
        RESET_DONE = "Réglages remis à zéro (vos paroles sont conservées).",
        FAV_ADDED = "Favori ajouté : %s",
        FAV_REMOVED = "Favori retiré : %s",
        FAV_NOT_FOUND = "Parole introuvable : « %s ». Utilisez la référence, par exemple Jean 3:16.",
        FAV_LIST_HEADER = "Vos favoris (tirés %dx plus souvent) :",
        FAV_LIST_EMPTY = "Aucun favori. /parole favori <référence> pour en ajouter.",
        EXCLUDED_ON = "Parole exclue : %s",
        EXCLUDED_OFF = "Parole réintégrée : %s",
        WEIGHT_SET = "Les favoris sont tirés %dx plus souvent.",
        WEIGHT_BAD = "Choisissez un nombre de 1 à 5.",
        CAT_ON = "Catégorie activée : %s",
        CAT_OFF = "Catégorie désactivée : %s",
        CAT_UNKNOWN = "Catégorie inconnue : « %s ».",
        CAT_LIST = "Catégories : %s",
        QUEBEC_NEEDS_QC = "Les paroles du Québec n'apparaissent qu'en mode Québec (/parole langue qc).",
        LANG_MIGRATED = "Langue par défaut : anglais. Changez-la avec /parole langue fr, qc ou en.",
        QC_SHARE_SET = "Mode Québec : %d %% de paroles du Québec, %d %% de versets et de vos paroles.",
        QC_SHARE_INFO = "Mode Québec : %d %% de paroles du Québec. Changez-le avec /parole quebec <0-100>.",
        QC_SHARE_BAD = "Choisissez un nombre de 0 à 100.",
        TOOLTIP_TITLE = "Words of the Lord",
        TOOLTIP_LEFT = "Clic gauche : prêcher sur « %s »",
        TOOLTIP_RIGHT = "Clic droit : changer de canal",
        TOOLTIP_DRAG = "Glisser : déplacer le bouton",
        HELP = {
            "|cffffff00/parole|r : prêcher sur le canal par défaut",
            "|cffffff00/parole <canal>|r : prêcher une fois sur dire, crier, emote, groupe, raid, guilde ou moi",
            "|cffffff00/parole canal <canal>|r : changer le canal par défaut",
            "|cffffff00/parole ajouter <texte>|r : ajouter votre propre parole",
            "|cffffff00/parole liste|r  |cffffff00/parole retirer <n°>|r : gérer vos paroles",
            "|cffffff00/parole integrees|r : activer ou non les paroles intégrées",
            "|cffffff00/parole auto <minutes>|r  |cffffff00/parole auto off|r : prêche automatique",
            "|cffffff00/parole bouton|r  |cffffff00/parole verrou|r : afficher ou verrouiller le bouton",
            "|cffffff00/parole reactions|r : paroles à la mort et à la résurrection",
            "|cffffff00/parole favori <référence>|r  |cffffff00/parole favoris|r : favoris, tirés plus souvent",
            "|cffffff00/parole poids <1-5>|r  |cffffff00/parole exclure <référence>|r  |cffffff00/parole categorie <nom>|r",
            "|cffffff00/parole quebec <0-100>|r : part de paroles du Québec en mode Québec",
            "|cffffff00/parole langue en/fr/qc|r  |cffffff00/parole reset|r",
        },
        CHANNELS = {
            SAY = "dire", YELL = "crier", EMOTE = "emote", GROUP = "groupe",
            RAID = "raid", GUILD = "guilde", SELF = "moi",
        },
    },
    en = {
        PREFIX = "|cffffd100Words of the Lord|r",
        LOADED = "loaded (v%s). Type |cffffff00/parole help|r for commands.",
        NO_SAYINGS = "No sayings to preach. Add some with /parole add <text>.",
        NOT_IN_GUILD = "You are not in a guild, so the word stays with you:",
        NOT_IN_GROUP = "You are not in a group, so the word stays with you:",
        NEEDS_CLICK = "The \"%s\" channel needs a click or a typed command; auto-preach only shows it to you:",
        COMBAT_SKIP = "In combat: auto-preach postponed.",
        CHANNEL_SET = "Default channel: %s",
        CHANNEL_UNKNOWN = "Unknown channel: \"%s\". Choices: say, yell, emote, group, raid, guild, self.",
        ADDED = "Saying added (#%d).",
        REMOVED = "Saying removed: %s",
        BAD_INDEX = "Invalid number. See /parole list.",
        LIST_HEADER = "Your own sayings:",
        LIST_EMPTY = "No sayings of your own. Add some with /parole add <text>.",
        LIST_BUILTIN = "Plus %d built-in sayings (%s).",
        BUILTIN_ON = "Built-in sayings: on",
        BUILTIN_OFF = "Built-in sayings: off (only yours)",
        AUTO_ON = "Auto-preach every %d minutes on \"%s\".",
        AUTO_OFF = "Auto-preach turned off.",
        AUTO_MIN = "Minimum interval: %d minutes.",
        BUTTON_SHOWN = "Button shown.",
        BUTTON_HIDDEN = "Button hidden. /parole button to show it again.",
        LOCKED = "Button locked.",
        UNLOCKED = "Button unlocked (drag to move).",
        REACTIONS_ON = "Reactions on (death and resurrection, in your group).",
        REACTIONS_OFF = "Reactions off.",
        LANG_SET = "Language: %s",
        RESET_DONE = "Settings reset (your sayings are kept).",
        FAV_ADDED = "Favorite added: %s",
        FAV_REMOVED = "Favorite removed: %s",
        FAV_NOT_FOUND = "Saying not found: \"%s\". Use the reference, for example John 3:16.",
        FAV_LIST_HEADER = "Your favorites (picked %dx more often):",
        FAV_LIST_EMPTY = "No favorites yet. /parole fav <reference> to add one.",
        EXCLUDED_ON = "Saying excluded: %s",
        EXCLUDED_OFF = "Saying included again: %s",
        WEIGHT_SET = "Favorites are picked %dx more often.",
        WEIGHT_BAD = "Choose a number from 1 to 5.",
        CAT_ON = "Category on: %s",
        CAT_OFF = "Category off: %s",
        CAT_UNKNOWN = "Unknown category: \"%s\".",
        CAT_LIST = "Categories: %s",
        QUEBEC_NEEDS_QC = "Québec sayings only appear in Québec mode (/parole lang qc).",
        LANG_MIGRATED = "Default language is now English. Change it with /parole lang fr, qc or en.",
        QC_SHARE_SET = "Québec mode: %d%% Québec sayings, %d%% verses and your own.",
        QC_SHARE_INFO = "Québec mode: %d%% Québec sayings. Change it with /parole quebec <0-100>.",
        QC_SHARE_BAD = "Choose a number from 0 to 100.",
        TOOLTIP_TITLE = "Words of the Lord",
        TOOLTIP_LEFT = "Left-click: preach on \"%s\"",
        TOOLTIP_RIGHT = "Right-click: change channel",
        TOOLTIP_DRAG = "Drag: move the button",
        HELP = {
            "|cffffff00/parole|r: preach on the default channel",
            "|cffffff00/parole <channel>|r: preach once on say, yell, emote, group, raid, guild or self",
            "|cffffff00/parole channel <channel>|r: change the default channel",
            "|cffffff00/parole add <text>|r: add a saying of your own",
            "|cffffff00/parole list|r  |cffffff00/parole remove <#>|r: manage your sayings",
            "|cffffff00/parole builtin|r: turn the built-in sayings on or off",
            "|cffffff00/parole auto <minutes>|r  |cffffff00/parole auto off|r: auto-preach",
            "|cffffff00/parole button|r  |cffffff00/parole lock|r: show or lock the button",
            "|cffffff00/parole reactions|r: sayings on death and resurrection",
            "|cffffff00/parole fav <reference>|r  |cffffff00/parole favs|r: favorites, picked more often",
            "|cffffff00/parole weight <1-5>|r  |cffffff00/parole exclude <reference>|r  |cffffff00/parole category <name>|r",
            "|cffffff00/parole quebec <0-100>|r: share of Québec sayings in Québec mode",
            "|cffffff00/parole lang en/fr/qc|r  |cffffff00/parole reset|r",
        },
        CHANNELS = {
            SAY = "say", YELL = "yell", EMOTE = "emote", GROUP = "group",
            RAID = "raid", GUILD = "guild", SELF = "self",
        },
    },
}

ns.strings = strings

-- Sayings language mode: "en" (default), "fr" or "qc" (French library plus Quebec sayings).
function ns.GetLang()
    local setting = ns.db and ns.db.lang
    if setting == "fr" or setting == "qc" then
        return setting
    end
    return "en"
end

-- Interface language: English, or French for both "fr" and "qc".
function ns.UILang()
    return (ns.GetLang() == "en") and "en" or "fr"
end

-- ns.L.KEY always reads from the current interface language, falling back to English.
ns.L = setmetatable({}, {
    __index = function(_, key)
        local value = strings[ns.UILang()][key]
        if value == nil then
            value = strings.en[key]
        end
        return value
    end,
})
