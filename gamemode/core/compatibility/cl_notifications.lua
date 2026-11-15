-- DarkRP is the default presentation. Optional plugins can consume a notice
-- through FluxNotification without replacing either framework's transport.
flux.notifications = flux.notifications or {}
local notifications = flux.notifications
notifications.nativeHelix = flux.util.CaptureNative(ix.util, "Notify", "ix.util.Notify")

function notifications.Notify(message, kind, duration)
    kind, duration = kind or NOTIFY_GENERIC, duration or 4
    if hook.Run("FluxNotification", message, kind, duration) == true then
        return
    end
    -- Match DarkRP's native receiver: stock popup, configured sound and log.
    GAMEMODE:AddNotify(message, kind, duration)
    surface.PlaySound(flux.runtime.darkrp.Config.notificationSound)
    MsgC(Color(255, 20, 20), "[DarkRP] ", Color(200, 200, 200), message, "\n")
end

function ix.util.Notify(message)
    return notifications.Notify(message)
end
flux.util.TrackWrapper(ix.util, "Notify", "ix.util.Notify")

-- Preserve DarkRP's recipient filtering, cancellation hook and wire format.
usermessage.Hook("_Notify", function(message)
    local text = message:ReadString()
    local kind, duration = message:ReadShort(), message:ReadLong()
    notifications.Notify(text, kind, duration)
end)
