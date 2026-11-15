-- Classes are the role authority; jobs are their native DarkRP API projection.
-- Faction IDs identify organizations, while engine teams identify active roles.
flux.roles = flux.roles or { byClass = {}, byTeam = {}, ready = false }
local roles = flux.roles
roles.byID = roles.byID or {}
assert(flux.darkrpPolicy.createJob, "DarkRP role policy was not installed before base loading")
local loadClasses = flux.util.CaptureNative(ix.class, "LoadFromDir", "class.LoadFromDir")
local canSwitchClass = flux.util.CaptureNative(ix.class, "CanSwitchTo", "class.CanSwitchTo")
local initializePlugins = flux.util.CaptureNative(ix.plugin, "Initialize", "plugin.Initialize")

function roles.DefaultClass(faction)
    for index, class in ipairs(ix.class.list) do
        if class.faction == faction and class.isDefault then
            return index
        end
    end
end

function roles.TeamForClass(index)
    return roles.byClass[index]
end

function roles.ClassForTeam(index)
    return roles.byTeam[index]
end

function roles.CommandForClass(index, client)
    local teamID = roles.TeamForClass(index)
    local job = teamID and RPExtraTeams[teamID]
    if not job then
        return
    end
    if job.vote or job.RequiresVote and job.RequiresVote(client, teamID) then
        return "vote" .. job.command
    end
    return job.command
end

function roles.FactionAvailable(index)
    local default = roles.DefaultClass(index)
    return default ~= nil and roles.TeamForClass(default) ~= nil
end

function roles.TeamForCharacter(character)
    local class = ix.class.Get(character.fluxTargetClass or character:GetClass())
    local index = class and class.faction == character:GetFaction() and class.index
        or roles.DefaultClass(character:GetFaction())
    return index and roles.TeamForClass(index)
end

local function projectClass(class, faction)
    local command = class.darkrp and class.darkrp.command
        or faction.darkrp and faction.darkrp.command
        or (class.isDefault and "flux_" .. faction.uniqueID or "flux_class_" .. class.uniqueID)
    local teamID = roles.byID[class.uniqueID]
    local job = teamID and RPExtraTeams[teamID]
    if not job then
        local existing, index = DarkRP.getJobByCommand(command)
        if existing and existing.fluxClass then
            teamID, job = index, existing
        end
    end
    if not job then
        local data = table.Copy(faction.darkrp or {})
        table.Merge(data, class.darkrp or {})
        data.command = command
        data.description = data.description or class.description
        if not data.model then
            data.model = {}
            for _, model in ipairs(class.models or faction.models) do
                data.model[#data.model + 1] = istable(model) and model[1] or model
            end
        end
        data.weapons = data.weapons or class.weapons or faction.weapons or {}
        data.color = data.color or class.color or faction.color
        data.max = data.max or class.limit or 0
        data.salary = data.salary or class.salary or faction.salary or faction.pay or 0
        data.admin = data.admin or 0
        data.vote = data.vote or false
        data.hasLicense = data.hasLicense or false
        local ok, result = pcall(flux.darkrpPolicy.createJob, class.name, data)
        assert(ok, result)
        -- Native DarkRP returns nil for a definition excluded from this map.
        -- Keep its class registered but unavailable, without creating a job.
        if not result then
            return
        end
        teamID, job = result, RPExtraTeams[result]
    end
    assert(
        not roles.byTeam[teamID] or roles.byTeam[teamID] == class.index,
        "Two classes projected onto one job"
    )
    roles.byClass[class.index], roles.byTeam[teamID] = teamID, class.index
    roles.byID[class.uniqueID] = teamID
    class.team = teamID
    _G["TEAM_" .. class.uniqueID:upper()] = teamID
    job.fluxClass, job.fluxFaction = class.index, faction.index
    job.fluxClassID = class.uniqueID
    job.name, job.description = class.name, class.description
    -- Keep native job tables, command identities and addon callbacks intact.
    team.SetUp(teamID, job.name, job.color)
end

function roles.Finalize()
    if roles.catalog ~= RPExtraTeams then
        roles.byID, roles.catalog = {}, RPExtraTeams
    end
    roles.byClass, roles.byTeam = {}, {}
    local defaults = {}
    for _, class in ipairs(ix.class.list) do
        if class.isDefault then
            defaults[class.faction] = (defaults[class.faction] or 0) + 1
        end
    end
    for index, faction in ipairs(ix.faction.indices) do
        if faction.salary == nil then
            faction.salary = faction.pay or 0
        end
        assert(
            defaults[index] == 1,
            "Faction requires exactly one explicit default Helix class: " .. faction.uniqueID
        )
    end
    for _, class in ipairs(ix.class.list) do
        projectClass(class, assert(ix.faction.Get(class.faction), "Class has no faction: " .. class.uniqueID))
    end
    for _, faction in ipairs(ix.faction.indices) do
        faction.pay = 0 -- DarkRP is the sole salary scheduler.
    end
    local default
    for _, class in ipairs(ix.class.list) do
        if class.uniqueID == Schema.defaultClass then
            default = class
            break
        end
    end
    assert(
        default and default.isDefault and roles.TeamForClass(default.index),
        "Schema.defaultClass must name an available default Helix class"
    )
    roles.defaultClass, roles.defaultFaction = default.index, default.faction
    local teamID = roles.TeamForClass(default.index)
    local active = GM or GAMEMODE
    active.DefaultTeam = teamID
    flux.runtime.darkrp.DefaultTeam = teamID
    if GAMEMODE then
        GAMEMODE.DefaultTeam = teamID
    end
    roles.ready = true
    flux.darkrpPolicy.defaultTeam = teamID
    flux.darkrpPolicy.RestoreDefault(active)
    flux.darkrpPolicy.Finish()
end

function ix.class.LoadFromDir(directory)
    loadClasses(directory)
    if roles.ready and not roles.loading then
        roles.Finalize()
    end
end
function ix.plugin.Initialize()
    -- Load the whole native class catalog before projecting it. Initial load
    -- and reload each need one projection, rather than one per class folder.
    local wasLoading = roles.loading
    roles.loading = true
    local ok, message = pcall(initializePlugins)
    roles.loading = wasLoading
    if not ok then
        error(message, 0)
    end
    if not wasLoading then
        roles.Finalize()
    end
end
hook.Remove("InitializedPlugins", "Flux.Roles.Finalize")
hook.Add("GetCharacterTeam", "Flux.Roles.Team", roles.TeamForCharacter)

function roles.CanJoinClass(client, index, force)
    local character = IsValid(client) and client:GetCharacter()
    local class = ix.class.Get(index)
    if not character or not class or not roles.TeamForClass(index) then
        return false, "Unknown role or no active character."
    end
    if force then
        return true
    end
    if not client:HasWhitelist(class.faction) then
        return false, "Faction whitelist required."
    end
    -- Native Helix owns class limits, group hooks and CLASS.CanSwitchTo.
    -- A permitted faction transfer is the bridge's only extra class policy.
    return canSwitchClass(client, index, true)
end

function ix.class.CanSwitchTo(client, index)
    -- DarkRP command/transition code checks job policy when a join is requested.
    return roles.CanJoinClass(client, index)
end

flux.util.TrackWrapper(ix.class, "LoadFromDir", "class.LoadFromDir")
flux.util.TrackWrapper(ix.class, "CanSwitchTo", "class.CanSwitchTo")
flux.util.TrackWrapper(ix.plugin, "Initialize", "plugin.Initialize")
