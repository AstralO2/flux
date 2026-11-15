local loading = flux.loading

local function definition(queue, data)
    if not istable(data) then
        return
    end
    for _, key in ipairs({ "model", "models", "Model", "ViewModel", "WorldModel" }) do
        queue:AddModels(data[key])
    end
    for _, key in ipairs({ "material", "Material", "icon", "Icon" }) do
        queue:AddMaterial(data[key])
    end
    if istable(data.darkrp) then
        queue:AddModels(data.darkrp.model)
    end
end

function loading.Gather()
    local queue = loading.NewQueue()
    for _, registry in ipairs({
        ix.faction.indices,
        ix.class.list,
        ix.item.list,
        RPExtraTeams,
        DarkRPEntities or {},
        CustomShipments or {},
        CustomVehicles or {},
        FoodItems or {},
        GAMEMODE.AmmoTypes or {},
        weapons.GetList(),
    }) do
        for _, data in pairs(registry) do
            definition(queue, data)
        end
    end
    for _, entity in pairs(scripted_ents.GetList()) do
        definition(queue, entity.t)
    end
    for _, vehicle in pairs(list.Get("Vehicles") or {}) do
        definition(queue, vehicle)
    end
    for _, character in pairs(ix.char.loaded) do
        queue:AddModel(character:GetModel())
    end
    if loading.config.includeSceneModels then
        for _, entity in ipairs(ents.GetAll()) do
            if IsValid(entity) then
                queue:AddModel(entity:GetModel())
            end
        end
    end
    queue:AddModels(loading.config.additionalModels)
    for _, path in ipairs(loading.config.additionalMaterials) do
        queue:AddMaterial(path)
    end
    hook.Run("FluxCollectLoadingAssets", queue)
    return queue
end

loading.handlers = {
    models = function(path, queue)
        if not file.Exists(path, "GAME") then
            return false, "Missing model"
        end
        local entity
        local ok, reason = xpcall(function()
            -- util.PrecacheModel does nothing clientside. A temporary model
            -- loads actual model data and exposes its material dependencies.
            entity = ClientsideModel(path, RENDERGROUP_OTHER)
            assert(IsValid(entity), "Could not create model")
            entity:SetNoDraw(true)
            for _, material in ipairs(entity:GetMaterials() or {}) do
                -- Animation-only engine models can expose this generated
                -- fallback. It is not a material file that can be prepared.
                if material ~= "___error" then
                    queue:AddMaterial(material, path)
                end
            end
        end, debug.traceback)
        if IsValid(entity) then
            entity:Remove()
        end
        return ok, reason
    end,
    materials = function(path)
        return not Material(path, "smooth"):IsError(), "Missing or invalid material"
    end,
}
