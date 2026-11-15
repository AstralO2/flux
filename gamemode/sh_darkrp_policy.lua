-- Install before loading the native base. Only Helix classes may define roles.
flux = flux or {}
flux.darkrpPolicy = flux.darkrpPolicy or {}
local policy = flux.darkrpPolicy
policy.catalog = policy.catalog or RPExtraTeams
policy.blockCreateJob = policy.blockCreateJob or function()
    return nil
end

function policy.RestoreDefault(gm)
    local teamID = policy.defaultTeam
    if not teamID or not RPExtraTeams or not RPExtraTeams[teamID] then
        return false
    end
    for _, target in pairs({ gm, GM, GAMEMODE, gamemode.Get("darkrp") }) do
        target.DefaultTeam = teamID
    end
    return true
end

hook.Add("DarkRPStartedLoading", "Flux.RoleDefinitions.Begin", function()
    policy.ready, policy.pending = false, nil
end)

hook.Add("DarkRPPreLoadModules", "Flux.RoleDefinitions", function()
    for _, category in ipairs({ "jobs", "agendas", "doorgroups", "demotegroups", "hitmen" }) do
        DarkRP.disabledDefaults[category] = setmetatable({}, {
            __index = function()
                return true
            end,
        })
    end
end)

-- Defer the native modification/readiness event until the Helix catalog exists.
-- The original hook dispatcher is retained, so every ordinary hook still runs.
policy.dispatch = policy.dispatch or hook.Call
function hook.Call(name, gm, ...)
    if name == "DarkRPFinishedLoading" then
        if not policy.createJob or policy.catalog ~= RPExtraTeams then
            policy.createJob, policy.catalog = DarkRP.createJob, RPExtraTeams
        end
        DarkRP.createJob, AddExtraTeam = policy.blockCreateJob, policy.blockCreateJob
        if not policy.ready or not policy.RestoreDefault(gm) then
            policy.ready, policy.pending = false, true
            return
        end
    elseif name == "loadCustomDarkRPItems" then
        -- Native validation reads GAMEMODE even while Register is merging a
        -- temporary GM table. Restore the configured job in both contexts.
        policy.RestoreDefault(gm)
    end
    return policy.dispatch(name, gm, ...)
end

function policy.Finish()
    if not policy.pending then
        return
    end
    policy.pending, policy.ready = nil, true
    policy.RestoreDefault(GM or GAMEMODE)
    local previous = GM
    GM = GAMEMODE or GM
    local ok, message = pcall(hook.Call, "DarkRPFinishedLoading", GM)
    GM = previous
    if not ok then
        error(message, 0)
    end
end

policy.RestoreDefault(GM)
