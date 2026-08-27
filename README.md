# Rapzo QoL

Rapzo QoL is a single modular quality-of-life addon for World of Warcraft Retail.

## One addon, internal modules

World of Warcraft now sees only one addon folder:

`RapzoQoL/`

Internal modules:
- Core — SavedVariables, scanning and bag ordering.
- Tooltip — item metadata and account-wide counts.
- Search — global inventory search.
- Collections — collection detection.
- Vendor — expanded merchant view and filters.
- AFK — fullscreen AFK screen.
- HUD — cursor ring, square minimap and minimalist Player/Target/Focus visuals.
- Config — runtime module controls.

## Installation

Copy or junction only `RapzoQoL` into:

`World of Warcraft/_retail_/Interface/AddOns/`

The legacy `RapzoBags_*` folders are no longer separate addons.

## Commands

- `/rapzo`
- `/rapzo config`
- `/rapzo modules`
- `/rapzo afk preview`
- `/rapzo hud status`

Legacy aliases `/rbags` and `/rapzobags` remain available.

## Compatibility

The addon intentionally keeps the existing `RapzoBagsDB` SavedVariables name so current data and preferences survive the migration.

## Development

Current development line: **3.0.0-alpha5** for WoW Retail 12.1.0.
