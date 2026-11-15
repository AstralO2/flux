-- Server startup configuration, distributed to clients by Garry's Mod.
-- true enables a system; false leaves its native module/plugin unloaded.
-- Restart the server after editing. Lua auto-refresh does not change the
-- running feature set: unloading systems with active players is unsafe.
return {
    darkrpFAdmin = false,
    darkrpPockets = false,
    darkrpDoors = false,
    darkrpEvents = false,
    darkrpAFK = false,
    darkrpHunger = false,
    optionalRagdolls = false, -- DarkRP sleep, FAdmin ragdoll, Helix /CharFallOver.
    helixBusiness = false, -- Purchases; existing shipment recovery stays available.
    helixVendors = false,
    typingIndicators = false, -- Both frameworks; typing/speaking hand pose stays.
}
