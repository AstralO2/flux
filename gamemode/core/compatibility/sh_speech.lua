flux.speech = flux.speech or {}
flux.speech.Resolve = nil
flux.speech.key = "Flux.Speaking"
flux.speech.cooldown = 0.2

-- Remove the previous text-chat trigger when this file is refreshed.
hook.Remove("MessageReceived", "Flux.Speech.Gesture")

-- Two-bone reach used by the client pose. Keep the elbow on a stable plane
-- and clamp the target so neither arm segment is stretched or inverted.
function flux.speech.SolveArm(shoulder, elbow, hand, target, bend)
    local upper, lower = shoulder:Distance(elbow), elbow:Distance(hand)
    local offset = target - shoulder
    local distance = offset:Length()
    if upper < 0.01 or lower < 0.01 or distance < 0.01 then
        return
    end
    local direction = offset / distance
    distance = math.Clamp(distance, math.abs(upper - lower) + 0.001, upper + lower - 0.001)
    local plane = bend - direction * bend:Dot(direction)
    if plane:LengthSqr() < 0.001 then
        plane = direction:Cross(Vector(0, 0, 1))
        if plane:LengthSqr() < 0.001 then
            plane = direction:Cross(Vector(0, 1, 0))
        end
    end
    plane:Normalize()
    local along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
    local height = math.sqrt(math.max(upper * upper - along * along, 0))
    return shoulder + direction * along + plane * height, shoulder + direction * distance
end

if SERVER then
    function flux.speech.Clear(client)
        if IsValid(client) then
            client.fluxChatTyping, client.fluxVoiceActive = false, false
            client.fluxPendingChatTyping, client.fluxPendingVoiceActive = nil, nil
            client.fluxNextChatActivity = nil
            if client:GetNW2Bool(flux.speech.key, false) then
                client:SetNW2Bool(flux.speech.key, false)
            end
        end
    end

    function flux.speech.Update(client)
        local speaking = client:Alive()
            and client:GetCharacter() ~= nil
            and (client:IsSpeaking() or client.fluxChatTyping == true or client.fluxVoiceActive == true)
        if client:GetNW2Bool(flux.speech.key, false) ~= speaking then
            client:SetNW2Bool(flux.speech.key, speaking)
        end
    end

    function flux.speech.FlushActivity(client)
        if client.fluxPendingChatTyping == nil or RealTime() < (client.fluxNextChatActivity or 0) then
            return false
        end
        if not client:Alive() or not client:GetCharacter() then
            flux.speech.Clear(client)
            return false
        end
        local typing, voice = client.fluxPendingChatTyping, client.fluxPendingVoiceActive
        client.fluxPendingChatTyping, client.fluxPendingVoiceActive = nil, nil
        if client.fluxChatTyping == typing and client.fluxVoiceActive == voice then
            return false
        end
        client.fluxChatTyping, client.fluxVoiceActive = typing, voice
        client.fluxNextChatActivity = RealTime() + flux.speech.cooldown
        return true
    end

    util.AddNetworkString("Flux.ChatActivity")
    net.Receive("Flux.ChatActivity", function(_, client)
        local typing, voice = net.ReadBool(), net.ReadBool()
        if not client:Alive() or not client:GetCharacter() then
            flux.speech.Clear(client)
            return
        end
        -- The sender can report only their own cosmetic chat activity.
        client.fluxPendingChatTyping, client.fluxPendingVoiceActive = typing, voice
        if flux.speech.FlushActivity(client) then
            flux.speech.Update(client)
        end
    end)

    -- Native state covers stock chat/voice too. Network only transitions,
    -- never microphone volume or animation frames.
    timer.Create("Flux.Speech.State", 0.1, 0, function()
        for _, client in player.Iterator() do
            flux.speech.FlushActivity(client)
            flux.speech.Update(client)
        end
    end)
    for _, event in ipairs({
        "PlayerDeath",
        "PlayerSilentDeath",
        "PrePlayerLoadedCharacter",
        "PlayerDisconnected",
    }) do
        hook.Add(event, "Flux.Speech.Clear", flux.speech.Clear)
    end
else
    local activity = flux.speech.localActivity or { typing = false, voice = false }
    flux.speech.localActivity = activity
    activity.sentTyping, activity.sentVoice = activity.sentTyping or false, activity.sentVoice or false
    local timerID = "Flux.Speech.Report"
    timer.Remove(timerID)
    local flush
    flush = function()
        if activity.typing == activity.sentTyping and activity.voice == activity.sentVoice then
            timer.Remove(timerID)
            return
        end
        local delay = (activity.nextReport or 0) - RealTime()
        if delay > 0 then
            if not timer.Exists(timerID) then
                timer.Create(timerID, delay, 1, function()
                    timer.Remove(timerID)
                    flush()
                end)
            end
            return
        end
        timer.Remove(timerID)
        net.Start("Flux.ChatActivity")
        net.WriteBool(activity.typing)
        net.WriteBool(activity.voice)
        net.SendToServer()
        activity.sentTyping, activity.sentVoice = activity.typing, activity.voice
        activity.nextReport = RealTime() + flux.speech.cooldown
    end
    local function report(key, value)
        if activity[key] == value then
            return
        end
        activity[key] = value
        flush()
    end
    hook.Add("StartChat", "Flux.Speech.Activity", function()
        report("typing", true)
    end)
    hook.Add("FinishChat", "Flux.Speech.Activity", function()
        report("typing", false)
    end)
    hook.Add("PlayerStartVoice", "Flux.Speech.Activity", function(client)
        if IsValid(client) and client == LocalPlayer() then
            report("voice", true)
        end
    end)
    hook.Add("PlayerEndVoice", "Flux.Speech.Activity", function(client)
        if IsValid(client) and client == LocalPlayer() then
            report("voice", false)
        end
    end)
    -- Reattach a pending report to the new function when this file refreshes.
    flush()
end
