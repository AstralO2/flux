-- Plugin-local metadata: native timestamps are shared only with their roster's owner.
flux.roster = flux.roster or { records = {} }

if SERVER then
    util.AddNetworkString("Flux.RosterInfo")
    net.Receive("Flux.RosterInfo", function(length, client)
        if
            not GetGlobalBool("Flux.CharacterUI.Enabled", false)
            or length ~= 0
            or not flux.rateLimit.Allow(client, "rosterInfo", 1)
        then
            return
        end
        local records = {}
        for _, id in ipairs(client.ixCharList or {}) do
            local character = ix.char.loaded[id]
            if character and character:GetSteamID() == client:SteamID64() then
                records[#records + 1] = character
                if #records == 63 then
                    break
                end
            end
        end
        net.Start("Flux.RosterInfo")
        net.WriteUInt(#records, 6)
        for _, character in ipairs(records) do
            net.WriteUInt(character:GetID(), 32)
            net.WriteUInt(character:GetCreateTime() or 0, 32)
            net.WriteUInt(character:GetLastJoinTime() or 0, 32)
        end
        net.Send(client)
    end)
else
    function flux.roster.Request()
        if (flux.roster.nextRequest or 0) > RealTime() then
            return
        end
        flux.roster.nextRequest = RealTime() + 1
        net.Start("Flux.RosterInfo")
        net.SendToServer()
    end

    net.Receive("Flux.RosterInfo", function()
        local records = {}
        for _ = 1, net.ReadUInt(6) do
            local id = net.ReadUInt(32)
            records[id] = { created = net.ReadUInt(32), lastPlayed = net.ReadUInt(32) }
        end
        flux.roster.records = records
        local menu = ix.gui.characterMenu
        if
            IsValid(menu)
            and menu.fluxCustom
            and menu.selected
            and not menu.creating
            and not menu.deleting
        then
            menu:ShowCharacterTab(menu.activeTab)
        end
    end)
end
