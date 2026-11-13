# Words of the Lord

A World of Warcraft: Forever addon that preaches the Lord's sayings in chat.
*Un addon pour World of Warcraft: Forever qui prêche les paroles du Seigneur dans le chat.*

- **124 built-in sayings**: 78 Bible verses (Louis Segond 1910 in French, King James in English, both public domain) and 46 traditional Catholic sayings, prayers and dictons from Quebec
- **Three languages**: English (default), Français, and Québec (the full French library plus the Québec sayings)
- **Favorites** are picked more often (3 times by default, adjustable from 1 to 5), and you can exclude sayings or turn whole categories off
- **The book**: one tabbed window styled as an open book, with ribbon tabs for the Library (search, category filters, a diamond to mark favorites), Favorites, Settings and My sayings. Open it with `/parole book`, Shift-click on the button, or a click on the addon's entry in the minimap addon list
- **The interface follows the game's language**: French on a French client, English on every other client
- Add your own sayings in game
- One-click button (left-click preaches, Shift-click opens the book, right-click changes channel, drag to move)
- Say, yell, emote, group (party/raid/instance picked automatically), raid, guild, or only yourself
- Optional auto-preach every N minutes (2 minutes minimum, paused in combat)
- Optional reactions: a saying to your group when you die and when you come back
- The same saying never comes up twice in a row
- Long sayings are split cleanly under WoW's 255-byte chat limit

## Install

Copy the `WordsOfTheLord` folder (the one with the `.toc` inside) into:

```
World of Warcraft\_forever_\Interface\AddOns\
```

You should end up with `...\AddOns\WordsOfTheLord\WordsOfTheLord.toc`. Then `/reload` or restart the game.

### While developing

Link the folder instead of copying it, so every save is live after `/reload`:

```bat
:: Windows (Command Prompt as administrator)
mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WordsOfTheLord" "C:\path\to\Words-of-the-Lord\WordsOfTheLord"
```

```sh
# macOS
ln -s ~/path/to/Words-of-the-Lord/WordsOfTheLord "/Applications/World of Warcraft/_forever_/Interface/AddOns/WordsOfTheLord"
```

Turn on Lua error display in game with `/console scriptErrors 1`.

## Languages

| Mode | Command | Sayings |
|---|---|---|
| English (default) | `/parole lang en` | English Bible verses (KJV) |
| Français | `/parole langue fr` | French Bible verses (Louis Segond 1910) |
| Québec | `/parole langue qc` | 46 Quebec Catholic sayings, with the French verses mixed in (70% Québec by default) |

This only chooses the language of the **sayings**. The interface (the book, messages, help) always follows the
game client: a French client gets French, every other client gets English.

New installs always start with English sayings, whatever the game client's language. Upgrading from 0.1.0 also
switches you to English once (with a message), unless you had picked French yourself.

In Québec mode, **70% of the sayings come from the Québec list** and 30% from the French verses and your own
sayings. Change it with `/parole quebec <0-100>`: 100 means Québec sayings only, 0 means verses only.
Favorites, exclusions and categories still apply, and the same saying never repeats right away.

The Québec sayings are traditional expressions, prayers and dictons: everyday sayings ("Offre ça au bon Dieu",
"Que le bon Dieu vous le rende"), prayers in their older wordings (Notre Père, Je vous salue Marie, the Angélus,
the Sign of the Cross, the Bénédicité), invocations to Sainte Anne, and weather dictons tied to saints' days.
Their "reference" is a label such as *Dicton populaire* or *Angélus*, not an author. Most are shared with the rest
of the French-speaking Catholic world; they are the ones Quebec Catholic culture kept alive, not all invented there.

## Commands

`/parole` or `/wotl`. Each command works in French or English.

| Command | What it does |
|---|---|
| `/parole` | Preach on the default channel |
| `/parole livre` / `book` | Open or close the book (library, favorites, settings, your own sayings) |
| `/parole guilde` (or `dire`, `crier`, `emote`, `groupe`, `raid`, `moi`) | Preach once on that channel |
| `/parole canal <channel>` / `channel` | Change the default channel |
| `/parole langue en`, `fr` or `qc` / `lang` | Choose the language mode |
| `/parole quebec 70` | Share of Québec sayings in Québec mode (0-100, default 70) |
| `/parole favori Jean 3:16` / `fav John 3:16` | Add or remove a favorite, by reference |
| `/parole favoris` / `favs` | List your favorites |
| `/parole poids 1-5` / `weight` | How much more often favorites come up (default 3) |
| `/parole exclure <reference>` / `exclude` | Never preach this saying (toggle) |
| `/parole categorie` / `category` | List categories; add a name to turn one on or off |
| `/parole ajouter <text>` / `add` | Add your own saying |
| `/parole liste` / `list` | List your own sayings |
| `/parole retirer <#>` / `remove` | Remove one of your own sayings |
| `/parole integrees` / `builtin` | Built-in sayings on/off (keep only yours) |
| `/parole auto 15 guilde` | Auto-preach every 15 minutes on guild chat |
| `/parole auto off` | Stop auto-preach |
| `/parole bouton` / `button` | Show/hide the button |
| `/parole verrou` / `lock` | Lock/unlock the button's position |
| `/parole reactions` | Sayings on death and resurrection (group only) |
| `/parole reset` | Reset settings to defaults (your sayings, favorites and exclusions are kept) |

Categories: Words of Jesus, Proverbs, Psalms, Ecclesiastes, Other scripture, Québec.
The Québec share only applies in Québec mode; if the Québec category is turned off, only verses are used.
Favorites and exclusions are saved by saying, so they stay when you switch language.

An in-game settings screen and library browser are planned for the next version.

## Good to know

- **Say, yell and emote need a click.** Outside instances, Blizzard only lets addons talk in /say, /yell and /emote right after a click or a typed command. The button and slash commands work everywhere. Auto-preach and reactions on those channels just show the saying to you, so use guild or group for automatic messages.
- **Don't spam.** Repeated automated messages can get you reported or silenced. Keep the auto-preach interval reasonable.
- Settings are saved per account in `WTF\Account\<ACCOUNT>\SavedVariables\WordsOfTheLord.lua`.

## Project layout

```
WordsOfTheLord/
  WordsOfTheLord.toc   addon metadata (Interface 16001 = WoW Forever 1.60.1)
  Locales.lua              interface text, French and English; language modes
  Sayings.lua              the sayings library (generated, see tools/)
  Core.lua                 settings, migration, picking (favorites, weights), sending, auto-preach, reactions
  Button.lua               the draggable button
  Commands.lua             slash commands
tools/                     regenerate Sayings.lua from the public-domain Bible texts (see tools/README.md)
tests/run.lua              offline tests with a fake WoW API: lua5.1 tests/run.lua
.pkgmeta                   packaging config for CurseForge / Wago
```

When Blizzard patches Forever, check the new interface number in game with
`/dump select(4, GetBuildInfo())` and update `## Interface:` in the `.toc`.
