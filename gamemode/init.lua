AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("sh_features.lua")
AddCSLuaFile("sh_darkrp_policy.lua")

-- Flux hosts Helix without executing its server entry point. Explicitly send
-- its bootstrap files before shared.lua loads the rest through ix.util.Include.
AddCSLuaFile("helix/gamemode/core/sh_util.lua")
AddCSLuaFile("helix/gamemode/core/sh_data.lua")
AddCSLuaFile("helix/gamemode/shared.lua")

include("shared.lua")
