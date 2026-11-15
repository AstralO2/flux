# Flux Helix Notifications

Enable **Flux Helix Notifications** under **Config → Plugins** to use native Helix notifications. Disable it to use the native DarkRP popup style, configured sound, severity and duration. The plugin is enabled by default unless an administrator disables it through Helix's saved plugin state.

Helix plugin enablement normally takes effect on the next map load. Restart the server and reconnect after enabling a plugin that was not loaded this session. Disabling a loaded plugin switches current clients back once its server flag replicates. No Think hook, polling timer or new notification transport is added.

The choice covers DarkRP.notify/notifyAll via the original _Notify transport, native Helix ix.util.Notify/NotifyLocalized and Player:Notify calls, plus Flux administration feedback. The server retains native recipient filtering, onNotify cancellation and Helix localization. Native Helix chat-notice preferences apply when enabled. Explicit ChatNotify calls remain chat messages, and independently drawn addon interfaces are not replaced.

The core notification router defaults to DarkRP if this plugin is absent or disabled. It retains the original Helix renderer separately to prevent recursive wrapper capture on file refresh. The plugin uses one server-owned global flag, updated only during load/unload, so non-admin clients receive the same choice without requesting the admin plugin list.
