local admin = flux.admin
util.AddNetworkString("Flux.Admin.Action")
util.AddNetworkString("Flux.Admin.Result")

local function result(client, ok, message)
    if not IsValid(client) then
        return
    end
    net.Start("Flux.Admin.Result")
    net.WriteBool(ok)
    net.WriteString(message)
    net.Send(client)
end

local function destination(client, target)
    -- Trace a free standing hull; never trust a client-provided position.
    local position = target:GetPos() + target:GetForward() * 64
    local trace = util.TraceHull({
        start = position,
        endpos = position,
        mins = client:OBBMins(),
        maxs = client:OBBMaxs(),
        filter = { client, target },
        mask = MASK_PLAYERSOLID,
    })
    if trace.Hit then
        return
    end
    return position
end

local handlers = {
    heal = function(_, target)
        target:SetHealth(target:GetMaxHealth())
        return true
    end,
    respawn = function(_, target)
        target:Spawn()
        return true
    end,
    freeze = function(_, target)
        target:Freeze(true)
        return true
    end,
    unfreeze = function(_, target)
        target:Freeze(false)
        return true
    end,
    bring = function(client, target)
        local position = destination(target, client)
        if not position then
            return false, "No safe position near you."
        end
        target:SetPos(position)
        return true
    end,
    ["goto"] = function(client, target)
        local position = destination(client, target)
        if not position then
            return false, "No safe position near this player."
        end
        client:SetPos(position)
        return true
    end,
    kick = function(_, target, reason)
        target:Kick(reason ~= "" and reason or "Removed by an administrator.")
        return true
    end,
}

-- Both the UI and integrations use this entry point. Authorization is checked
-- on every request and again after CAMI's asynchronous callback.
function admin.Execute(client, target, action, reason, callback)
    callback = callback or function() end
    if
        not IsValid(client)
        or not client:IsPlayer()
        or not IsValid(target)
        or not target:IsPlayer()
        or not handlers[action]
    then
        callback(false, "Invalid staff request.")
        return
    end
    if not flux.rateLimit.Allow(client, "admin", flux.config.adminRequestDelay) then
        callback(false, "Please wait.")
        return
    end
    reason = isstring(reason) and reason:sub(1, 128):gsub("[%c]", " ") or ""
    local settled, checkingAction = false, false
    local actorID, targetID = client:SteamID64(), target:SteamID64()
    local targetCharacter = target:GetCharacter()
    local function complete(ok, message)
        if settled then
            return
        end
        settled = true
        callback(ok, message)
    end
    local function stillValid()
        return IsValid(client)
            and IsValid(target)
            and client:SteamID64() == actorID
            and target:SteamID64() == targetID
    end
    CAMI.PlayerHasAccess(client, "Flux - Administration", function(access)
        if settled or checkingAction then
            return
        end
        if not access or not stillValid() then
            complete(false, "Access denied.")
            return
        end
        checkingAction = true
        CAMI.PlayerHasAccess(client, "Flux - " .. action, function(actionAccess)
            if settled then
                return
            end
            if not actionAccess or not stillValid() then
                complete(false, "Access denied.")
                return
            end
            if target:IsSuperAdmin() and not client:IsSuperAdmin() then
                complete(false, "Target has higher access.")
                return
            end
            if action ~= "kick" and (not targetCharacter or target:GetCharacter() ~= targetCharacter) then
                complete(false, "Target character is no longer active.")
                return
            end
            -- Settle before invoking arbitrary hook callbacks to prevent re-entry.
            settled = true
            local ok, message = handlers[action](client, target, reason)
            if ok then
                ServerLog(string.format("[Flux staff] %s %s %s %s\n", actorID, action, targetID, reason))
                hook.Run("FluxAdminAction", client, target, action, reason)
            end
            callback(ok, message or (ok and "Action completed." or "Action failed."))
        end, target)
    end, target)
end

net.Receive("Flux.Admin.Action", function(length, client)
    if length > 2048 then
        return
    end
    local target, action = net.ReadEntity(), admin.actions[net.ReadUInt(3)]
    local reason = net.ReadString()
    admin.Execute(client, target, action, reason, function(ok, message)
        result(client, ok, message)
    end)
end)
