# La parole du seigneur

A World of Warcraft: Forever addon that preaches the Lord's sayings in chat.
*Un addon pour World of Warcraft: Forever qui prêche les paroles du Seigneur dans le chat.*

- 26 built-in sayings of Jesus, in French (Louis Segond 1910) or English (King James), both public domain
- Add your own sayings in-game
- One-click button (left-click preaches, right-click changes channel, drag to move)
- Say, yell, emote, group (party/raid/instance picked automatically), raid, guild, or only yourself
- Optional auto-preach every N minutes (2 minutes minimum, paused in combat)
- Optional reactions: a saying to your group when you die and when you come back
- No repeats until every saying has been preached once
- Long sayings are split cleanly under WoW's 255-byte chat limit

## Install

Copy the `LaParoleDuSeigneur` folder (the one with the `.toc` inside) into:

```
World of Warcraft\_forever_\Interface\AddOns\
```

You should end up with `...\AddOns\LaParoleDuSeigneur\LaParoleDuSeigneur.toc`. Then `/reload` or restart the game.

### While developing

Link the folder instead of copying it, so every save is live after `/reload`:

```bat
:: Windows (Command Prompt as administrator)
mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\LaParoleDuSeigneur" "C:\path\to\La-parole-du-seigneur\LaParoleDuSeigneur"
```

```sh
# macOS
ln -s ~/path/to/La-parole-du-seigneur/LaParoleDuSeigneur "/Applications/World of Warcraft/_forever_/Interface/AddOns/LaParoleDuSeigneur"
```

Turn on Lua error display in game with `/console scriptErrors 1`.

## Commands

`/parole` or `/lps`. Each command works in French or English.

| Command | What it does |
|---|---|
| `/parole` | Preach on the default channel |
| `/parole guilde` (or `dire`, `crier`, `emote`, `groupe`, `raid`, `moi`) | Preach once on that channel |
| `/parole canal <channel>` / `channel` | Change the default channel |
| `/parole ajouter <text>` / `add` | Add your own saying |
| `/parole liste` / `list` | List your sayings |
| `/parole retirer <#>` / `remove` | Remove one of your sayings |
| `/parole integrees` / `builtin` | Built-in sayings on/off (keep only yours) |
| `/parole auto 15 guilde` | Auto-preach every 15 minutes on guild chat |
| `/parole auto off` | Stop auto-preach |
| `/parole bouton` / `button` | Show/hide the button |
| `/parole verrou` / `lock` | Lock/unlock the button's position |
| `/parole reactions` | Sayings on death and resurrection (group only) |
| `/parole langue fr` / `lang en` / `auto` | Language of the sayings and messages |
| `/parole reset` | Reset settings (your sayings are kept) |

## Good to know

- **Say, yell and emote need a click.** Outside instances, Blizzard only lets addons talk in /say, /yell and /emote right after a click or a typed command. The button and slash commands work everywhere. Auto-preach and reactions on those channels just show the saying to you, so use guild or group for automatic messages.
- **Don't spam.** Repeated automated messages can get you reported or silenced. Keep the auto-preach interval reasonable.
- Settings are saved per account in `WTF\Account\<ACCOUNT>\SavedVariables\LaParoleDuSeigneur.lua`.

## Project layout

```
LaParoleDuSeigneur/
  LaParoleDuSeigneur.toc   addon metadata (Interface 16001 = WoW Forever 1.60.1)
  Locales.lua              interface text, French and English
  Sayings.lua              the built-in sayings (edit freely)
  Core.lua                 settings, picking and sending sayings, auto-preach, reactions
  Button.lua               the draggable button
  Commands.lua             slash commands
tests/run.lua              offline tests with a fake WoW API: lua5.1 tests/run.lua
.pkgmeta                   packaging config for CurseForge / Wago
```

When Blizzard patches Forever, check the new interface number in game with
`/dump select(4, GetBuildInfo())` and update `## Interface:` in the `.toc`.
