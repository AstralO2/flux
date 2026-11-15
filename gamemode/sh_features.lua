-- Load before either framework, so disabled systems never start their workers.
flux = flux or {}
flux.features = flux.features or {}
local features = flux.features
if SERVER then
    AddCSLuaFile("flux/config/sh_features.lua")
end
local configured = include("flux/config/sh_features.lua")
assert(istable(configured), "Flux feature config must return a table")
for name, value in pairs(configured) do
    assert(isbool(value), "Flux feature must be true or false: " .. tostring(name))
end
features.active = features.active or table.Copy(configured)

function features.Enabled(name)
    assert(features.active[name] ~= nil, "Unknown Flux feature: " .. tostring(name))
    return features.active[name] == true
end

local modules = {
    fadmin = "darkrpFAdmin",
    pocket = "darkrpPockets",
    doorsystem = "darkrpDoors",
    events = "darkrpEvents",
    afk = "darkrpAFK",
    hungermod = "darkrpHunger",
    sleep = "optionalRagdolls",
    fadmin_ragdoll = "optionalRagdolls",
    chatindicator = "typingIndicators",
}

local function nothing() end
local function no()
    return false
end
local function empty()
    return {}
end

-- DarkRP loads interfaces even for disabled modules. Replace their deferred
-- stubs with inert answers, so HUD/base queries cannot grow a delayed-call
-- queue indefinitely. Helix's IsDoor/SetRagdolled APIs remain untouched.
function features.ApplyDarkRP()
    for module, feature in pairs(modules) do
        DarkRP.disabledDefaults.modules[module] = not features.Enabled(feature)
    end
    local entity, player = FindMetaTable("Entity"), FindMetaTable("Player")
    if not features.Enabled("darkrpDoors") then
        for _, name in ipairs({
            "isKeysOwnable",
            "isDoor",
            "isKeysOwned",
            "isMasterOwner",
            "isKeysOwnedBy",
            "isKeysAllowedToOwn",
            "isLocked",
        }) do
            entity[name] = no
        end
        entity.getKeysNonOwnable = function()
            return true
        end
        entity.getDoorData = empty
        for _, name in ipairs({
            "getDoorOwner",
            "getKeysTitle",
            "getKeysDoorGroup",
            "getKeysDoorTeams",
            "getKeysAllowedToOwn",
            "getKeysCoOwners",
            "doorIndex",
            "drawOwnableInfo",
            "keysLock",
            "keysUnLock",
            "addKeysAllowedToOwn",
            "addKeysDoorOwner",
            "removeKeysDoorOwner",
            "keysOwn",
            "keysUnOwn",
            "setKeysNonOwnable",
            "setKeysTitle",
            "setDoorGroup",
            "addKeysDoorTeam",
            "removeKeysDoorTeam",
            "removeAllKeysDoorTeams",
            "removeAllKeysExtraOwners",
            "removeAllKeysAllowedToOwn",
            "removeKeysAllowedToOwn",
            "removeDoorData",
        }) do
            entity[name] = nothing
        end
        player.canKeysLock, player.canKeysUnlock = no, no
        for _, name in ipairs({ "keysUnOwnAll", "sendDoorData", "doPropertyTax", "initiateTax" }) do
            player[name] = nothing
        end
        for _, name in ipairs({
            "registerDoorVar",
            "readNetDoorVar",
            "writeNetDoorVar",
            "doorToEntIndex",
            "doorIndexToEnt",
        }) do
            DarkRP[name] = nothing
        end
        DarkRP.getDoorVars, DarkRP.getDoorVarsByName = empty, empty
    end
    if not features.Enabled("darkrpHunger") then
        DarkRP.createFood, DarkRP.removeFoodItem = nothing, nothing
        DarkRP.getFoodItems, player.isCook = empty, no
        player.newHungerData, player.hungerUpdate = nothing, nothing
    end
    if not features.Enabled("optionalRagdolls") then
        DarkRP.toggleSleep = nothing
    end
end

hook.Add("DarkRPPreLoadModules", "Flux.Features", features.ApplyDarkRP)
hook.Add("PluginShouldLoad", "Flux.Features", function(id)
    if
        id == "vendor" and not features.Enabled("helixVendors")
        or id == "typing" and not features.Enabled("typingIndicators")
    then
        return false
    end
end)
