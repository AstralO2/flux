local previous = flux.runtime
flux.runtime = { darkrp = gamemode.Get("darkrp"), helix = {}, composed = {} }
local runtime = flux.runtime
assert(istable(runtime.darkrp), "Flux requires the pinned DarkRP runtime")

-- Preserve the actual Helix implementations before composing overlapping hooks.
for key, value in pairs(GM) do
    if isfunction(value) then
        runtime.helix[key] = previous
                and previous.composed
                and previous.composed[key] == value
                and previous.helix[key]
            or value
    end
end

-- Helix is the sole owner of character lifecycle, model and loadout. Executing
-- DarkRP's spawn path as well would strip inventories and spawn players twice.
runtime.owners = {
    Initialize = "flux",
    PlayerInitialSpawn = "flux",
    InitPostEntity = "flux",
    PlayerSpawn = "helix",
    PlayerLoadout = "helix",
    PlayerSetModel = "flux",
    PlayerSay = "flux",
    PlayerDeath = "helix",
    DoPlayerDeath = "helix",
    PlayerDeathThink = "helix",
    PlayerCanHearPlayersVoice = "helix",
    GrabEarAnimation = "flux",
    HUDPaint = "darkrp",
    HUDShouldDraw = "darkrp",
    DrawDeathNotice = "darkrp",
    HUDAmmoPickedUp = "darkrp",
    HUDDrawPickupHistory = "darkrp",
    HUDDrawTargetID = "darkrp",
    ScoreboardShow = "darkrp",
    ScoreboardHide = "darkrp",
    ShowHelp = "flux",
    ShowTeam = "flux",
    ShowSpare1 = "flux",
    ShowSpare2 = "darkrp",
    GetGameDescription = "flux",
    OnReloaded = "flux",
    ShutDown = "helix",
}

-- Shared permission hooks require both frameworks to allow the action. A false
-- result must never be lost because the other framework returned true first.
local permissions = {
    PlayerSpawnProp = true,
    PlayerSpawnNPC = true,
    PlayerSpawnVehicle = true,
    PlayerSpawnSWEP = true,
    PlayerGiveSWEP = true,
    PlayerSpawnSENT = true,
    PlayerSpawnRagdoll = true,
    PlayerSpawnEffect = true,
    PlayerCanPickupWeapon = true,
    CanPlayerSuicide = true,
    CanTool = true,
    PhysgunPickup = true,
    CanProperty = true,
    PlayerUse = true,
    PlayerShouldTakeDamage = true,
    PlayerNoClip = true,
}

-- Helix already calls the base physgun pickup check. Its freeze implementation
-- also performs the complete Sandbox operation, so neither needs a second pass.
runtime.owners.PhysgunPickup = "helix"
runtime.owners.OnPhysgunFreeze = "helix"
runtime.owners.PlayerUse = "helix"

-- These notifications have distinct work in each framework: Helix character
-- ownership/animation/network cleanup, and DarkRP/Sandbox entity/job cleanup.
-- No other overlapping callback is automatically executed twice.
local combined = {
    EntityRemoved = true,
    PlayerBindPress = true,
    PlayerDisconnected = true,
    PlayerEnteredVehicle = true,
    PlayerLeaveVehicle = true,
    PlayerSpawnedEffect = true,
    PlayerSpawnedNPC = true,
    PlayerSpawnedProp = true,
    PlayerSpawnedRagdoll = true,
    PlayerSpawnedSENT = true,
    PlayerSpawnedSWEP = true,
    PlayerSpawnedVehicle = true,
    StartCommand = true,
}

for name, helixFunction in pairs(runtime.helix) do
    local darkrpFunction = runtime.darkrp[name]
    if isfunction(darkrpFunction) and helixFunction ~= darkrpFunction and not runtime.owners[name] then
        local helixCallback, darkrpCallback = helixFunction, darkrpFunction
        if permissions[name] then
            local delegatesToolCheck = name == "CanTool"
            GM[name] = function(self, client, ...)
                local a, b = helixCallback(self, client, ...)
                if a == false then
                    return a, b
                end
                -- Native Helix either rejects a dangerous non-admin tool or
                -- delegates to BaseClass:CanTool. Only its admin shortcut
                -- still needs the separate DarkRP restrictions checked here.
                if delegatesToolCheck and not client:IsAdmin() then
                    return a, b
                end
                local c, d = darkrpCallback(self, client, ...)
                if c == false then
                    return c, d
                end
                if a ~= nil then
                    return a, b
                end
                return c, d
            end
            runtime.owners[name] = "both:deny-wins"
        elseif combined[name] then
            GM[name] = function(self, ...)
                local a, b, c, d, e, f = helixCallback(self, ...)
                local g, h, i, j, k, l = darkrpCallback(self, ...)
                if a ~= nil then
                    return a, b, c, d, e, f
                end
                return g, h, i, j, k, l
            end
            runtime.owners[name] = "both:distinct-work"
        else
            GM[name] = helixCallback
            runtime.owners[name] = "helix"
        end
    end
end

for name, owner in pairs(runtime.owners) do
    if owner == "helix" and isfunction(runtime.helix[name]) then
        GM[name] = runtime.helix[name]
    elseif owner == "darkrp" and isfunction(runtime.darkrp[name]) then
        GM[name] = runtime.darkrp[name]
    end
end

-- DarkRP stays intact as the base, including shops, doors, policing, language,
-- MySQLite, networking, entities and the standard modification loader.
GM.Config = runtime.darkrp.Config
GM.NoLicense = runtime.darkrp.NoLicense
GM.Sandbox = runtime.darkrp.Sandbox
GM.DefaultTeam = runtime.darkrp.DefaultTeam
-- Native F4 dispatch retains DarkRP's menu API and job-specific callbacks.
GM.ShowSpare2 = runtime.darkrp.ShowSpare2

if CLIENT then
    -- Use the actual DarkRP renderer, without a second Flux paint pass.
    GM.HUDPaint = runtime.darkrp.HUDPaint
    GM.HUDShouldDraw = runtime.darkrp.HUDShouldDraw
    hook.Remove("HUDShouldDraw", "Flux.HUD.Ownership")
    -- DarkRP/Source own health, armor and ammunition. Helix keeps its item
    -- interaction, action/stamina bars and gameplay effects.
    ix.bar.Remove("armor")
    ix.bar.Remove("health")
    function GM:CanDrawAmmoHUD()
        return false
    end
end

-- Helix's entry files normally mount these; its core is hosted by Flux instead.
ix.plugin.LoadEntities("helix/entities")
if SERVER then
    resource.AddWorkshop("1267236756")
    GM.Config.disallowClientsideScripts = true
end

function GM:GetGameDescription()
    return "Flux"
end
