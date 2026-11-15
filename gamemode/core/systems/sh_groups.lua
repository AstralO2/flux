-- Groups organize Helix classes. They never replace factions, teams, classes,
-- character IDs or admin usergroups, and do not grant access by themselves.
flux.groups = { list = {}, ordered = {} }

function flux.groups.Register(id, definition)
    assert(flux.util.Identifier(id), "Invalid Flux group ID")
    assert(istable(definition) and isstring(definition.name), "Group requires a name")
    -- Schema files are re-included during Helix auto-refresh. Replace an existing
    -- definition without duplicating its menu entry or breaking plugin reloads.
    local previous = flux.groups.list[id]
    local group = table.Copy(definition)
    group.uniqueID = id
    group.order = group.order or 100
    flux.groups.list[id] = group
    if previous then
        for index, existing in ipairs(flux.groups.ordered) do
            if existing.uniqueID == id then
                flux.groups.ordered[index] = group
                break
            end
        end
    else
        flux.groups.ordered[#flux.groups.ordered + 1] = group
    end
    table.sort(flux.groups.ordered, function(a, b)
        if a.order == b.order then
            return a.uniqueID < b.uniqueID
        end
        return a.order < b.order
    end)
    return group
end

function flux.groups.Get(id)
    return flux.groups.list[id]
end

function flux.groups.GetClasses(id, faction)
    local result = {}
    for _, class in ipairs(ix.class.list) do
        if class.group == id and (not faction or class.faction == faction) then
            result[#result + 1] = class
        end
    end
    return result
end

function flux.groups.ForCharacter(character)
    local class = character and ix.class.Get(character:GetClass())
    return class and flux.groups.Get(class.group)
end

function flux.groups.CanJoin(client, id)
    local group = flux.groups.Get(id)
    if not group then
        return false, "Unknown class group."
    end
    if group.CanJoin then
        return group:CanJoin(client)
    end
    return true
end

hook.Add("CanPlayerJoinClass", "Flux.Groups.Access", function(client, _, class)
    if not class.group then
        return
    end
    local allowed = flux.groups.CanJoin(client, class.group)
    if allowed == false then
        return false
    end
end)

hook.Add("InitializedPlugins", "Flux.Groups.Validate", function()
    for _, class in ipairs(ix.class.list) do
        assert(not class.group or flux.groups.Get(class.group), "Unknown group on class " .. class.uniqueID)
    end
end)
