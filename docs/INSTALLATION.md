# Installation

Update all three gamemode folders (`flux`, `helix`, `darkrp`) together, including `flux.txt` and `gamemode/sh_darkrp_policy.lua`. Restart the server and reconnect clients. The metadata/load-order change is required to suppress stock DarkRP roles before they register; a partial Lua update is insufficient.

Roles now come only from native Helix faction/class files. Set `Schema.defaultClass` in `flux/schema/sh_schema.lua`; its value is the class uniqueID. Each faction requires exactly one explicit default class. See [role configuration](ROLES.md). The default remains Citizen in the supplied schema, alongside Engineer; these are Helix-authored classes.

The Escape menu now has a single **You & inventory** page. Native YOU/inventory entry points reach that page; inventory visibility restrictions and character-info extension hooks are preserved. F4/HUD stay native DarkRP. F1-F3 do not open Flux menus; Tab uses the native DarkRP/base scoreboard without a Flux wrapper. Config is admin-only, and Exit server asks for confirmation.

Existing Citizen faction identifiers are retained. Restored characters from retired generated job factions fall back to the configured default faction, with their previous identifier backed up in `fluxPreviousFaction`. Only faction/data fields are migrated; wallets and inventories remain intact.

## Server setup

Optional native systems are configured in [config/sh_features.lua](../config/sh_features.lua). Optional systems default off; see [the switches and retained recovery behavior](FEATURES.md). Restart the server and reconnect after changing them. Deploy the included `darkrp` folder too: four verified native loader/SWEP opt-outs are required.

Keep the three folders under `garrysmod/gamemodes`. Launch the dedicated server with `+gamemode flux +map gm_construct`, or customize the portable `startup_flux.example.bat` from the archive. Choose your own bind address, player limit, tick rate, account and content settings. Clients receive necessary Lua through the server; no separate client installation of Helix is required. Back up existing server data and configuration before updating.

Branding/timing defaults live in `flux/config/sh_config.lua`. Configure server values through native Helix configuration/CAMI interfaces and native DarkRP modification files. DarkRP job definitions are intentionally ignored; put role properties in `CLASS.darkrp`. Other modification modules and content APIs load normally after the class catalog/default role exist.

## Entry points

| Key/command | Result |
| --- | --- |
| ESC / `flux_menu` | Combined You & inventory workspace; ESC again closes the foreground menu/dialog. |
| F4 | Native DarkRP jobs/purchases using configured Helix class projections. |
| Tab | Native DarkRP/base scoreboard; no custom Flux menu. |
| `flux_inventory` | Combined profile/inventory page. |
| `flux_characters` | Character roster. |
| `flux_settings` | Native client options in the Flux workspace. |
| `flux_admin` | CAMI-authorized administration. |

Staff privileges are `Flux - Administration` and `Flux - heal/respawn/freeze/unfreeze/bring/goto/kick`. Native server configuration retains `Helix - Manage Config` authorization. UI visibility does not replace server checks.

## Loading screen

The optional Flux Loading Screen plugin is enabled by default and can be toggled under Config → Plugins. It prepares models/materials after engine downloads and before character selection. Include `flux/content/` when updating so the four photo backgrounds can mount and download. Edit `flux/config/sh_loading.lua` for limits, scheduling, additional asset paths and slideshow settings. See [session preparation](LOADING.md). It needs no web host.

Host `flux/loading/` on a reachable HTTP(S) server and set `sv_loadingurl` through your normal server configuration or Flux's `loadingURL`. There are no external fonts, build tools or trackers. No public URL is deployed by this archive. The page can be previewed locally with Python's HTTP server, but remote players need a public URL.

Read [validation](VALIDATION.md) for development-tool locations and acceptance limits. A source/layout check or listen-server UI run does not certify remote downloads or every third-party workflow.
