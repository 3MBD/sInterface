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
| Version | 1.60.1 |
| Interface (TOC) | 16001 |
| Blizzard UI source used | 1.60.1.70338 (Gethe/wow-ui-source, `forever` branch) |
| Client API export used | build 70170 |

To check your client, type this in chat:

    /run print(GetBuildInfo())

It should print `1.60.1`, a build number, a date and `16001`. If the version or interface number is
different, send me the full line before you rely on this build.

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

RESTRICTED_FEATURES

UNCERTAINTIES
