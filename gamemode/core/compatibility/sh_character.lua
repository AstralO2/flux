-- One authoritative character wallet and identity, with both public APIs.
-- The upstream DarkRP transport is retained for arbitrary custom DarkRPVars.
local playerMeta = FindMetaTable("Player")
local nativeGet = flux.util.CaptureNative(playerMeta, "getDarkRPVar", "player.getDarkRPVar")
local nativeSet = SERVER and flux.util.CaptureNative(playerMeta, "setDarkRPVar", "player.setDarkRPVar")
flux.character = {}

function playerMeta:getDarkRPVar(key, fallback)
    local character = self:GetCharacter()
    if key == "money" then
        if character then
            return character:GetMoney()
        end
        return fallback == nil and 0 or fallback
    elseif key == "rpname" and character then
        return character:GetName()
    end
    return nativeGet(self, key, fallback)
end

flux.util.TrackWrapper(playerMeta, "getDarkRPVar", "player.getDarkRPVar")

if SERVER then
    local function sendWallet(client, amount)
        -- DarkRP's late-join serializer consults this native privacy registry.
        -- Sending only to the owner is insufficient without the persistent flag.
        DarkRP.ServerPrivateDarkRPVars[client] = DarkRP.ServerPrivateDarkRPVars[client] or {}
        DarkRP.ServerPrivateDarkRPVars[client].money = true
        nativeSet(client, "money", amount, client)
    end

    function flux.character.ScheduleSave(character)
        if character.isBot then
            return
        end
        local id = "Flux.Character.Save." .. character:GetID()
        timer.Create(id, 0.25, 1, function()
            local client = character:GetPlayer()
            -- Native CharacterPreSave reads the active player's health/items.
            -- A delayed save must not run after detach or against a new character.
            if
                ix.char.loaded[character:GetID()] == character
                and IsValid(client)
                and client:GetCharacter() == character
            then
                character:Save()
            end
        end)
    end

    hook.Add("CharacterPreSave", "Flux.Character.SaveSettled", function(character)
        timer.Remove("Flux.Character.Save." .. character:GetID())
    end)
    hook.Add("CharacterDeleted", "Flux.Character.CancelSave", function(_, id)
        timer.Remove("Flux.Character.Save." .. id)
    end)

    function playerMeta:setDarkRPVar(key, value, receiver)
        local character = self:GetCharacter()
        if key == "money" then
            if not character or not flux.util.IsFinite(value) or value < 0 or value > 2147483647 then
                return false
            end
            character:SetMoney(math.floor(value))
            return true
        elseif key == "rpname" then
            if not character or not isstring(value) or #value < 1 or #value > 128 then
                return false
            end
            character:SetName(value)
            return true
        end
        return nativeSet(self, key, value, receiver)
    end
    flux.util.TrackWrapper(playerMeta, "setDarkRPVar", "player.setDarkRPVar")

    function playerMeta:addMoney(amount)
        if not self:GetCharacter() or not flux.util.IsFinite(amount) then
            return false
        end
        amount = math.Round(amount)
        local previous = self:getDarkRPVar("money")
        local override = hook.Run("playerWalletChanged", self, amount, previous)
        local total = override == nil and previous + amount or override
        return self:setDarkRPVar("money", total)
    end

    -- DarkRP's account restore must not overwrite a selected character, nor
    -- create an account wallet which can be copied across multiple characters.
    function playerMeta:restorePlayerData() end

    function DarkRP.storeMoney(client, amount)
        return client:setDarkRPVar("money", amount)
    end

    function DarkRP.storeRPName(client, name)
        return client:setDarkRPVar("rpname", name)
    end

    function flux.character.Sync(client, character)
        if not character then
            return
        end
        nativeSet(client, "rpname", character:GetName())
        sendWallet(client, character:GetMoney())
        local job = client:getJobTable()
        if job then
            nativeSet(client, "job", job.name)
            client:setSelfDarkRPVar("salary", job.salary)
        end
    end

    hook.Add("CharacterVarChanged", "Flux.Character.Project", function(character, key, oldValue, value)
        local client = character:GetPlayer()
        if not IsValid(client) or client:GetCharacter() ~= character then
            return
        end
        if key == "money" then
            sendWallet(client, value)
            flux.character.ScheduleSave(character)
        elseif key == "name" then
            nativeSet(client, "rpname", value)
            flux.character.ScheduleSave(character)
        end
    end)

    hook.Add("CharacterLoaded", "Flux.Character.ProjectLoaded", function(character)
        local client = character:GetPlayer()
        if IsValid(client) then
            flux.character.Sync(client, character)
        end
    end)
end
