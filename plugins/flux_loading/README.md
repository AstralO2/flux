# Flux Loading Screen

Optional SCP slideshow and client asset preparation before character selection.
Enabled by default.

Admins with **Helix - Manage Config** access can enable/disable
**Flux Loading Screen** (`flux_loading`) under **Config → Plugins**. The native
plugin manager saves this choice across server restarts.

Disabling a plugin loaded at map start also stops preparation on connected
clients and reveals any waiting character menu. It works with either the custom
Flux character UI or native Helix menus. Re-enabling does not interrupt active
characters or repeat preparation for an already-prepared session. New joins
prepare their assets when enabled.

Restart the server and reconnect after installing this change. Enabling a plugin
that was disabled at startup requires a restart/reconnect so its client files and
resource registrations can load. Files already mounted/downloaded are retained
when disabling live; restart to rebuild the server's download list.

Settings remain in `flux/config/sh_loading.lua`, including the file-level
`enabled` override, slideshow images, timeouts and frame budgets. The plugin uses
Flux's existing loading materials and UI helpers. See `docs/LOADING.md` for asset
discovery and failure handling. The optional hosted HTML page under `flux/loading/`
is separate and remains controlled through the engine's `sv_loadingurl` setting.
