# RapzoBags

RapzoBags is a modular inventory addon suite for World of Warcraft Retail.

## Modules

- **RapzoBags_Core** — required core, SavedVariables, scanning and bag ordering.
- **RapzoBags_Tooltip** — expansion, item metadata and account-wide counts.
- **RapzoBags_Search** — global inventory search.
- **RapzoBags_Collections** — mount, pet, toy, transmog, recipe and collection detection.
- **RapzoBags_Vendor** — expanded 4x5 merchant view, collected markers and filters.
- **RapzoBags_AFK** — fullscreen AFK screen with timer, character, zone and safe Retail 12.x detection.
- **RapzoBags_HUD** — cursor ring, square minimap and minimalist Player/Target/Focus styling.
- **RapzoBags_Config** — configuration panel.

## Installation

Copy the eight `RapzoBags_*` folders directly into:

`World of Warcraft/_retail_/Interface/AddOns/`

`RapzoBags_Core` is required. The other modules can be enabled or disabled individually.

## Development version

Current development line: **3.0.0-alpha5** for WoW Retail 12.1.0.

Alpha5: AFK Screen plus the first RapzoBags HUD pass. Adds an ultrawide-friendly AFK overlay, cursor ring, square minimap and portrait-free Player/Target/Focus styling while keeping Blizzard's native unit-frame data handling.

## Releases / WowUp

Release packages are generated automatically when a tag beginning with `v` is pushed, for example:

```bash
git tag v3.0.0-alpha5
git push origin v3.0.0-alpha5
```

GitHub Actions will create a ZIP containing only the eight addon folders and attach it to the GitHub Release.
