local features = flux.features

function features.WeaponEnabled(class)
    return (class ~= "pocket" or features.Enabled("darkrpPockets"))
        and (class ~= "keys" or features.Enabled("darkrpDoors"))
end

-- Native gamemode SWEPs are registered by the engine outside module loading.
-- Their entry points honour disabledDefaults before including any handlers.
-- These hooks also stop sandbox grants and ordinary map pickups.
hook.Add("PlayerGiveSWEP", "Flux.Features", function(_, class)
    if not features.WeaponEnabled(class) then
        return false
    end
end)
hook.Add("PlayerSpawnSWEP", "Flux.Features", function(_, class)
    if not features.WeaponEnabled(class) then
        return false
    end
end)
hook.Add("PlayerCanPickupWeapon", "Flux.Features", function(_, weapon)
    if not features.WeaponEnabled(weapon:GetClass()) then
        return false
    end
end)

local function apply()
    if not features.Enabled("optionalRagdolls") then
        -- Remove only the voluntary command. Damage, unconsciousness, death,
        -- restraints and inventory recovery still use native SetRagdolled.
        ix.command.list.charfallover = nil
    end
    if not features.Enabled("helixBusiness") then
        -- Keep shipment handlers: other plugins and existing items can use
        -- them independently of the business purchasing system.
        net.Receivers["ixbusinessbuy"] = nil
    end
end

hook.Add("CanPlayerUseBusiness", "Flux.Features", function()
    if not features.Enabled("helixBusiness") then
        return false
    end
end)
hook.Add("BuildBusinessMenu", "Flux.Features", function()
    if not features.Enabled("helixBusiness") then
        return false
    end
end)
hook.Add("FluxReady", "Flux.Features", apply)
hook.Add("OnReloaded", "Flux.Features", apply)
apply()
