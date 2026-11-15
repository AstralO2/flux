# Flux

Flux combines Helix characters, inventories and plugins with native DarkRP jobs, purchases, HUD and F4. Helix classes define roles and project into DarkRP jobs. The supplied schema includes Citizen and Engineer as a starting point.

## Installation

Install the bundled `flux`, `helix` and `darkrp` directories together under `garrysmod/gamemodes`. Use the pinned, patched dependencies from the same archive. Restart the server and reconnect clients after updates.

Start your server with `+gamemode flux +map gm_construct`. The archive includes `startup_flux.example.bat`; customize server settings locally. Read [installation](docs/INSTALLATION.md) before deploying.

## Configuration

- Define factions and classes in `schema/factions` and `schema/classes`. Set `Schema.defaultClass` in `schema/sh_schema.lua`; each faction needs one default class. [Role configuration](docs/ROLES.md).
- Configure core defaults in `config/sh_config.lua` and optional native systems in `config/sh_features.lua`. Startup feature changes require a restart. [Feature switches](docs/FEATURES.md).
- Configure loading assets and scheduling in `config/sh_loading.lua`. The optional HTML page in `loading/` needs a reachable web host; the in-game loading plugin does not. [Loading configuration](docs/LOADING.md).

## Interfaces and plugins

ESC opens the combined YOU/inventory page, with description editing, attributes and native item actions. The secondary container column appears only when needed. Settings, Help and authorized administration remain available. F4 uses DarkRP's native interface; Tab uses the native scoreboard without a Flux wrapper.

| Optional plugin | Purpose |
| --- | --- |
| [Flux Character UI](plugins/flux_character_ui/README.md) | Custom roster, creation and deletion screens over native Helix validation and persistence. |
| [Flux Loading Screen](plugins/flux_loading/README.md) | In-game slideshow and bounded model/material preparation before character selection. |
| [Flux Helix Notifications](plugins/flux_helix_notifications/README.md) | Selects Helix or DarkRP notification presentation. |

Admins can manage these under **Config → Plugins**. Native plugin startup rules still apply; enabling a plugin absent at startup requires a restart/map change and reconnect.

## Development and licenses

Tests, fixtures, source snapshots, patch provenance and release tools live in `flux-development` at the source checkout root. They are excluded from this deployable gamemode. Generated local reports and separately installed plugins are excluded from public archives. See [validation scope](docs/VALIDATION.md).

Read [architecture](docs/ARCHITECTURE.md), [API compatibility](docs/COMPATIBILITY.md) and [interface behavior](docs/INTERFACE.md) when extending Flux. Generic contract checks do not certify every third-party addon or an aggregate performance improvement.

Flux code uses the [MIT license](LICENSE). Helix and DarkRP retain their own licenses. SCP loading images have separate attribution and share-alike terms; full credits ship with the assets. See [third-party notices](THIRD_PARTY.md).
