# RapzoBags

RapzoBags is a modular inventory addon suite for World of Warcraft Retail.

## Modules

- **RapzoBags_Core** — required core, SavedVariables, scanning and bag ordering.
- **RapzoBags_Tooltip** — expansion, item metadata and account-wide counts.
- **RapzoBags_Search** — global inventory search.
- **RapzoBags_Collections** — mount, pet, toy, transmog, recipe and collection detection.
- **RapzoBags_Vendor** — expanded 4x5 merchant view, collected markers and filters.
- **RapzoBags_AFK** — fullscreen AFK screen with timer, character, zone and safe Retail 12.x detection.
- **RapzoBags_Config** — configuration panel.

## Installation

Copy the seven `RapzoBags_*` folders directly into:

`World of Warcraft/_retail_/Interface/AddOns/`

`RapzoBags_Core` is required. The other modules can be enabled or disabled individually.

## Development version

Current development line: **3.0.0-alpha5** for WoW Retail 12.1.0.

Alpha5: first RapzoBags AFK Screen implementation. Adds a fullscreen AFK overlay, elapsed timer, character/zone information, preview command, combat-safe hiding and secret-value-safe AFK detection for Retail 12.x.

## Releases / WowUp

Release packages are generated automatically when a tag beginning with `v` is pushed, for example:

```bash
git tag v3.0.0-alpha5
git push origin v3.0.0-alpha5
```

GitHub Actions will create a ZIP containing only the seven addon folders and attach it to the GitHub Release.
