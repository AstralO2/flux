PLUGIN.name = "Flux Helix Notifications"
PLUGIN.author = "Flux contributors"
PLUGIN.description = "Use Helix notices for framework notifications. Disable to use DarkRP notifications."

local stateKey = "Flux.HelixNotifications.Enabled"

function PLUGIN:OnLoaded()
    if SERVER then
        SetGlobalBool(stateKey, true)
    end
end

function PLUGIN:OnUnload()
    if SERVER then
        SetGlobalBool(stateKey, false)
    end
end

if CLIENT then
    function PLUGIN:FluxNotification(message)
        if not GetGlobalBool(stateKey, false) then
            return
        end
        -- Call the captured original; ix.util.Notify is the shared router.
        flux.notifications.nativeHelix(message)
        return true
    end
end
