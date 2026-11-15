-- DarkRP supplies its complete runtime, entities and normal modification loader.
include("sh_features.lua")
include("sh_darkrp_policy.lua")
DeriveGamemode("darkrp")

-- GMod dispatches OnReloaded before Register applies base inheritance to its
-- temporary GM table. Native DarkRP registration APIs prefer GM to GAMEMODE,
-- so they need the base helpers during shared loading and reload callbacks.
table.Inherit(GM, assert(gamemode.Get("darkrp"), "Flux requires the DarkRP base"))

flux = flux or {}
flux.version = "0.6.1"
flux.path = "flux/gamemode/core/"

-- Helix's core is loaded in its original include context. Its small performance
-- patch is tracked in flux-development/vendor/; integration policy belongs
-- exclusively to Flux.
ix = ix or { util = {}, meta = {}, gui = {} }
ix.gui = ix.gui or {}
include("helix/gamemode/core/sh_util.lua")
include("helix/gamemode/core/sh_data.lua")
include("helix/gamemode/shared.lua")

ix.util.Include("flux/gamemode/core/sh_bootstrap.lua", "shared")

GM.Name = "Flux"
GM.Author = "Flux contributors"
GM.Version = flux.version
GM.IsDarkRP = true
