-- One role transition for native job commands, Helix commands and staff setters.
local roles = flux.roles
local playerMeta, characterMeta = FindMetaTable("Player"), ix.meta.character
local changeTeam = flux.util.CaptureNative(playerMeta, "changeTeam", "player.changeTeam")
local setClass = flux.util.CaptureNative(characterMeta, "SetClass", "character.SetClass")
local setFaction = flux.util.CaptureNative(characterMeta, "SetFaction", "character.SetFaction")

-- Earlier Flux releases synthesized factions from DarkRP jobs. Preserve those
-- characters when the retired role no longer exists in the authored schema.
hook.Add("CharacterRestored", "Flux.Roles.RetiredFaction", function(character)
    local old = character.vars.faction
    if not isstring(old) or old:sub(1, 7) ~= "darkrp_" or ix.faction.Get(old) then
        return
    end
    local faction = assert(ix.faction.Get(roles.defaultFaction), "Default faction is unavailable")
    character.vars.data = character.vars.data or {}
    character.vars.data.fluxPreviousFaction = character.vars.data.fluxPreviousFaction or old
    character.vars.faction = faction.uniqueID
    -- Update only the migrated fields, not inactive-character health/loadout.
    local query = mysql:Update("ix_characters")
    query:Where("id", character:GetID())
    query:Update("faction", faction.uniqueID)
    query:Update("data", util.TableToJSON(character.vars.data))
    query:Execute()
end)

function roles.Commit(character, index, joined, fromTeamHook, syncFaction)
    local class = assert(ix.class.Get(index), "Unknown role")
    local client = character:GetPlayer()
    if character.fluxRoleCommitting then
        return
    end
    if not IsValid(client) or client:GetCharacter() ~= character then
        if syncFaction or character:GetFaction() ~= class.faction then
            setFaction(character, class.faction)
        end
        setClass(character, index)
        return
    end
    local oldClass, oldTeam = character:GetClass(), client:Team()
    local targetTeam = assert(roles.TeamForClass(index), "Role has no job projection")
    character.fluxRoleCommitting, character.fluxTargetClass = true, index
    local ok, message = pcall(function()
        if syncFaction or character:GetFaction() ~= class.faction then
            setFaction(character, class.faction)
        end
        if oldClass ~= index then
            setClass(character, index)
        end
        if client:Team() ~= targetTeam then
            client:SetTeam(targetTeam)
        end
        flux.character.Sync(client, character)
        if not fromTeamHook and oldTeam ~= targetTeam then
            hook.Run("OnPlayerChangedTeam", client, oldTeam, targetTeam)
        end
    end)
    character.fluxRoleCommitting, character.fluxTargetClass = nil, nil
    if not ok then
        error(message, 0)
    end
    if joined and oldClass ~= index then
        hook.Run("PlayerJoinedClass", client, index, oldClass)
    end
end

-- Commit before dispatching the public team event, so every addon callback sees
-- matching faction/class/job data and native loadout runs with the new role.
hook.fluxRoleCall = hook.fluxRoleCall or hook.Call
function hook.Call(name, gm, ...)
    if name == "OnPlayerChangedTeam" then
        local client, _, newTeam = ...
        local character = IsValid(client) and client:GetCharacter()
        local class = roles.ClassForTeam(newTeam)
        if character and class and not character.fluxRoleCommitting then
            roles.Commit(character, class, true, true)
        end
    end
    return hook.fluxRoleCall(name, gm, ...)
end

function playerMeta:changeTeam(target, force, suppressNotification, ...)
    local class = roles.ClassForTeam(target)
    if not class then
        return false
    end
    local allowed, reason = roles.CanJoinClass(self, class, force)
    if not allowed then
        if not suppressNotification then
            DarkRP.notify(self, 1, 4, reason or DarkRP.getPhrase("unable", ix.class.Get(class).name, ""))
        end
        return false, reason
    end
    -- This retains native customCheck/blacklists, limits, bans, callbacks,
    -- salaries, policing, demotion and respawn behavior for both API paths.
    return changeTeam(self, target, force, suppressNotification, ...)
end

function roles.Request(client, index)
    local teamID = roles.TeamForClass(index)
    local job = teamID and RPExtraTeams[teamID]
    local character = IsValid(client) and client:GetCharacter()
    if not job or not character or character:GetClass() == index then
        return false
    end
    local command = roles.CommandForClass(index, client)
    local definition = DarkRP.getChatCommand(command)
    if not definition or not definition.callback then
        return false
    end
    definition.callback(client, "")
    -- Votes/CAMI may complete later. Never report an uncommitted role as joined.
    return client:GetCharacter() == character and character:GetClass() == index
end

-- Pending votes target a player entity in DarkRP. Character selection changes
-- its identity, so discard votes from the previous character at that boundary.
hook.Add("CharacterLoaded", "Flux.Roles.CancelVotes", function(character)
    local client = character:GetPlayer()
    if IsValid(client) and client:GetCharacter() == character then
        DarkRP.destroyVotesWithEnt(client)
    end
end)

hook.Add("CanPlayerCreateCharacter", "Flux.Roles.AvailableFaction", function(_, payload)
    if roles.ready and ix.faction.Get(payload.faction) and not roles.FactionAvailable(payload.faction) then
        return false, "This faction is unavailable on this map."
    end
end)
hook.Add("CanPlayerUseCharacter", "Flux.Roles.AvailableFaction", function(_, character)
    if roles.ready and not roles.FactionAvailable(character:GetFaction()) then
        return false, "This faction is unavailable on this map."
    end
end)

function characterMeta:JoinClass(index)
    local client = self:GetPlayer()
    if not IsValid(client) or client:GetCharacter() ~= self then
        return false
    end
    if not index then
        self:KickClass()
        return false
    end
    return roles.Request(self:GetPlayer(), index)
end

function characterMeta:KickClass()
    local client = self:GetPlayer()
    if not IsValid(client) or client:GetCharacter() ~= self then
        return false
    end
    local index = roles.DefaultClass(self:GetFaction())
    if index then
        return self:GetPlayer():changeTeam(roles.TeamForClass(index), true, true)
    end
    return false
end

-- Native SetClass/SetFaction are trusted raw setters, unlike user-facing join
-- requests. Preserve that distinction while keeping the projected role coherent.
function characterMeta:SetClass(index)
    if not index or not roles.ready then
        return setClass(self, index)
    end
    return roles.Commit(self, index)
end

function characterMeta:SetFaction(index)
    if not roles.ready then
        return setFaction(self, index)
    end
    local default = roles.DefaultClass(index)
    assert(default, "Faction has no default role")
    -- Native CharSetFaction writes vars.faction before calling this setter.
    -- Still invoke its OnSet callback so clients receive the faction update.
    return roles.Commit(self, default, false, false, true)
end

flux.util.TrackWrapper(playerMeta, "changeTeam", "player.changeTeam")
flux.util.TrackWrapper(characterMeta, "SetClass", "character.SetClass")
flux.util.TrackWrapper(characterMeta, "SetFaction", "character.SetFaction")
