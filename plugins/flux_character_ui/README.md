# Flux Character UI

Optional character selection, creation and typed deletion screens for Flux.
Enabled by default through the native Helix plugin loader.

Administrators with **Helix - Manage Config** access can open the Escape
workspace, select **Config → Plugins**, and enable/disable **Flux Character UI**
(`flux_character_ui`). The native plugin manager saves the choice for future
server starts. Disabling restores the original Helix character menus; character
data, slots, permissions and server validation are unchanged.

When the plugin was loaded at map start, switching applies to connected clients
and rebuilds an open character menu. Submitted custom-menu requests and native
creation requests finish before the switch. Unsaved form edits are discarded when the
menu switches. Enabling a plugin that was disabled at startup requires the usual
Helix server restart/map change and client reconnect so its files can load.
Restart and reconnect after first installing this change as well.

Creation uses a faction selector, full-body preview with model arrows, a
scrollable portrait grid, and
native character-variable fields. Attributes and extension fields appear when
their existing providers allow them. Providers retain their display, validation,
cleanup and payload hooks. The plugin adds no new character attributes.

The owner-only roster timestamp transport lives in this plugin and stops serving
requests when disabled. Flux's core loading controller supports both custom and
native menus. There are no edits to Helix or DarkRP sources for this plugin.
