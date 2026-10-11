# Changelog

## 2.0.2-forever.1

Port of sInterface v2.0.2 (Interface 90002, Shadowlands 9.0.2) to **WoW: Forever 1.60.1**
(Interface 16001). WoW: Forever runs the 12.x engine: Edit Mode, secret values, the rebuilt
default UI and the restricted addon environment. This port adapts the existing look,
configuration and features to that client. It adds no new features.

### Packaging

- The v2.0.2 archive could not load at all. Its git submodules (oUF, oUF_Smooth, oUF_GCD,
  oUF_FloatingCombatFeedback) were empty folders, so `embeds\_embeds.xml` referenced missing
  files and `oUF` was nil. The libraries are now vendored:
  - oUF **14.2.0**, which officially supports Interface 16001 and WoW: Forever
  - oUF_FloatingCombatFeedback and oUF_GCD, taken from the commits the submodules pointed to,
    then repaired as described below
- oUF_Smooth is no longer loaded or shipped. oUF 14 smooths bars natively and secret-safely
  (`.smoothing`), and the Lua smoothing cannot work with secret values.
- `## Interface: 16001`.
- License notices added: `embeds/rLib/LICENSE.md` and `embeds/rActionBar/LICENSE.md` (MIT,
  zork), and `media/OFL-AlegreyaSans.txt` and `media/OFL-FrancoisOne.txt` (fonts). See
  `LICENSING-ISSUES.md` in the source repository for open questions.

### Unit frames (oUF 14)

- Style functions take the unit from oUF. `self.unit` is no longer set because Blizzard's ping
  code owns it.
- Auras use oUF's aura containers. The modes are unchanged: "aura" shows buffs then debuffs,
  "debuff" shows debuffs, and the player's "buff" mode shows Blizzard's personal buffs plus the
  `uf.buffs` whitelist. Others' debuffs are still desaturated on unfriendly units. Sizes, rows,
  spacing, the 1.4 aspect crop, the count text and the borders are kept.
- `uf.buffs` names are resolved to spell IDs at login, because aura names are secret in combat.
  Numeric spell IDs are accepted as keys too.
- Heal prediction and absorbs moved into the Health element. The background tint (colour × 0.4)
  is re-implemented because oUF removed `.bg`/`.multiplier`.
- Health, power and the out-of-combat fade logic are secret-safe. The `sInterface:*` tags use
  client-side formatting (AbbreviateNumbers, curves) when values are secret, so they keep the
  red "value | NN%" and green full-health look.
- Cast bar: the "elapsed | total" (channels: "remaining | total") time text is formatted by the
  client, and the red pushback text is kept. Uninterruptible enemy casts are still grey, and
  interrupted or failed casts still turn red and fade.
- Party, raid and main-tank headers use `SetVisibility`. Before this, the shifted
  `SpawnHeader` arguments meant no group frames were shown. Blizzard raid frames are blocked
  the way oUF blocks its other frames.
- The class power bar no longer overwrites the Blizzard global `ClassPowerBar`, and the pet cast
  bar is no longer patched. Combo points are coloured through oUF colour objects.
- Arena names use `[sInterface:name]`. `[arenaspec]` is always secret, and Forever has no
  specializations.
- oUF_GCD reads the global cooldown spell (61304) instead of scanning the spellbook with removed
  APIs, and has a duration-object fallback for secret cooldowns.
- oUF_FloatingCombatFeedback uses oUF's unit field, so it shows feedback again.
- oUF_Trinkets uses the arena crowd-control API instead of the unreadable combat log.

### Action bars (rActionBar/rLib)

- The main bar is `MainActionBar`. The stance, pet and possess bars, the micro menu and the bag
  bar use their new frames. Blizzard's Edit Mode bars are hidden by reparenting only, and
  sInterface takes over their buttons.
- Bar 1 paging resolves the override, vehicle and temporary-shapeshift pages from the client.
  The old hard-coded pages 12-14 are action bars 6-8 now.
- The grid hack, the currency workaround and the global cooldown metatable hook are removed or
  scoped. The cooldown flash fix only touches sInterface's buttons and is secret-safe.
- Button borders and empty-slot art are hidden after every Blizzard art update, the rounded icon
  mask is removed, and the overlays are fitted to the 32px buttons.
- The micro menu default `numCols` is 14, so all of Forever's micro buttons stay on one row.
- The bag bar includes Forever's reagent bag and key ring buttons, and keeps its layout when
  Blizzard re-lays out the bags.
- When the UI loads during combat, setup waits until combat ends.

### Other modules

- **Auras**: player buffs and debuffs are restyled and re-anchored after Blizzard's aura
  layout. This includes temporary enchants, consolidated buffs, the collapse button and private
  aura anchors.
- **Tooltips**: unit tooltips go through the tooltip data post-call and are secret-safe. Forever
  surnames are shown as Blizzard formats them, not as "name of realm". The border is hidden
  without overriding Blizzard methods.
- **Chat**: the shortened channel and whisper prefixes are applied with `TransformMessages` to
  finished, non-secret lines, instead of replacing the CHAT_*_GET strings (which would taint
  chat). Class-coloured names use the client setting. Shift+wheel jumps to the top or bottom,
  layered on Blizzard's scrolling. Edit Mode placement is respected.
- **Minimap**: works with the new MinimapCluster, compass, tracking, mail, queue status and
  difficulty frames, and keeps the square mask when the client re-applies the round one.
- **Nameplates**: the skin hooks the new nameplate layout (`NamePlateUnitFrameMixin`):
  texture, background tint, shadow borders, thin cast bar, name style and reaction or
  tank-threat colours.
- **Progress bars**: experience and reputation use the current reputation, friendship and
  max-level APIs.
- **Cool bar**: uses `C_Spell` cooldowns. In combat, a secret cooldown is placed with a duration
  object and a curve. Fixed: the disabled list never matched.
- **Mirror timers, talking head, objective tracker, junk seller, Details skin, order hall bar**:
  moved to their current frames and APIs. Edit Mode frames are re-anchored with their original
  methods so Edit Mode is not tainted.
- **Errors**: the `/errors` filter unregisters UIErrorsFrame events instead of replacing its
  event handler.
