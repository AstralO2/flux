flux.voice = flux.voice or {}

function flux.voice.ApplyOwnership()
    local native = flux.runtime.helix.PlayerCanHearPlayersVoice
    if SERVER then
        -- Keep the base entry point usable for native callers, with the same
        -- Helix rules as the active gamemode. No second proximity cache runs.
        if GM then
            GM.PlayerCanHearPlayersVoice = native
        end
        if GAMEMODE then
            GAMEMODE.PlayerCanHearPlayersVoice = native
        end
        flux.runtime.darkrp.PlayerCanHearPlayersVoice = native
        timer.Remove("DarkRPCanHearPlayersVoice")
        hook.Remove("PlayerDisconnected", "DarkRPCanHear")
        hook.Remove("PlayerCanHearPlayersVoice", "FSpectate")
    else
        -- The stock recipient preview uses DarkRP distance/room tests, which
        -- cannot describe Helix audibility. Leave text recipient APIs intact.
        local client = LocalPlayer()
        if IsValid(client) and client.DRPIsTalking then
            hook.Remove("Think", "DarkRP_chatRecipients")
            hook.Remove("HUDPaint", "DarkRP_DrawChatReceivers")
        end
        hook.Remove("PlayerStartVoice", "DarkRP_VoiceChatReceiverFinder")
        hook.Remove("PlayerEndVoice", "DarkRP_VoiceChatReceiverFinder")
        DarkRP.removeChatReceiver("speak")
    end
end

flux.voice.ApplyOwnership()
hook.Add("FluxReady", "Flux.Voice.Ownership", flux.voice.ApplyOwnership)
hook.Add("OnReloaded", "Flux.Voice.Ownership", flux.voice.ApplyOwnership)
hook.Add("loadCustomDarkRPItems", "Flux.Voice.Ownership", function()
    -- Native modules can re-register their hooks/timer while loading. Run
    -- after every listener, independent of hook iteration order.
    timer.Simple(0, flux.voice.ApplyOwnership)
end)
