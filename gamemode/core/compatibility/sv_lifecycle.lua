local runtime = flux.runtime

if flux.config.loadingURL ~= "" then
    RunConsoleCommand("sv_loadingurl", flux.config.loadingURL)
end

hook.Add("CanPlayerJoinClass", "Flux.Class.Cooldown", function(client)
    if client:GetLocalVar("fluxNextClass", 0) > CurTime() then
        return false
    end
end)
hook.Add("PlayerJoinedClass", "Flux.Class.Cooldown", function(client)
    client:SetLocalVar("fluxNextClass", CurTime() + flux.config.classChangeDelay)
end)

-- F1-F3 do not open Flux menus. F4 keeps DarkRP's native server callback.
function GM:ShowHelp() end
function GM:ShowTeam() end
function GM:ShowSpare1() end

function GM:PlayerSetModel(client)
    local character = client:GetCharacter()
    if not character then
        return
    end
    client:SetModel(character:GetModel())
    client:SetupHands()
end

function GM:PlayerInitialSpawn(client)
    runtime.darkrp.PlayerInitialSpawn(self, client)
    runtime.helix.PlayerInitialSpawn(self, client)
end

function GM:InitPostEntity()
    runtime.darkrp.InitPostEntity(self)
    runtime.helix.InitPostEntity(self)
end

-- Helix commands retain their full argument/access machinery. DarkRP chat
-- commands retain their native declared conditions and rate limits.
function GM:PlayerSay(client, text, teamOnly)
    -- Chat-class autocomplete commands exist only on Helix clients. Its shared
    -- parser owns speech prefixes/aliases, including plugin classes. Blank
    -- speech must stop here: native DarkRP post-chat hooks require strings.
    local chatType = ix.chat.Parse(client, text, true)
    if not chatType then
        return ""
    end
    local command = text:match("^/(%S+)")
    local definition = command and DarkRP.getChatCommand(command:lower())
    if chatType == "ic" and definition and definition.callback and not ix.command.list[command:lower()] then
        if not client:GetCharacter() then
            return ""
        end
        if not flux.rateLimit.Allow(client, "chat:" .. command:lower(), definition.delay or 0.1) then
            return ""
        end
        local arguments = text:sub(#command + 3)
        local response, doSay =
            definition.callback(client, definition.tableArgs and DarkRP.explodeArg(arguments) or arguments)
        local message = response == "" and "" or arguments
        if isfunction(doSay) then
            doSay(message)
        end
        hook.Run("PostPlayerSay", client, message, teamOnly or false, not client:Alive())
        return ""
    end
    return runtime.helix.PlayerSay(self, client, text)
end

hook.Add("PostPlayerLoadout", "Flux.DarkRP.Loadout", function(client)
    local character = client:GetCharacter()
    if not character then
        return
    end
    -- Faction/class loadouts and Helix item weapons have already been applied.
    -- Invoke the job callback once without running DarkRP's destructive spawn.
    local job = client:getJobTable()
    if job and job.PlayerLoadout then
        job.PlayerLoadout(client)
    end
    for _, weapon in ipairs(job and job.weapons or {}) do
        if flux.features.WeaponEnabled(weapon) and not client:HasWeapon(weapon) then
            client:Give(weapon)
        end
    end
    for _, class in ipairs(GAMEMODE.Config.DefaultWeapons or {}) do
        if flux.features.WeaponEnabled(class) then
            client:Give(class)
        end
    end
    if job and job.ammo then
        for kind, count in pairs(job.ammo) do
            client:SetAmmo(count, kind)
        end
    end
end)

hook.Add("PlayerSpawn", "Flux.DarkRP.SpawnCallback", function(client)
    -- Defer until the authoritative Helix spawn/loadout has completed.
    timer.Simple(0, function()
        if not IsValid(client) or not client:GetCharacter() then
            return
        end
        local job = client:getJobTable()
        if job and job.PlayerSpawn then
            job.PlayerSpawn(client)
        end
    end)
end)
