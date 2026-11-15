local ui = flux.ui
local actions = flux.admin.actions

function ui.OpenCommands()
    local frame = ui.Frame("Framework commands", 940, 650)
    local search = frame:Add("DTextEntry")
    search:Dock(TOP)
    search:SetTall(36)
    search:SetPlaceholderText("Search commands")
    ui.TextEntry(search)
    local list = ui.List(frame, { "Command", "Arguments" })
    list:Dock(FILL)
    list:DockMargin(0, 12, 0, 12)
    local arguments = frame:Add("DTextEntry")
    arguments:Dock(BOTTOM)
    arguments:SetTall(36)
    arguments:SetPlaceholderText('Arguments, for example: "Character Name" 500')
    ui.TextEntry(arguments)
    local description =
        ui.Label(frame, "Choose a command to see its description.", "Flux.Small", ui.colors.muted, 42)
    description:Dock(BOTTOM)
    description:SetWrap(true)
    local run = ui.Button(frame, "Run selected command", function()
        local row = list:GetLine(list:GetSelectedLine() or 0)
        if not IsValid(row) then
            return
        end
        -- Parsing, argument validation and access control stay in native Helix.
        ix.command.Send(row.command.uniqueID, unpack(ix.command.ExtractArgs(arguments:GetValue())))
    end)
    run:Dock(BOTTOM)
    local function populate(query)
        list:Clear()
        for id, command in SortedPairs(ix.command.list) do
            if
                command.uniqueID == id
                and ix.command.HasAccess(LocalPlayer(), id)
                and id:find(query:lower(), 1, true)
            then
                local row = ui.ListLine(list, command.name, command.syntax or "")
                row.command = command
            end
        end
    end
    search.OnChange = function(panel)
        populate(panel:GetValue())
    end
    list.OnRowSelected = function(_, _, row)
        description:SetText(row.command:GetDescription())
    end
    populate("")
    return frame
end

function ui.OpenAdmin()
    CAMI.PlayerHasAccess(LocalPlayer(), "Flux - Administration", function(access)
        if not access then
            flux.notifications.Notify("Administration access denied.", NOTIFY_ERROR, 4)
            return
        end
        if IsValid(ui.admin) then
            ui.admin:Remove()
        end
        local frame = ui.Frame("Administration", 940, 660)
        ui.admin = frame
        local players = ui.List(frame, { "Player", "SteamID64" })
        players:Dock(LEFT)
        players:SetWide(math.floor(frame:GetWide() * 0.52))
        for _, client in ipairs(player.GetAll()) do
            local row = ui.ListLine(players, client:Name(), client:SteamID64())
            row.player = client
        end
        local controls = frame:Add("DScrollPanel")
        controls:Dock(FILL)
        controls:DockMargin(18, 0, 0, 0)
        ui.Label(controls, "Select a player, then an action.", "Flux.Small", ui.colors.muted, 32)
        local reason = controls:Add("DTextEntry")
        reason:Dock(TOP)
        reason:DockMargin(0, 0, 0, 12)
        reason:SetTall(36)
        reason:SetPlaceholderText("Reason (optional)")
        reason:SetUpdateOnType(true)
        ui.TextEntry(reason)
        for index, action in ipairs(actions) do
            local actionID = index
            ui.Button(controls, action:sub(1, 1):upper() .. action:sub(2), function()
                local row = players:GetLine(players:GetSelectedLine() or 0)
                if not IsValid(row) or not IsValid(row.player) then
                    return
                end
                local function submit()
                    if not IsValid(row.player) then
                        return
                    end
                    net.Start("Flux.Admin.Action")
                    net.WriteEntity(row.player)
                    net.WriteUInt(actionID, 3)
                    net.WriteString(reason:GetValue():sub(1, 128))
                    net.SendToServer()
                end
                if action == "kick" then
                    ui.Confirm(
                        "Remove player",
                        "Kick " .. row.player:Name() .. " from this server?",
                        "Kick",
                        submit
                    )
                else
                    submit()
                end
            end, action == "kick")
        end
        ui.Button(controls, "Server configuration", function()
            frame:Close()
            ui.OpenHelixTab("config")
        end)
        ui.Button(controls, "Framework commands", function()
            frame:Close()
            ui.OpenCommands()
        end)
    end)
end

net.Receive("Flux.Admin.Result", function()
    local ok, message = net.ReadBool(), net.ReadString()
    flux.notifications.Notify(message, ok and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
end)
concommand.Add("flux_admin", ui.OpenAdmin)
