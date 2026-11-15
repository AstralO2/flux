# Runtime architecture

Flux derives from DarkRP and applies the base table's inheritance before loading shared framework code. GMod's registration path can dispatch `OnReloaded` before its usual inheritance step; native DarkRP registration functions prefer the temporary `GM` table over `GAMEMODE`, so the early step keeps all base helpers available in that context. This loads DarkRP's actual module loader, APIs, shops, entities, policing, doors, configuration, MySQLite and transports. Flux then loads Helix's actual core files in their original include contexts and mounts Helix entities through its native entity loader. Helix's native plugin initializer loads its own bundled plugins, the Flux schema and `flux/plugins`.

Both dependencies retain their native layout. Hard-coded internal includes such as `helix/gamemode/...` continue to resolve. Exact upstream revisions and original SHA-256 digests are recorded in `flux-development/vendor/upstream-lock.json`. Helix carries tracked inventory/chat optimizations, a faction/team contract migration and the pickup-indicator arc correction. DarkRP has four startup opt-outs for engine-loaded pocket/keys weapons and nested FAdmin ragdoll actions. `flux-development/vendor/local-patches.json`, each framework's unified diff and pristine snapshots verify these changes separately. [Feature configuration](FEATURES.md) applies before the native loaders; feature toggles require a restart.

## Ownership

| Shared concept | Authority |
| --- | --- |
| Character ID, identity, wallet, inventory | Helix character and SQL database. |
| Faction | Character organization, read through `Character:GetFaction()`; independent of the engine team. |
| Engine team / DarkRP job | Projection of the active Helix class. Existing DarkRP IDs and commands remain stable. |
| Class / role | Helix class registry is authoritative. Both user-facing switching APIs use native job authorization and Helix class/group checks. |
| Group | Flux metadata grouping classes; never an admin usergroup or a native team. |
| Character spawn/model/loadout/death | Helix lifecycle; job callbacks run at the integration boundary. |
| DarkRP purchases, shipments, doors, policing | Native DarkRP runtime. |
| Payday | DarkRP job salary scheduler; factions do not also run Helix pay timers. |
| Generic DarkRPVars | Native DarkRP replication. Money is projected privately to its owner. |
| Plugins, character vars, attributes, items, commands | Native Helix registries/loaders. |
| HUD | Native DarkRP renderer; Source health/armor/ammo ownership follows DarkRP. Helix interaction/action/stamina effects remain. |
| F4 dispatch/menu | Native DarkRP `ShowSpare2` on both realms, including job-specific callbacks and standard menu APIs. |
| Client options | Native Helix options. |
| Staff privileges | CAMI, checked on the server for every operation. |

## Hooks

`core/compatibility/sh_runtime.lua` captures the Helix implementations and assigns one owner to overlapping callbacks. The default is Helix, with explicit DarkRP HUD/F4 and Flux lifecycle/menu ownership. Independent permission checks retain deny-wins composition. Only a named list of notifications with distinct work runs both frameworks, including spawn/entity cleanup, vehicle handling, weapon commands and the client F4 bind path. Helix view/physgun callbacks already delegate to their base; there is no second discarded base pass. Non-admin tool checks also reuse their native delegation, while the admin shortcut still checks DarkRP restrictions. Ordinary GMod hooks and the native Helix plugin hook cache remain in place.

`sh_voice.lua` makes Helix the sole native audibility owner, including direct DarkRP-base calls. It removes DarkRP's proximity timer, spectator voice override and client voice recipient preview. Ownership is reapplied after native module loading and on reload. The cosmetic speech activity poll remains separate from audibility. See [feature configuration](FEATURES.md) for optional native systems.

Both upstreams wrap `hook.Call` for chat. Helix remains the outer plugin/schema dispatcher, with the original GMod dispatcher as its fallback. Flux probes the native Helix parser without changing chat state, then delegates registered speech classes and typed Helix commands to native Helix PlayerSay. Chat-class prefixes are distinct from server commands; their autocomplete entries exist only on clients. This covers plugin prefixes/aliases through the same registry. Native Helix owns hearing ranges, formatting and restrictions.

DarkRP-only commands execute their native wrapped callbacks and any returned deferred DoSay function once. Suppressed output stays empty. Blank parsed input stops before either post-chat hook, avoiding native DarkRP consumers receiving a nil message. Flux does not render a message through both chat implementations. See COMPATIBILITY.md for precedence and limits.

Plugins and addons remain trusted Lua. Returning from a public hook can stop subsequent hooks according to normal GMod/Helix semantics. Flux does not sandbox third-party code or override arbitrary third-party side effects.

## Persistence and performance

Money and names are stored on Helix characters. DarkRP account restoration is bypassed so reconnecting cannot overwrite a selected character or copy an account wallet into several characters. Native player data and unrelated addon databases remain separate.

Flux uses explicit core include order, cached upstream registries, engine network transports and event-driven menus. Its request limiter has weak player keys. Active-character wallet/name saves coalesce over 250 ms; native Helix saves on disconnect/shutdown also remain in place. That debounce can lose the latest quarter-second of a change during an abrupt process crash. It is not a transactional banking ledger.

Running two native runtimes adds work. Tracked Helix patches reduce repeated inventory work and UTF-8 normalization, but these changes do not establish an aggregate FPS or capacity improvement. Optional native systems are controlled by [feature configuration](FEATURES.md); startup changes require a restart.

## Unified role transitions

`sh_roles.lua` projects only authored Helix classes into jobs. It requires one default per faction and an explicit `Schema.defaultClass`; it neither imports raw jobs nor generates missing classes. Native plugin initialization projects the whole catalog once after loading all class folders; late registrations still refresh it. `CLASS.team`, `flux.roles.TeamForClass(classID)` and `ClassForTeam(teamID)` express the mapping; faction, class and team IDs are separate domains.

`sv_roles.lua` sends Helix joins through native DarkRP job/vote commands. Native `changeTeam` retains its job custom checks, bans, limits, callbacks, salary and respawn behavior, with Helix access validation before mutation. Class limits and class callbacks use the captured native `ix.class.CanSwitchTo`, with a permitted faction transfer after Flux's whitelist check for ordinary Helix factions. Every authored faction retains native whitelist access; Flux does not maintain a second copy of those checks. Before the native `OnPlayerChangedTeam` event is dispatched, the bridge commits matching character faction/class data, so addon listeners and subsequent loadout see the new role. `PlayerJoinedClass` runs once for an actual job/class transition. Trusted raw setters retain their server-side administrative meaning while updating the projection.

Helix's native faction consumers now query character membership rather than assuming `Player:Team()` is a faction ID. This is a semantic migration of the framework and its bundled behavior. External code making the old equality assumption needs to use the faction API; two incompatible meanings cannot both be assigned to the engine's single team value.


Native map filters may decline a projected job without an error; those classes remain unavailable on that map. Public creation/selection hooks reject factions without a usable default projection. Character loading cancels native votes targeting the previous character identity. Dialog ownership is tracked by Flux's common frame helper, while native F4 remains owned by DarkRP.


## Helix-only startup ordering

The metadata preloads Sandbox; Flux installs `sh_darkrp_policy.lua` and then explicitly derives DarkRP as its actual base. Native disabled-default flags suppress stock role definitions and their role-dependent default groups. The original hook dispatcher is retained while DarkRPFinishedLoading is queued. After Helix loads the schema/plugins and Flux projects all classes and assigns DefaultTeam, the native readiness/modification event is replayed once. Raw CreateJob/AddExtraTeam registrations stay disabled; the bridge holds the actual native registration function for class projection. Other DarkRP modules and content APIs remain native.

The combined profile/inventory tab composes the native YOU and inventory providers. It styles existing character-info controls and preserves their extension/update hooks, while the native inventory provider owns item/bag actions. The workspace uses a model panel instead of the original world-camera overview.

## Session preparation (0.5.0)

The optional `plugins/flux_loading/` plugin separates the shared bounded queue, client registry collection/model/material loaders, preparation lifecycle and presentation. The character menu defers its expensive controls/model preview until preparation completes, while keeping its native object identity and early HUD alpha contract. The native Helix networking receivers remain unchanged. Public registry collection and the generic FluxCollectLoadingAssets hook supply content; no addon-specific adapters or filesystem-wide asset scan are used. FluxClientPrepared is a local presentation event, not an authorization signal. See LOADING.md for scheduling and failure behavior.


## Reload boundaries (0.6.0)

Flux retains original API bindings separately from installed wrappers. Re-including a bridge reuses the original implementation; an upstream replacement is captured as a new native binding. Role projection reuses existing Flux jobs by stable class uniqueID/native command, rebuilding class/team lookup maps without allocating duplicate jobs. Composite gamemode callbacks are remembered separately from Helix implementations so a partial runtime refresh cannot recapture its own lifecycle wrapper.

The role policy stores the configured default team and restores it into the active, temporary and base gamemode tables before native validation. DarkRPStartedLoading resets readiness; a new job registry captures the new native createJob implementation and defers DarkRPFinishedLoading until the Helix catalog/default is ready. Native validation is retained. No addon-specific reload hooks or permission bypasses are introduced.
