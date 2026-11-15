# Compatibility contract

The integration is universal in design: every package uses the same native APIs and lifecycle rules. Flux contains no individual addon/plugin compatibility files, vendor detection or per-package exceptions.

Universal design does not establish universal compatibility. Arbitrary Lua can require a different active gamemode, schema, database layout or ownership policy. Such contradictions cannot be solved merely by exposing both globals. Flux reports `engine.ActiveGamemode()` as `flux`; it does not spoof the engine.

## Helix

Install directory plugins at `flux/plugins/<id>/sh_plugin.lua`, or single-file plugins at `flux/plugins/<id>.lua`. Use the original plugin structure. The native loader handles libraries, attributes, factions, classes, items, nested plugins, languages, tools, entities, effects and weapons. Native `ix`, `PLUGIN`, `Schema`, netstream, SQL, command, configuration, option and item APIs are present.

Dependencies on another schema's faction constants, assets, custom methods or content still require that schema content. A plugin that replaces a character or spawn implementation can conflict with any other plugin doing the same, just as in a native Helix schema. External plugins that equate `Player:Team()` with a faction constant need to use `GetCharacter():GetFaction()` instead. The native Helix faction consumers have been migrated consistently. Core dependency changes require restart and retesting. Ordinary schema group definitions can be re-included without duplicating registry entries.

Helix numeric character/inventory/item IDs and native storage formats are retained. No Foundation or existing external database migration is performed.

Flux supplies custom character and menu presentation. It retains character-var display/validation providers, native requests, `OnCharacterMenuCreated`, native character response entry points, `CreateMenuButtons` and menu lifecycle callbacks. Default character text fields retain `ixTextEntry` methods and providers can use native `AttachCleanup`. Extensions which depend on private child-panel geometry or replace those menus themselves need separate acceptance testing. See [interface design and native client results](INTERFACE.md).

## DarkRP

Install addons normally, including DarkRPModification when required. DarkRP's original modification loader executes custom modules, configuration, jobs, entities, shipments, vehicles, categories and other registrations. These are the actual upstream implementations rather than empty registration stubs.

Helix classes are canonical roles. Each has one native DarkRP job entry; stock DarkRP jobs and raw `DarkRP.createJob` definitions are not registered. Define roles as Helix classes with native properties in `CLASS.darkrp`. `Player:Team()` identifies the projected job of the active class. DarkRP `allowed` team lists therefore restrict roles. Read faction membership through `Character:GetFaction()` and use `flux.roles.TeamForClass` / `ClassForTeam` when crossing the API boundary. Class IDs and team IDs need not be numerically equal.

`getDarkRPVar("money")`, `addMoney`, `setDarkRPVar("money")`, `canAfford` and Helix money methods read/change the active character wallet. Names project in both directions. Unknown/custom DarkRPVars still use the original native transport, including false values and private variables.

Money writes through DarkRP require an active character, a finite nonnegative amount and the configured bridge's integer range. The in-memory debit is synchronous, matching ordinary DarkRP purchase code. SQLite persistence follows the Helix save path. Third-party direct SQL reads of `darkrp_player.wallet`, offline account-money operations and original DarkRP account rows are **not** projections of all Helix character wallets. Choosing an offline character from only an account identifier is inherently ambiguous; Flux does not silently choose one. Integrations needing offline character balances must supply a character ID through Helix's character API.

DarkRP's startup modification loader runs before Helix core/plugin initialization. Cross-framework code should use `FluxReady` when it needs both registries. GMod addon autoruns still run before the gamemode; code that exits permanently before its framework initializes has the same loading-order problem. Flux does not replay arbitrary autoruns.

## Chat

Notifications have one optional presentation owner. Enable **Flux Helix Notifications** under Config â†’ Plugins for native Helix notices; disable it for native DarkRP popups/sound. The core router covers native DarkRP/Helix Notify APIs and Flux admin feedback, preserving DarkRP message types/durations when its style is selected. Helix localization and server-side DarkRP recipient filtering/onNotify cancellation remain native. The enabled plugin uses the original Helix renderer and its chat-notice preference, without a second popup or sound. The server-owned flag updates only on plugin load/unload; no polling is added. Enabling follows Helix's next-map/restart plugin lifecycle. See [the plugin instructions](../plugins/flux_helix_notifications/README.md).

Public StartChat/FinishChat and local PlayerStartVoice/PlayerEndVoice hooks report the player's typing and voice-activation state through one small cosmetic message. The server accepts state only for the sender and requires a living active character. Either input keeps `Flux.Speaking` true until both stop; native voice activity remains a fallback, sampled every 0.1 seconds. Only transitions update the NW2 bool. Death, character switching and disconnection clear it. There is no microphone-volume threshold or post-message text timer.

Activity reports have a 0.2-second cooldown on the client and server. The first changed state sends immediately; changes within the window share one pending report with the latest state, including stop events. Returning to the already-sent state cancels the pending packet. The server likewise keeps only the newest pending pair and applies it through its existing 0.1-second state poll once eligible. Lifecycle clearing cancels pending state; refreshing the client controller preserves a queued stop. No continuous network heartbeat or per-frame message is added.

Models supporting ACT_GMOD_IN_CHAT use [GMod's actual ear-grab animation](https://wiki.facepunch.com/gmod/GM:GrabEarAnimation). Stock Helix NPC citizens lack that activity, so they use the bounded ValveBiped hand-to-ear pose. Both ease in and out over 0.25 seconds; repeated bone builds in a frame do not speed up the transition. The fallback eases its target while preserving arm segment lengths and connected fingers. Taunts, forced sequences and unsupported skeletons are skipped. Model lookups are cached; refresh replaces only Flux's callback. Native voice mouth movement remains unchanged. NW2 values follow the engine's [PVS replication behavior](https://wiki.facepunch.com/gmod/Entity:SetNW2Bool).

Registered Helix chat classes own their prefixes and aliases, including whisper/yell and plugin-defined speech. Flux uses the shared native parser to identify them rather than relying on the server command registry: Helix creates chat-class autocomplete commands only on clients. Matching speech continues through native Helix PlayerSay and Send, preserving formatting, recipient ranges, dead-player restrictions, plugin vetoes and logging. Empty parsed speech is dropped before dispatch.

Typed Helix commands also retain priority over colliding DarkRP command names. DarkRP-only commands keep their native wrapped callback, access hooks, table arguments and Flux request limits. When a callback returns a deferred DoSay function, Flux invokes it once with the original arguments, or an empty string if output was suppressed. No per-package dispatch rules are used. This does not certify arbitrary addons that replace the chat renderer or dispatcher.

## Established and unestablished behavior

Native engine tests establish the behaviors listed in [VALIDATION.md](VALIDATION.md). Those tests exercise framework contracts using a generic disposable fixture. The fixture is not production support for a named package.

Overlapping callbacks have explicit ownership; only independent permissions and named events with distinct work are composed. Core voice audibility is Helix-only, including native DarkRP-base calls. DarkRP's proximity timer, spectator hearing exception and voice recipient preview are detached; visual spectating and public addon/plugin hooks remain available. Configure voice range through Helix. Optional native systems are documented in [feature configuration](FEATURES.md).

They do not establish acceptance of all installed paid addons, every Helix plugin, external MySQL providers, two independent remote clients, large populations, arbitrary direct SQL integrations or long-running economy consistency. Missing external assets/licenses/dependencies and mutually exclusive UI/core replacements remain the responsibility of the package installation.

References: [DarkRP source](https://github.com/FPtje/DarkRP), [Helix source](https://github.com/NebulousCloud/helix), [GMod loading order](https://wiki.facepunch.com/gmod/Lua_Loading_Order).

## Role authorization

Helix `JoinClass` and normal DarkRP job requests share the native job command path, including custom checks, admin permissions, votes and class/faction/group gates. Direct native `changeTeam` still observes its ordinary force semantics; trusted `SetClass` / `SetFaction` remain administrative setters, not permission-checked user requests. A vote or asynchronous CAMI check can complete later; `JoinClass` reports success only when the role has actually committed. The native DarkRP F4 menu uses its original command path, preserving vote and notification flow. Helix factions enforce their native whitelist access; there are no generated job factions in the new catalog.

Generic contract tests cover vetoes on both API paths and coherent state before team callbacks. Individual third-party workflows require their own acceptance checks.


Flux 0.4.0 intentionally changes role authoring: job-definition addons/files need their roles represented as Helix classes. Other native APIs and modification modules still load normally after the class catalog is ready. Both Native DarkRPFinishedLoading/readiness and ordinary modification callbacks are deferred until the configured default exists. No per-addon migration or adapter is used.
