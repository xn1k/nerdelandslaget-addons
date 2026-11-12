# Nerdelandslaget addon suite (WoW Forever)

Addons for the Nerdelandslaget podcast community and the guilds `<Nerdelandslaget>` and `<Nerdelandslaget II>`.

| Folder | What it is |
|---|---|
| `Nerdelandslaget/` | The suite core: events, debug log, guild check, the hidden addon channel (`Comm.lua`), the look (`Theme.lua`, `Widgets.lua`), pop-ups above the chat (`Toast.lua`), the NL emblem minimap button, and the options page with the wordmark. Modules reach it through the global `Nerdelandslaget`. |
| `Nerdelandslaget_LFG/` | The Dungeon Finder. You can sign up for several dungeons with any roles, start a group with a level range, ask to join, and invite or whisper with one click. |
| `art/` | Source art: `role-icons.png`, the tank / healer / damage icons (made with Nano Banana 2.1 on fal.ai, the emblem as style reference). |
| `tools/` | `build_media.py` (logos and role icons to `Nerdelandslaget/Media`), `wowmock.lua` + `smoke.py` (an offline test). |

Both addon folders are linked into `_forever_\Interface\AddOns` with directory junctions, so edits here go live after `/reload`.

## In game

- `/nl` opens the Dungeon Finder. Left-click the minimap emblem does the same, and right-click it for a menu.
- `/nl lfg demo` fills the finder with made-up listings, so you can try the UI alone.
- Pop-ups: a new group for your level, a level range, or dungeons you pick (Browse > Pop-ups) pops up above the chat; click it to jump to the group, or Ask to join right on it. A leader gets one with Invite and Whisper when someone asks to join. `/nl lfg test` shows a sample; drag one to move them.
- `/nl options`, `/nl button` (show or hide the minimap button), `/nl probe` (logs which APIs this client has), `/nl debug`.

## How it talks

GUILD addon messages only reach your own guild, so both guilds share a hidden channel, `NerdelandslagetAddon`. The channel never shows in chat. If it can't be joined, messages fall back to GUILD. The protocol is documented at the top of `Nerdelandslaget_LFG/Core.lua` (prefix `NLLFG1`). Dungeon ids in `Dungeons.lua` travel in messages, so never renumber them.

## Development

```
python tools/build_media.py                         # after changing the logos or role icons
pip install --target tools/.pylib lupa              # once
python -I tools/smoke.py tools/.pylib               # offline smoke test
python <skill>/scripts/lint_addon.py Nerdelandslaget_LFG
```

Debug log: `_forever_\WTF\Account\<id>\SavedVariables\Nerdelandslaget.lua` (`log`), written on `/reload` or logout.
