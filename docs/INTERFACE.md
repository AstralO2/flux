# Flux interface

The Escape workspace matches the character screens: a translucent charcoal backdrop (180/255 opacity), warm white text, muted gold accents, Roboto, and a gold stripe on the selected navigation row. Darker translucent bands behind the header, navigation, profile text and page content improve readability. The grey `v-` version sits beside FLUX in the header; there is no footer branding. Disconnect sits below Change Character at the bottom of the left rail; ESC closes the workspace. The other pages retain their existing providers, controls and callbacks.

## Combined page

The **YOU** page uses a compact text profile beside the player's inventory. The secondary bag/container column appears only while a bag is open, and disappears after the last one closes; the inventory reclaims the available width. There is no portrait, large identity banner or full-height card framing. Name/faction, description editing, job/wallet, extension fields and compact attribute values remain visible. The duplicated faction row and date/time footer are omitted. All three areas scroll independently; browsing a large bag keeps the player's inventory in view. Grid cells resize to fit both item columns, with native bag View/Close actions and transfers preserved.

Native world-container views still use Helix's storage context and authorization. Their player/container grids are sized and positioned together to fit the screen, including wide containers. ESC closes storage through its native close action before opening the ESC menu.

The page composes native character-info and inventory providers rather than replacing item actions or persistence. `CanCreateCharacterInfo`, `CreateCharacterInfo`, `UpdateCharacterInfo`, category extension hooks and native attribute/boost values remain in use. The styling changes typography, row surfaces and attribute-bar rendering. The visible class row is labeled Job. Native class IDs/APIs retain their names. Attributes separate the localized name from a right-aligned value such as `2 / 100`; modifiers remain visible as `4 / 100 (+2)` with matching positive/negative segments and base-value tooltips. Redundant decimal zeros and the repeated percentage are removed. Native description editing/right-click behavior and inventory item/bag controls remain available. `CanPlayerViewInventory` still controls whether inventory is created; the character profile remains available when inventory visibility is denied.

The merged page keeps the native `inv` identifier. `you` utility/direct page requests alias it, and `GetSubpanel("you")` returns the combined page. The YOU page does not create a world-camera overview or a 3D character preview. These core ESC controls also work when the optional character UI plugin is disabled.

## Characters

The character selector uses an open three-column layout: the roster and empty slots on the left, a full-height native model in the center, and character details/actions on the right. A gold stripe marks the selected character. Overview shows the description, faction and dates; Details shows the job, wallet and appearance. The dark background, gold primary action and thin header/footer rules follow the supplied visual reference. Header server name, player count, version and slot usage reflect the current server. Every unused character slot is shown: a five-slot limit with one character displays that character and four empty slots. The roster scrolls when its rows exceed the available height; the actual limit is unchanged.

Native creation/latest-session timestamps are requested through a rate-limited owner-only roster message. The server selects IDs from the requesting player's own character list and checks account ownership; dates are not added to public character synchronization. Missing dates display as unrecorded in Overview. Existing consensual/native creation, selection and typed-deletion paths remain intact. Resizing refreshes fonts, rows and column geometry without replacing the creation payload.

The roster, creation form and typed deletion confirmation are supplied by the optional **Flux Character UI** plugin (`plugins/flux_character_ui`). Admins with native Manage Config access can toggle it in **Config â†’ Plugins**. Disabling restores native Helix character menus and persists across restarts. Switching a plugin loaded at map start also updates connected clients, after any submitted request finishes. Enabling from a disabled startup requires a restart/map change and reconnect, as with native Helix plugins. See [the plugin instructions](../plugins/flux_character_ui/README.md).

Creation uses a full-body model preview with previous/next controls, a faction dropdown and a compact portrait grid. The right column scrolls through native name, description, attributes and extension fields. Fields use `ix.char.vars` and preserve native display, validation, cleanup and payload hooks. String controls retain the actual text-entry API. The roster waits for a valid local player and refreshes automatically. The header keeps the server/player count without the previous character-system label or player icon; the footer has no Back to Game control.

Both form columns and dialogs resize to the viewport. Longer forms/details remain scrollable. Creation/selection/deletion use their native server authorization; styling does not bypass ownership or required-field checks.

Players can use **Edit Description** on the YOU page or their active character's roster Overview. This opens Helix's prefilled description prompt and uses native `CharDesc` validation and persistence. Cancel leaves the description unchanged. Load an inactive character before editing its description. The YOU control remains available when the custom character UI plugin is disabled.

## Navigation and permissions

ESC opens the combined page through the documented native `OnPauseMenuShow` hook. A second press closes it, with duplicate VGUI/engine delivery handled once per frame. Foreground dialogs and native F4 close before the workspace toggles. Exit server is confirmed; Escape cancels its dialog. Shift+Escape retains GMod's original-menu bypass.

The first three tabs are YOU, Settings, Help. Admin and extension tabs follow in deterministic alphabetical order, retaining their native sections. Settings and plugin pages retain native providers, callbacks, values and persistence. Business, Classes/Roles and Scoreboard are excluded from this workspace. Config and nested sections are admin-visible, with native server CAMI authorization still required for writes. An admin-status change closes an open menu before providers are rebuilt.

F4 opens the original DarkRP job/purchase interface using only configured Helix class projections. Tab uses the native DarkRP/base scoreboard handling; Flux creates no custom Tab menu or scoreboard frame. F1-F3 are not Flux menu keys. The HUD remains native DarkRP, with Helix interaction/action/stamina effects and without duplicate health/armor/ammo displays.

## Motion and acceptance

Flux menu entrances use a short fade; hover interpolation is frame-rate independent. Client Settings â†’ Flux â†’ Interface transitions disables Flux animation. There are no external fonts, generated background images or full-screen Flux blur passes.

Background native client tests cover combined-page controls and extension hooks, inventory visibility denial, both menu aliases, responsive columns and the existing character/menu/role flows. File captures are used for visual inspection; no desktop control or OS keyboard injection is involved. See [validation](VALIDATION.md) for development-tool locations and acceptance limits. Physical input, remote downloads and every third-party interface remain separate acceptance work.
