# Optional framework systems

Edit [config/sh_features.lua](../config/sh_features.lua). Every entry below defaults to `false`. Set an entry to `true` to allow that native system to load, then **restart the server and reconnect**. The config is distributed with the server's Lua; clients do not select their own feature set. These are startup settings, separate from live Helix settings and the plugin manager.

| Setting | Controls |
| --- | --- |
| `darkrpFAdmin` | The complete native FAdmin module, including its admin UI, access backend, logs, hooks and timers. |
| `darkrpPockets` | Pocket SWEP, entity storage, menu, networking and default weapon grant. Helix inventories remain. |
| `darkrpDoors` | DarkRP ownership, co-owners, door tax, door menus/labels, lock actions and keys SWEP. Helix doors and `ix_keys` remain. |
| `darkrpEvents` | DarkRP fire-spread, earthquake and meteor event module. This does not disable general Lua hooks/events. |
| `darkrpAFK` | DarkRP AFK detection, role demotion and AFK salary/hunger effects. |
| `darkrpHunger` | Native hunger updates, food module and food UI. Helix stamina remains. |
| `optionalRagdolls` | DarkRP sleep, FAdmin voluntary/admin ragdoll actions when FAdmin is enabled, and Helix `/CharFallOver`. |
| `helixBusiness` | Helix business purchase requests and menu access. Existing shipments retain their native recovery handlers. |
| `helixVendors` | The bundled Helix vendor plugin, entity registration, persistence loading and trade handlers. |
| `typingIndicators` | DarkRP's typing bubble and Helix's typing indicator plugin/messages. Flux's typing/microphone hand pose remains. |

Helix core unconsciousness/death ragdolls, `SetRagdolled`, weapon restoration and character/inventory persistence stay available regardless of `optionalRagdolls`. This setting does not disable other plugins' independently authored actions or models' animations. Vendor save data is retained when the vendor plugin is skipped; enabling it allows the native plugin to restore that data. If a Helix plugin was also disabled through its native plugin manager, enable it there as well.

The startup snapshot stays fixed during Lua refresh. Do not use auto-refresh to change these settings with players connected: restart immediately after editing this file. Feature-dependent addons require their feature to be enabled. For example, code calling FAdmin directly requires `darkrpFAdmin`; this configuration does not emulate a disabled backend or add package-specific adapters.

DarkRP's native `disabledDefaults.modules` controls its module loader. Four small, verified vendor patches extend that policy to the engine-loaded pocket/keys SWEPs and FAdmin's nested ragdoll loader in both realms. Disabled SWEPs remain inert registered classes, are hidden from spawning and are rejected by give/pickup hooks. Disabled door/hunger interfaces return inert answers rather than accumulating DarkRP's deferred stub calls. Helix vendors/typing use `PluginShouldLoad`; business purchases are denied and their receiver is removed while shipment recovery remains available. No recurring feature-manager timer or extra network channel is added.

The Escape menu retains its earlier navigation policy: re-enabling a backend does not add Business, Jobs or Scoreboard tabs to that menu. Native DarkRP F4 and HUD, Helix-authored job projections and wallets are retained.
