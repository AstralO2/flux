# Helix classes are the only role definitions

Flux 0.4.0 registers one native DarkRP job for each authored Helix class. It does not register stock DarkRP jobs, import job files into synthetic factions, or generate missing classes. The stock DarkRP HUD, F4, shops, job commands, permissions, voting and callbacks remain native.

## Configure the default job

Set the class uniqueID in `flux/schema/sh_schema.lua`:

```lua
Schema.defaultClass = "citizen"
```

The uniqueID is the class filename without `sh_` and `.lua`. The selected class must exist, be available on this map, and be the default class of its faction. Each faction needs exactly one explicitly authored `CLASS.isDefault = true` class. Invalid configurations fail with a clear startup error rather than selecting an unrelated job.

The supplied schema defines Citizen and Engineer as Helix classes. Citizen is the starting role. The faction is also a native Helix definition in `schema/factions/sh_darkrp_citizen.lua`; its historical identifier keeps existing Citizen characters usable. These are schema content you can edit, not DarkRP stock jobs.

## Define factions, classes and groups

Use native Helix faction files under `schema/factions` and class files under `schema/classes`. Faction constants are declared in faction files before class loading:

```lua
FACTION.name = "Research"
FACTION.models = {"models/player/kleiner.mdl"}
FACTION.isDefault = false -- Native Helix whitelist is required.
FACTION_RESEARCH = FACTION.index
```

```lua
CLASS.name = "Researcher"
CLASS.description = "Conduct laboratory research."
CLASS.faction = FACTION_RESEARCH
CLASS.isDefault = true
CLASS.group = "research"
CLASS.limit = 8
CLASS.darkrp = {command = "researcher", salary = 65, vote = false}
CLASS_RESEARCHER = CLASS.index
```

Register groups with `flux.groups.Register(id, data)` in a schema library. Groups organize classes across factions and can implement `CanJoin`; they do not grant faction whitelists or administrative ranks.

`CLASS.darkrp` accepts native job fields, including models, weapons, salary, category, prerequisites, admin requirements, votes, map restrictions and custom checks. Native category definitions can be configured through their usual APIs. Native job-dependent tables such as CivilProtection can be configured after `FluxReady` using projected class teams. Default DarkRP job-dependent agendas/door/demotion groups are disabled along with the stock roles; define your schema's own groups using its projected teams.

Raw `DarkRP.createJob`/`AddExtraTeam` role definitions are intentionally ignored. Convert role definitions to Helix classes. Other DarkRP modification files and modules still load normally; no package-specific adapters are installed.

## Identifiers and APIs

| Concept | API |
| --- | --- |
| Character role | `character:GetClass()`, `ix.class.Get(classID)` |
| Native job/team | `CLASS.team`, `flux.roles.TeamForClass(classID)` |
| Class for a team | `flux.roles.ClassForTeam(teamID)` |
| Generated team constant | `TEAM_<CLASS_UNIQUEID>` |
| Character faction | `character:GetFaction()`, `ix.faction.Get(factionID)` |
| Server default | `Schema.defaultClass`, `flux.roles.defaultClass`, `GAMEMODE.DefaultTeam` |
| Job metadata | `RPExtraTeams[teamID]`, `player:getJobTable()` |
| Group | `flux.groups.Get(id)`, `ForCharacter(character)` |

Class, faction and job/team IDs are separate domains. `Player:Team()` identifies the projected job; faction membership uses the character API. External code equating a team ID with a faction ID needs that same migration.

## Switching and access

F4 uses the original DarkRP job menu. Native job commands and Helix `character:JoinClass(id)` reach the same transition. Both faction whitelists and class/group restrictions remain enforced, together with native job custom checks, bans, limits, prerequisites, admin commands, votes, callbacks, salary and respawn behavior.

The shared command helper follows native F4's static/dynamic vote-command decision. Votes/CAMI may finish asynchronously; `JoinClass` reports success only for an immediate committed change on the requesting character. Same-role requests return false. Native votes targeting a player are cancelled at character loading so results cannot transfer to another character.

Trusted `SetClass`/`SetFaction` retain their administrative meaning. Editing an inactive character does not change its owner's active team or wallet. Public team listeners see matching faction/class/job state; class callbacks run once for an actual committed transition.

A map-excluded class stays registered without a native job and cannot be joined. Character creation/selection rejects a faction without an available default role. Classes reset to their faction default at character loading, matching Helix's temporary-class lifecycle.

## Existing characters

Existing Citizen faction identifiers remain unchanged. Characters restored from a retired generated `darkrp_*` faction that is no longer defined move to the configured default faction. Their former identifier is retained in character data as `fluxPreviousFaction`; only faction/data fields are updated. Name, wallet and inventory remain intact. No character or inventory rows are deleted.

Install core updates with a server restart and reconnect. Existing job identities and the configured default survive repeated Flux bridge-file includes and native Helix OnReloaded calls. The readiness policy restores the default into temporary GM, active GAMEMODE and native base contexts before DarkRP validates it; a fresh native catalog is deferred until projection completes. Native API wrappers retain their underlying implementations across re-includes instead of stacking.

Changing/removing job identities, command definitions or native job properties still requires a restart; this is not a live role-authoring API. Arbitrary engine file-watcher order, third-party reload behavior and client graphics reloads remain outside the verified cases.
