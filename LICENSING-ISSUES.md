# Outstanding third-party licensing issues

This is a list of open questions, not legal advice. Getting the addon to load and run on
WoW: Forever says nothing about whether every bundled file may be redistributed. Resolve the
items below before you publish the package anywhere.

sInterface's own code is MIT licensed (© 2017 Sean Baildon, `LICENSE`). oUF ships its own
`LICENSE.txt`. Neither is affected by the questions below.

## 1. oUF plugins without a license

| Component | Source | Status |
|---|---|---|
| `embeds/oUF_GCD` | github.com/sBaildon/oUF_GCD, originally "by Exactly of Turalyon (us)" | No license file and no license statement. The credit header is kept. |
| `embeds/oUF_FloatingCombatFeedback` | github.com/ls-/oUF_FloatingCombatFeedback (author: lightspark) | No license file. The README, CHANGELOG and .toc credits are kept. |
| `embeds/oUF_Trinkets` | Part of the sInterface repository since 2020; original author unknown | No author, license or source statement. It may be covered by sInterface's MIT license, but the repository does not say so. |

oUF_Smooth (github.com/sBaildon/oUF_Smooth, also unlicensed) is **no longer shipped**. Native
status-bar smoothing replaces it.

The repairs modify the first three plugins, which may matter if their authors' terms turn out to
restrict modification.

## 2. rLib and rActionBar (zork)

Both libraries come from github.com/zorker/rothui. That repository's `LICENSE.md` grants MIT
(© 2011-2018 Erik Raetz), but sInterface v2.0.2 shipped the libraries without that notice. This
repair adds a copy as `embeds/rLib/LICENSE.md` and `embeds/rActionBar/LICENSE.md`, with a line
recording where the notice came from.

Still open: whether the root license is meant to cover these particular sub-addons. Their own
`.toc` files only say "Author: zork".

## 3. Fonts in `media/`

`AlegreyaSans-Bold.ttf`, `AlegreyaSans-Medium.ttf` and `francois.ttf`:

- No sInterface code uses these fonts (`grep` for `.ttf` finds nothing). They are kept as
  bundled materials.
- Their metadata points to the SIL Open Font License 1.1, but v2.0.2 shipped no license text. The
  OFL requires that text to accompany redistributed copies. This repair adds
  `media/OFL-AlegreyaSans.txt` and `media/OFL-FrancoisOne.txt`, using the OFL text from the
  current google/fonts repository.
- The binaries are older than the current upstream releases: Alegreya Sans "Version 2.001"
  (2013) and Francois One "Version 1.000" (2011). Their checksums differ from the current
  google/fonts files. The license text was taken from the newer releases.
- `francois.ttf` carries "Copyright (c) 2011 by vernon adams. All rights reserved." together
  with the OFL URL. The current upstream file credits "The Francois One Project Authors"
  instead. The "All rights reserved" wording is common in older OFL fonts, but please confirm it
  with the upstream project.
- `francois.ttf` was renamed from its upstream file name. Renaming the file does not change the
  font name, and the OFL allows it, but it makes the file harder to trace.

Simplest resolution: remove the three unused fonts, or replace them with the current upstream
releases and their OFL.txt.

## 4. Textures in `media/`

- `bar.tga` and `shadow_border.tga`: `media/README.txt` credits kesava
  (github.com/kesava-wow). No license is stated for them.
- `embeds/rActionBar/media/vehicleexit.tga`: part of zork's rActionBar, so presumably covered by
  the MIT notice in section 2.

## 5. Blizzard material

The package contains no Blizzard art or code. All Blizzard textures are referenced by in-game
path only. The repair was written against Blizzard's interface source as published at
github.com/Gethe/wow-ui-source (`forever` branch). That repository was a reference only, and none
of its files are copied into the package.
