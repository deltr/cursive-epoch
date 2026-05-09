# Cursive — Curse Debuff Alerts (Design)

**Date:** 2026-05-09
**Target:** WoW 3.3.5a client (Project Epoch / WotLK), Interface 30300
**Addon path:** `Interface/AddOns/Cursive/`

## Purpose

When a Curse-type debuff lands on the player or any party/raid member, play a configurable sound and show a customizable center-screen banner.

## Scope

In scope:
- Detect new debuffs whose `debuffType == "Curse"` on watched units (player, party1–4, raid1–40).
- Play one sound from a selectable list (Blizzard built-ins + bundled `.ogg` files).
- Show a center-screen banner using two user-editable templates (self / group), with `%target%`, `%spell%`, `%caster%` substitutions.
- Throttle alerts to one per (unit, spell) per cooldown window, with a global ~1/sec cap.
- Provide a Blizzard Interface Options panel with a sound Test button, opened via `/cursive`.

Out of scope (v1):
- Pets, focus, target.
- LibSharedMedia integration.
- Whitelist/blacklist of specific spells.
- Chat/whisper output, raid warning broadcast.
- Localization.

## Architecture

Single addon, four Lua files, one saved-variables table.

```
Cursive/
  Cursive.toc
  Core.lua        -- init, saved vars, event frame, slash command
  Detector.lua    -- UNIT_AURA scanning, group roster tracking, throttle
  Alert.lua       -- sound playback, popup banner frame
  Config.lua      -- Blizzard Interface Options panel
  Sounds/
    README.txt    -- explains how to drop in .ogg files
```

### Cursive.toc

```
## Interface: 30300
## Title: Cursive
## Notes: Curse debuff alerts for self and group
## Author: <user>
## Version: 1.0
## SavedVariables: CursiveDB

Core.lua
Detector.lua
Alert.lua
Config.lua
```

### Core.lua

- Defines global `Cursive = {}` namespace and `CursiveDB` saved-vars table.
- Registers `ADDON_LOADED` to populate defaults on first load.
- Registers `PLAYER_LOGIN` to wire up Detector and Config.
- Registers slash command `/cursive` (and `/curs`) → opens Interface Options panel to the Cursive category. Uses `InterfaceOptionsFrame_OpenToCategory` (called twice — known 3.3.5a workaround).

**Defaults (`CursiveDB` shape):**

```lua
{
  enabled = true,
  watchSelf = true,
  watchGroup = true,
  sound = "RaidWarning",            -- key into Alert.Sounds table
  selfTemplate = "You are CURSED with %spell%!",
  groupTemplate = "%target% has %spell% (from %caster%)",
  cooldown = 3.0,                   -- seconds, per (unit, spell)
  popupDuration = 3.0,              -- seconds visible
  fontSize = 24,
}
```

### Detector.lua

State:
- `watchedUnits` — array of unit tokens currently being watched (`player` plus group units).
- `seenCurses[unit][spellName] = expirationTime` — per-unit cache of curses we've already alerted on.
- `lastAlertAt[unit .. "::" .. spellName] = GetTime()` — for throttle window.
- `lastGlobalAlertAt = 0` — global ~1/sec cap.

Events:
- `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE`, `RAID_ROSTER_UPDATE`, `PARTY_MEMBERS_CHANGED` → call `RebuildWatchList()`.
- `UNIT_AURA` (unit) → if `IsWatched(unit)` and `CursiveDB.enabled`, call `ScanUnit(unit)`.

`RebuildWatchList()`:
- Always include `"player"` if `watchSelf`.
- If `watchGroup`: if in raid, add `raid1..raidN`; else add `party1..partyN`.
- Prune `seenCurses` and throttle keys for units no longer watched.

`ScanUnit(unit)`:
- Iterate `i = 1..40`, call `UnitDebuff(unit, i)`. Stop when name is nil.
- Returns `name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable`.
- If `debuffType == "Curse"`:
  - `key = unit .. "::" .. name`
  - If `seenCurses[unit][name] == expirationTime`, skip (already handled).
  - If `GetTime() - (lastAlertAt[key] or 0) < cooldown`, update cache and skip alert.
  - If `GetTime() - lastGlobalAlertAt < 1.0`, update cache and skip alert (global cap).
  - Resolve caster: `casterName = unitCaster and UnitName(unitCaster) or "Unknown"`.
  - Update `seenCurses[unit][name] = expirationTime`, `lastAlertAt[key] = GetTime()`, `lastGlobalAlertAt = GetTime()`.
  - Call `Alert.Fire(unit, name, casterName)`.
- After loop, drop entries from `seenCurses[unit]` whose names weren't seen this scan (curse expired/dispelled), so re-application alerts.

### Alert.lua

**Sound table:**

```lua
Alert.Sounds = {
  -- Blizzard built-in (use PlaySound)
  { key = "RaidWarning",   label = "Raid Warning",   type = "builtin", id = "RaidWarning" },
  { key = "ReadyCheck",    label = "Ready Check",    type = "builtin", id = "ReadyCheck" },
  { key = "AuctionOpen",   label = "Auction Open",   type = "builtin", id = "AuctionWindowOpen" },
  { key = "LevelUp",       label = "Level Up",       type = "builtin", id = "LevelUp" },
  { key = "Achievement",   label = "Achievement",    type = "builtin", id = "AchievementMenuOpen" },
  { key = "AlarmClock1",   label = "Alarm 1",        type = "builtin", id = "AlarmClockWarning1" },
  { key = "AlarmClock2",   label = "Alarm 2",        type = "builtin", id = "AlarmClockWarning2" },
  { key = "AlarmClock3",   label = "Alarm 3",        type = "builtin", id = "AlarmClockWarning3" },
  { key = "MapPing",       label = "Map Ping",       type = "builtin", id = "MapPing" },
  { key = "PVPFlag",       label = "PvP Flag",       type = "builtin", id = "PVPFlagTaken" },
  -- Bundled file slots (use PlaySoundFile). User drops files into Sounds/.
  { key = "Alert1",        label = "Custom Alert 1", type = "file", path = "Interface\\AddOns\\Cursive\\Sounds\\alert1.ogg" },
  { key = "Alert2",        label = "Custom Alert 2", type = "file", path = "Interface\\AddOns\\Cursive\\Sounds\\alert2.ogg" },
  { key = "Alert3",        label = "Custom Alert 3", type = "file", path = "Interface\\AddOns\\Cursive\\Sounds\\alert3.ogg" },
}
```

`Alert.PlayByKey(key)` — looks up entry, calls `PlaySound(id)` or `PlaySoundFile(path, "Master")`. Returns `true` if accepted by client. (3.3.5a `PlaySoundFile` returns nothing useful; we just attempt and trust the user to verify with Test.)

**Banner frame:**
- Created lazily on first alert. `CreateFrame("Frame", "CursiveBannerFrame", UIParent)`.
- `SetFrameStrata("DIALOG")`, `SetSize(600, 60)`, `SetPoint("CENTER", UIParent, "CENTER", 0, 150)`.
- Single `FontString` child, font `GameFontNormalHuge` cloned, `SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")`. Color: white. (No color picker in v1.)
- Animation via `OnUpdate`: states `fadein` (0.15s, alpha 0→1), `hold` (`popupDuration`), `fadeout` (0.5s, alpha 1→0), then `Hide()`.
- If a new alert fires while one is showing, replace text and reset to `hold` state (no re-fade-in flicker).

`Alert.Fire(unit, spellName, casterName)`:
- Resolve target name: `UnitName(unit)`. If unit == `"player"`, use self template; else group template.
- Substitute `%target%`, `%spell%`, `%caster%` (gsub with literal replacement, escape `%` in user input).
- `Alert.PlayByKey(CursiveDB.sound)`.
- Show banner with the substituted text.

### Config.lua

Standard 3.3.5a Interface Options panel:

```lua
local panel = CreateFrame("Frame", "CursiveConfigPanel", UIParent)
panel.name = "Cursive"
InterfaceOptions_AddCategory(panel)
```

Widgets, top to bottom:

1. **Title** (font string, "Cursive — Curse Debuff Alerts").
2. **Enable Cursive** — `UICheckButtonTemplate` → `CursiveDB.enabled`.
3. **Watch self** — checkbox → `watchSelf`. On change, calls `Detector.RebuildWatchList()`.
4. **Watch party/raid** — checkbox → `watchGroup`. Same hook.
5. **Sound** dropdown — `UIDropDownMenu_Initialize` populated from `Alert.Sounds`. Selecting updates `CursiveDB.sound`.
6. **Test sound** button — `UIPanelButtonTemplate`, calls `Alert.PlayByKey(CursiveDB.sound)`.
7. **Self message** — `EditBox` (single-line, 200px wide). Saves to `selfTemplate` on focus loss / enter.
8. **Group message** — same.
9. **Help text** — small font: "Variables: %target% %spell% %caster%".
10. **Per-spell cooldown** — `OptionsSliderTemplate`, range 0.5–10, step 0.5 → `cooldown`.
11. **Popup duration** — slider, range 1–10, step 0.5 → `popupDuration`.
12. **Popup font size** — slider, range 12–48, step 2 → `fontSize`. On change, also calls `Alert.RefreshFont()`.
13. **Test popup** button — fires a fake alert ("Bob has Curse of Agony (from Skeletal Mage)") so user can preview text + sound together.

Panel `refresh` function reads from `CursiveDB` and updates all widget states (called when panel opens).

### Slash command

```lua
SLASH_CURSIVE1 = "/cursive"
SLASH_CURSIVE2 = "/curs"
SlashCmdList.CURSIVE = function(msg)
  -- 3.3.5a quirk: must call twice to actually open to the right category
  InterfaceOptionsFrame_OpenToCategory(panel)
  InterfaceOptionsFrame_OpenToCategory(panel)
end
```

## Data flow

```
PLAYER_LOGIN
  → Detector.RebuildWatchList()
  → Config.Build()  (if not built)

GROUP_ROSTER_UPDATE / RAID_ROSTER_UPDATE
  → Detector.RebuildWatchList()
  → prune seenCurses / lastAlertAt for stale units

UNIT_AURA(unit)
  → if not enabled, return
  → if not watched, return
  → Detector.ScanUnit(unit):
      for i = 1..40:
        name, _, _, _, debuffType, _, expirationTime, unitCaster = UnitDebuff(unit, i)
        if not name then break end
        if debuffType == "Curse":
          if not previously seen with same expirationTime AND throttle OK:
            Alert.Fire(unit, name, UnitName(unitCaster) or "Unknown")
      cleanup expired entries from seenCurses[unit]

Alert.Fire(unit, spell, caster)
  → format template
  → Alert.PlayByKey(CursiveDB.sound)
  → Banner.Show(text)
```

## Edge cases & decisions

- **Curse refresh (same spell re-applied):** `expirationTime` changes, so we treat it as a new alert if outside the cooldown window. Refreshes inside the cooldown are silently absorbed.
- **Curse dispelled then re-applied immediately:** UNIT_AURA fires on dispel (we drop it from cache), then again on re-apply (we alert again, subject to throttle).
- **Caster not visible** (out of range / left raid): `unitCaster` is `nil`. Substitute `"Unknown"`.
- **Player has the same name as a curse caster:** purely cosmetic, no functional issue.
- **Empty template string:** banner shows nothing but sound still plays. Acceptable.
- **User puts literal `%` in template:** we use `string.gsub` with table replacement to avoid `%` interpretation issues; literal `%` followed by non-token text (`%foo`) is left as-is.
- **PvP flag debuff is not Curse type, so won't trigger.** (Sanity check.)
- **Sound file missing:** `PlaySoundFile` silently fails on 3.3.5a. The "Test" button can't reliably detect this; we accept that limitation and document it in the Sounds README.
- **Performance:** UNIT_AURA can fire many times per second in a 25-man raid. Per-unit scan loops at most 40 times and exits early when `name == nil`. No table allocations in the hot path beyond the throttle key (a string concat).

## Testing strategy

Manual, in-game (no automated test harness exists for this client). The Test popup button (Config widget #13) covers the alert path end-to-end without needing to find a real curse caster. Validation steps for the user:

1. `/cursive` opens the panel.
2. Toggle Enable off → no alerts fire when test button pressed.
3. Each sound option, when selected and Tested, plays.
4. Editing self/group templates is reflected by the Test popup.
5. Font size slider live-updates the banner.
6. Have someone in party cast Curse of Weakness on a target dummy; alert fires with correct group template substitution.
7. Cast a curse on yourself (e.g., warlock self-target) → self template fires.
8. Spam-cast curses → throttle limits to one per (unit, spell) per cooldown.

## Open items

None. (User can choose font color and pet/focus tracking later if desired — explicitly out of scope for v1.)
