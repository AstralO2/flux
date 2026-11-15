function GM:Initialize()
    if flux.runtime.darkrp.Initialize then
        flux.runtime.darkrp.Initialize(self)
    end
    flux.runtime.helix.Initialize(self)
    hook.Run("FluxReady")
    flux.util.Log("Ready: native DarkRP + native Helix; no package-specific adapters")
end

function GM:OnReloaded()
    flux.darkrpPolicy.RestoreDefault(self)
    flux.runtime.helix.OnReloaded(self)
    -- A partial file refresh may leave Helix's once-only reload guard set.
    -- Reconcile the preserved job catalog without registering duplicate jobs.
    if #ix.class.list > 0 then
        flux.roles.Finalize()
    end
end

-- Both upstreams wrap hook.Call. Helix's cache remains the outer dispatcher;
-- its fallback must be the engine hook dispatcher, not DarkRP's second chat
-- renderer. DarkRP command callbacks are dispatched explicitly below.
if SERVER then
    assert(isfunction(g_DarkRPOldHookCall), "DarkRP chat dispatcher missing")
    hook.ixCall = g_DarkRPOldHookCall
end
