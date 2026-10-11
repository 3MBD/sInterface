# sInterface 2.0.2-forever.1 for WoW: Forever

This build ports sInterface v2.0.2, which was written for Shadowlands 9.0.2, to WoW: Forever. It
keeps the original look, layout, configuration files and features wherever the client allows.
`CHANGELOG.md` lists the changes and why each one was needed.

**Status:** the changes have passed static checks only (listed below). Nobody has run this build
in the game yet. Please use the checklist below and send me any Lua errors you see.

## Target client

| | |
|---|---|
| Game | World of Warcraft: Forever (product `wow_classic_beta`, codename Camelot) |
| Version | 1.60.1, build 70338 (Oct 9 2026) |
| Interface (TOC) | 16001 |
| Blizzard UI source used | 1.60.1.70338 (Gethe/wow-ui-source, `forever` branch), the same build |
| Client API export used | build 70170 (cross-checked against the 70338 API documentation) |

Confirmed on the user's client: `/run print(GetBuildInfo())` printed
`1.60.1 70338 Oct 9 2026 16001`.

After a client patch, run the same command again. If the version or interface number has changed,
the addon may need another pass.

## Installing

1. Quit the game.
2. Delete any existing `sInterface` folder from your AddOns folder. The old version left empty
   library folders and files that this build no longer uses.
3. Extract the ZIP so that this file exists:

       World of Warcraft\_classic_beta_\Interface\AddOns\sInterface\sInterface.toc

   Use the flavour folder that your WoW: Forever client lives in. `_classic_beta_` is the usual one.
   Make sure the TOC is not one folder too deep (`sInterface\sInterface\sInterface.toc`).
4. Start the game and open **AddOns** on the character screen. sInterface should be listed and
   enabled, and should not be marked "Out of date". You do not need **Load out of date AddOns**.
5. **Personal settings:** if you keep your settings in your own `sInterface_Config` addon (the
   optional addon that defines the `sInterface_Config` table), change that addon's `.toc` to
   `## Interface: 16001`. Otherwise the client skips it and sInterface uses its defaults. The
   option names have not changed. The changelog lists the options that work differently.

## Turning on Lua errors

The default UI hides Lua errors. Before testing:

    /console scriptErrors 1
    /reload

Errors then appear in a window with a stack trace. Please send me the **whole** text of each one,
including the stack, and say what you were doing (logging in, entering combat, opening a window).

To find taint problems, for example "Interface action failed because of an AddOn" or a blocked
action:

    /console taintLog 1
    /reload

Reproduce the problem, then log out. The file `World of Warcraft\_classic_beta_\Logs\taint.log`
records which addon touched what. Send the lines that mention sInterface. When you have finished,
turn logging off again with `/console taintLog 0`, because the log grows quickly.

## What was verified, and how

STATIC_RESULTS

None of these checks runs the client. They cannot prove that frames look right, that secret values
are handled correctly in every combat situation, or that nothing taints the default UI. Only the
in-game checklist can show that.

## In-game test checklist (not yet done)

Use a character with combat abilities, ideally one with a pet and a shapeshift or stance bar.
Keep Lua errors on. Run `/reload` once before you start.

**Login and general**
- [ ] No Lua error at login or after `/reload`.
- [ ] `/rl` reloads the UI. `/errors` prints "Errors shown: …" and toggles the red error text.
- [ ] Open and close Edit Mode once. No error, and no "blocked action" message afterwards.

**Unit frames**
- [ ] Player, target, target of target, focus, focus target and pet frames are at their usual
      positions, with the thin bars, shadow borders and the "value | NN%" text.
- [ ] Out of combat at full health, the player frame fades as it did before. It reappears in
      combat, when you are damaged and when you have a target.
- [ ] Target an enemy NPC in combat: health text and colours update and no error appears. This is
      where secret values matter most.
- [ ] Cast bar: "elapsed | total" text, channel countdown, red pushback text, grey for
      uninterruptible enemy casts, and red then fading for interrupted or failed casts.
- [ ] Player buffs above the player frame: Blizzard's personal buffs plus the `uf.buffs` list.
      Target auras: buffs then debuffs. Other players' debuffs are desaturated on enemies.
- [ ] Heal prediction and absorbs on health bars.
- [ ] Class power: combo points, holy power and so on, for classes that have them.
- [ ] Party (join a group), raid (raid group) and main tank frames appear. Blizzard's raid frames
      do not.
- [ ] Boss frames during an encounter, and arena frames in an arena if Forever has arenas.
- [ ] GCD spark on the player frame, and floating combat text on the player frame.

**Action bars**
- [ ] Bars 1-5, stance, pet, possess, extra action, vehicle exit, micro menu and bag bar are in
      sInterface's layout and fade as configured.
- [ ] Paging: change bar with Shift+number or the bar keys, shapeshift or stance, ride a vehicle,
      be mind controlled or possessed. The right abilities appear on bar 1.
- [ ] Buttons have no Blizzard border or empty-slot art, and icons are square.
- [ ] Dragging spells on and off the bars works, in and out of combat, and is not blocked.
- [ ] `/reload` during combat: the bars are set up once combat ends.

**Nameplates**
- [ ] Enemy and friendly nameplates: thin bar with the sInterface texture, dark background, white
      names, thin cast bar under the bar, debuffs above it.
- [ ] As a tank, the colour changes when you lose threat.

**Chat**
- [ ] Shortened prefixes: `[1. General]` becomes `1`, guild `G`, party `P`, raid `R`, and
      whispers read `from Name` / `to Name`.
- [ ] Class-coloured names. Mouse wheel scrolls one line, and Shift+wheel jumps to the top or
      bottom.
- [ ] The chat frame is at the configured position and stays there after Edit Mode and `/reload`.

**Minimap, tooltips and other modules**
- [ ] Square minimap with a shadow border. The wheel zooms, and no zoom buttons appear on hover.
- [ ] Tracking button top right, mail icon top left (send yourself mail), queue eye bottom right
      (join a queue). Day/night indicator bottom left. The addon compartment, if any addon uses
      it, sits below tracking.
- [ ] Zone text above the minimap, if `zoneText` is on.
- [ ] Objective tracker under the progress bars, including after Edit Mode.
- [ ] Experience and reputation bars update. Watch a reputation and gain some.
- [ ] Cool bar shows cooldowns, in and out of combat.
- [ ] Unit tooltips: class-coloured name, level line, no border, and no error on NPCs in combat.
- [ ] Player buffs and debuffs in the top right are styled, with timers.
- [ ] Mirror timer (hold your breath under water) is restyled.
- [ ] Talking head appears at sInterface's position.
- [ ] Junk seller sells grey items at a vendor.
- [ ] Details! skin, if Details! is installed.

## Features that work differently on this client

The client does not allow the original behaviour for these. Each one uses the closest supported
fallback.

| Feature | What changed and why |
|---|---|
| Player frame that follows your character (`uf.emulatePersonalResourceDisplay`) | The old code pinned the player frame to your own nameplate. On Forever the Personal Resource Display is a fixed Edit Mode frame, not a nameplate, and the click-through API is gone, so there is nothing that follows the character. The player frame stays at `uf.player.position` (by default just below the screen centre). The option is kept but has no effect. |
| `uf.buffs` whitelist by spell name | Aura names are secret in combat, so names cannot be matched at that point. Names are turned into spell IDs at login instead. A name that your character's spellbook cannot resolve (for example another class's buff) is skipped. Use the numeric spell ID as the key for those (`[1126] = true`). |
| Power bar on NPCs | The old code hid the power bar when a unit has no power. For NPCs the maximum power is secret and cannot be tested, so their power bar is always shown (empty when they have no power). Player-controlled units still hide it. |
| Player frame fade | It still fades out of combat at full health. If the client ever makes your own health secret, the frame stays visible instead of fading, because the "full health" test cannot be made. |
| Arena enemy specialization text | `[arenaspec]` is always secret, and Forever has no specializations. Arena frames show the name instead. |
| Arena trinket tracking | The combat log is not available to addons. The trinket icon uses the arena crowd-control API instead. |
| Chat prefixes | Lines whose text is secret (in restricted situations such as encounters) cannot be read or rewritten by any addon, so they keep Blizzard's full prefixes. |
| Class-coloured chat names | Done by the client's own class-colour setting, which sInterface switches on, instead of by rewriting Blizzard's chat tables (that would taint chat). |
| Order hall command bar | Forever has no command bar. The module stays enabled but has nothing to hide. |
| Nameplate cast bar colour | When the client keeps the cast type secret, the bar keeps Blizzard's fill art for that cast instead of the sInterface colour. |

UNCERTAINTIES
