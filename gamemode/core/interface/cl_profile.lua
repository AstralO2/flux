-- Native providers retain inventory actions/bags and character-info hooks.
local ui, c = flux.ui, flux.ui.workspaceColors

function ui.EditDescription()
    if not ui.GetCharacter() then
        return false
    end
    -- Native CharDesc opens a prefilled prompt and validates/saves on the server.
    ix.command.Send("CharDesc")
    for _, panel in pairs({ ix.gui.menu, ix.gui.characterMenu }) do
        if IsValid(panel) then
            panel:Remove()
        end
    end
    return true
end

local function numberText(value)
    return string.format("%.1f", value):gsub("%.0$", "")
end

function ui.AttributeReadout(value, maximum, boost)
    boost = boost or 0
    local text = numberText(value + boost) .. " / " .. numberText(maximum)
    if boost ~= 0 then
        text = text .. " (" .. (boost > 0 and "+" or "") .. numberText(boost) .. ")"
    end
    return text
end

function ui.StyleProfileInfo(info)
    local scale = ui.WorkspaceScale()
    local bodyFont = info.fluxCompact and "Flux.Shell.Small" or "Flux.Shell.Body"
    info.fluxStyleScale = scale
    if IsValid(info.name) then
        info.name:SetFont("Flux.Shell.Title")
        info.name:SetContentAlignment(4)
        info.name:SetPadding(0)
        info.name:SetExpensiveShadow(0)
        info.name.backgroundColor = Color(0, 0, 0, 0)
        info.name:SetTall(42)
        info.name:SetZPos(-4)
        info.name:SetVisible(false)
    end
    if IsValid(info.description) then
        info.description:SetFont(bodyFont)
        info.description:SetTextColor(c.text)
        info.description:SetContentAlignment(7)
        info.description:SetTextInset(0, 0)
        info.description.Paint = nil
        info.description:SetZPos(-3)
        info.description:DockMargin(0, 0, 0, 8 * scale)
        info.description:SetTooltip("Click to edit your description")
        if not IsValid(info.editDescription) then
            info.editDescription = ui.Button(info, "Edit Description", ui.EditDescription)
            info.editDescription:SetZPos(-2)
            info.editDescription:SetContentAlignment(4)
            info.editDescription:SetTextInset(0, 0)
            info.editDescription.UpdateColours = function() end
            info.editDescription.Paint = function(button)
                button:SetTextColor(button:IsHovered() and c.text or c.accent)
            end
        end
        info.editDescription:SetFont("Flux.Shell.Small")
        info.editDescription:SetTall(28 * scale)
        info.editDescription:DockMargin(0, 0, 0, 18 * scale)
    end
    if IsValid(info.time) then
        info.time:SetFont("Flux.Shell.Small")
        info.time:SetTextColor(c.muted)
        info.time:SetExpensiveShadow(0)
        info.time:SetContentAlignment(4)
        info.time:SetZPos(100)
        info.time:DockMargin(0, 20 * scale, 0, 0)
        info.time:SetVisible(false)
    end
    if IsValid(info.characterInfo) then
        for _, row in ipairs(info.characterInfo:GetChildren()) do
            if IsValid(row.label) and IsValid(row.text) then
                row.label:SetFont(bodyFont)
                row.label:SetTextColor(c.muted)
                row.label:SetContentAlignment(4)
                row.label:SetExpensiveShadow(0)
                row.label.Paint = nil
                row.text:SetFont(bodyFont)
                row.text:SetTextColor(c.text)
                row.text:SetContentAlignment(6)
                row.text:SetExpensiveShadow(0)
                row.text:SetTextInset(0, 0)
                row.text.Paint = nil
                row:SetTall((info.fluxCompact and 36 or 42) * scale)
                row:DockMargin(0, 0, 0, 0)
                row.Paint = function(_, w, h)
                    surface.SetDrawColor(c.line)
                    surface.DrawLine(0, h - 1, w, h - 1)
                end
            end
        end
        if IsValid(info.faction) then
            info.faction:SetVisible(false)
        end
        info.characterInfo:SizeToContents()
    end
    if IsValid(info.attributes) then
        info.attributes:DockMargin(0, 20 * scale, 0, 0)
        info.attributes.Paint = function()
            draw.SimpleText(L("attributes"), "Flux.Shell.Small", 0, 0, c.muted)
        end
        for _, attribute in ipairs(info.attributes:GetChildren()) do
            if IsValid(attribute.bar) and IsValid(attribute.label) then
                attribute.Paint = function() end
                attribute:SetTall((info.fluxCompact and 30 or 44) * scale)
                attribute.label:SetFont("Flux.Shell.Small")
                attribute.label:SetExpensiveShadow(0)
                attribute.label:SetTextColor(c.text)
                attribute.label:SetContentAlignment(7)
                attribute.label:SetWrap(true)
                local name = attribute.label:GetText():match("^(.*) %[[^%]]+%]") or attribute.label:GetText()
                attribute.label:SetText(name)
                attribute.label:DockMargin(0, 0, 96 * scale, info.fluxCompact and 0 or 12 * scale)
                attribute.bar.Paint = function(_, w, h)
                    local maximum, value, boost =
                        attribute:GetMax(), attribute:GetValue(), attribute:GetBoost() or 0
                    local readout = ui.AttributeReadout(value, maximum, boost)
                    surface.SetFont("Flux.Shell.Small")
                    local textWidth = surface.GetTextSize(readout)
                    if attribute.fluxValueWidth ~= textWidth then
                        attribute.fluxValueWidth = textWidth
                        attribute.label:DockMargin(
                            0,
                            0,
                            textWidth + 12 * scale,
                            info.fluxCompact and 0 or 12 * scale
                        )
                    end
                    draw.SimpleText(readout, "Flux.Shell.Small", w, 0, c.muted, TEXT_ALIGN_RIGHT)
                    if attribute.fluxReadout ~= readout then
                        attribute.fluxReadout = readout
                        attribute.bar:SetTooltip(name .. "\n" .. readout .. "\nBase: " .. numberText(value))
                    end
                    if info.fluxCompact then
                        return
                    end
                    local start = maximum > 0 and math.Clamp(value / maximum, 0, 1) or 0
                    local finish = maximum > 0 and math.Clamp((value + boost) / maximum, 0, 1) or 0
                    surface.SetDrawColor(c.line)
                    surface.DrawRect(0, h - 3, w, 2)
                    surface.SetDrawColor(c.accent)
                    surface.DrawRect(0, h - 3, w * start, 2)
                    if boost ~= 0 then
                        surface.SetDrawColor(boost > 0 and c.text or c.danger)
                        surface.DrawRect(w * math.min(start, finish), h - 3, w * math.abs(finish - start), 2)
                    end
                end
            end
        end
        info.attributes:SizeToContents()
    end
end

local function createPage(container, you, inventory)
    container.fluxProfile = true
    local header = container:Add("Panel")
    container.profileHeader = header
    header.Paint = function(_, w, h)
        surface.SetDrawColor(10, 12, 13, 125)
        surface.DrawRect(0, 0, w, h)
    end
    container.characterTitle = ui.Label(header, "Your Character", "Flux.Shell.Heading", c.text, 36)
    container.characterSubtitle = ui.Label(header, "", "Flux.Shell.Small", c.accent, 28)
    local profile, belongings = container:Add("Panel"), container:Add("Panel")
    container.profileHost, container.inventoryHost = profile, belongings
    local scroll = ui.Scroll(belongings:Add("DScrollPanel"))
    local ownScroll = ui.Scroll(belongings:Add("DScrollPanel"))
    container.ownInventoryScroll = ownScroll
    container.inventoryScroll = scroll
    local inventoryHeading = ui.Label(belongings, "Inventory", "Flux.Shell.Heading", c.text)
    inventoryHeading:Dock(NODOCK)
    local containerHeading = ui.Label(belongings, "Container", "Flux.Shell.Heading", c.text)
    containerHeading:Dock(NODOCK)
    container.inventoryHeading, container.containerHeading = inventoryHeading, containerHeading
    for _, heading in ipairs({ inventoryHeading, containerHeading }) do
        heading.Paint = header.Paint
    end
    local provider = scroll:Add("Panel")
    provider:Dock(TOP)
    container.inventoryProvider = provider
    container.hasInventoryProvider = inventory ~= nil
    if inventory then
        if isfunction(inventory) then
            inventory(provider)
        else
            inventory:Create(provider)
        end
    else
        ui.Label(provider, "Inventory is unavailable.", "Flux.Body", c.muted, 40)
    end
    local canvas = ix.gui.menuInventoryContainer
    containerHeading:SetVisible(false)
    if IsValid(canvas) and canvas:GetParent() == provider then
        canvas:Dock(TOP)
        if IsValid(ix.gui.inv1) then
            ix.gui.inv1:SetParent(ownScroll:GetCanvas())
        end
        canvas.PerformLayout = function(panel)
            local scale = ui.WorkspaceScale()
            local width = math.max(belongings:GetWide() - 10, 40)
            local gap = 20 * scale
            local root = ix.gui.inv1
            local primaryColumns = IsValid(root) and root.gridW or 6
            local secondaryColumns = primaryColumns
            local opened = {}
            for _, child in ipairs(panel:GetChildren()) do
                if IsValid(child) and child ~= root and child.gridW and child.RebuildItems then
                    opened[#opened + 1] = child
                    secondaryColumns = math.max(secondaryColumns, child.gridW)
                end
            end
            local hasContainer = #opened > 0
            local columns = primaryColumns + (hasContainer and secondaryColumns or 0)
            local size = math.max(1, math.min(64, (width - (hasContainer and gap + 16 or 8)) / columns))
            local primaryWidth = primaryColumns * size + 8
            local columnX = primaryWidth + gap
            local top = 44 * scale
            ownScroll:SetPos(0, top)
            ownScroll:SetSize(primaryWidth + 5, math.max(belongings:GetTall() - top, 1))
            scroll:SetPos(columnX, top)
            scroll:SetSize(
                math.max(belongings:GetWide() - columnX, 1),
                math.max(belongings:GetTall() - top, 1)
            )
            scroll:SetVisible(hasContainer)
            containerHeading:SetVisible(hasContainer)
            local function place(inventory, x, y)
                inventory:SetPaintedManually(false)
                if math.abs(inventory:GetIconSize() - size) > 0.01 then
                    inventory:SetIconSize(size)
                    inventory:SetSize(
                        inventory.gridW * size + 8,
                        inventory.gridH * size + inventory:GetPadding(2) + inventory:GetPadding(4)
                    )
                    inventory:RebuildItems()
                end
                inventory:SetPos(x, y)
                return inventory:GetTall()
            end
            if IsValid(root) and root:GetParent() == ownScroll:GetCanvas() then
                place(root, 0, 0)
            end
            local nextY = 0
            for _, child in ipairs(opened) do
                nextY = nextY + place(child, 0, nextY) + 16 * scale
            end
            panel:SetTall(math.max(nextY, 120 * scale))
            provider:SetTall(panel:GetTall())
            inventoryHeading:SetPos(0, 0)
            inventoryHeading:SetSize(primaryColumns * size + 8, 36 * scale)
            containerHeading:SetPos(columnX, 0)
            containerHeading:SetSize(width - columnX, 36 * scale)
        end
        -- A hidden secondary scroll panel does not run normal layout passes.
        -- Native bag actions add/remove children here, so wake the layout then.
        for _, event in ipairs({ "OnChildAdded", "OnChildRemoved" }) do
            local previous = canvas[event]
            canvas[event] = function(panel, child)
                if previous then
                    previous(panel, child)
                end
                timer.Simple(0, function()
                    if IsValid(panel) then
                        panel:InvalidateLayout(true)
                    end
                end)
            end
        end
    end
    if you then
        if isfunction(you) then
            you(profile)
        else
            you:Create(profile)
        end
    end
    container.infoPanel = profile.infoPanel
    local info = container.infoPanel
    if IsValid(info) then
        info:Dock(FILL)
        info.fluxCompact = true
        profile.Paint = function(_, w, h)
            surface.SetDrawColor(10, 12, 13, 125)
            surface.DrawRect(0, 0, w, math.min(h, info:GetCanvas():GetTall() + 24 * ui.WorkspaceScale()))
        end
        info:DockMargin(0, 0, 8 * ui.WorkspaceScale(), 0)
        ui.Scroll(info)
        ui.StyleProfileInfo(info)
        if IsValid(info.description) then
            local heading =
                ui.Label(info, "Description", "Flux.Shell.Small", c.muted, 30 * ui.WorkspaceScale())
            heading:SetZPos(-4)
            container.descriptionHeading = heading
        end
        if IsValid(info.description) then
            info.description.SizeToContents = function(label)
                local width = math.max(info:GetWide() - 8, 40)
                local font = info.fluxCompact and "Flux.Shell.Small" or "Flux.Shell.Body"
                local lines = ix.util.WrapText(label:GetText(), width, font)
                surface.SetFont(font)
                local _, height = surface.GetTextSize("W")
                label:SetWide(width)
                label:SetWrap(true)
                label:SetTall(math.max(#lines, 1) * height + 8)
            end
        end
        local resized = info.OnSizeChanged
        info.OnSizeChanged = function(panel, w, h)
            if resized then
                resized(panel, w, h)
            end
            if IsValid(panel.description) then
                panel.description:SizeToContents()
            end
        end
        local update = info.Update
        info.Update = function(panel, character)
            if IsValid(panel.description) then
                panel.description.bWrap = nil
                panel.description:SetWrap(false)
            end
            update(panel, character)
            if IsValid(panel.class) and character then
                local class = ix.class.Get(character:GetClass())
                panel.class:SetVisible(class ~= nil)
                if class then
                    panel.class:SetLabelText("Job")
                    panel.class:SetText(L(class.name))
                end
            end
            ui.StyleProfileInfo(panel)
            container.characterTitle:SetText(IsValid(panel.name) and panel.name:GetText() or "Your Character")
            container.characterTitle:SetTooltip(container.characterTitle:GetText())
            container.characterSubtitle:SetText(IsValid(panel.faction) and panel.faction.text:GetText() or "")
            container:InvalidateLayout()
        end
    end
    function container:SetProfileSection(name)
        -- Retain direct inventory callers while keeping both views visible.
        self.profileSection = name == "Inventory" and "Inventory" or "Overview"
        profile:SetVisible(true)
        belongings:SetVisible(true)
    end
    container.PerformLayout = function(_, w, h)
        local scale = ui.WorkspaceScale()
        if IsValid(info) and info.fluxStyleScale ~= scale then
            ui.StyleProfileInfo(info)
        end
        if IsValid(container.descriptionHeading) then
            container.descriptionHeading:SetTall(26 * scale)
        end
        local left = math.min(w * 0.27, 300 * scale)
        local gap = 28 * scale
        local inset = 12 * scale
        header:DockPadding(inset, 4 * scale, inset, 4 * scale)
        profile:DockPadding(inset, inset, inset, inset)
        inventoryHeading:SetTextInset(inset, 0)
        containerHeading:SetTextInset(inset, 0)
        header:SetPos(0, 0)
        header:SetSize(left, 72 * scale)
        surface.SetFont("Flux.Shell.Heading")
        local nameWidth = surface.GetTextSize(container.characterTitle:GetText())
        container.characterTitle:SetFont(
            nameWidth > left - inset * 2 and "Flux.Shell.Body" or "Flux.Shell.Heading"
        )
        container.characterTitle:SetTall(36 * scale)
        container.characterSubtitle:SetTall(28 * scale)
        profile:SetPos(0, 92 * scale)
        profile:SetSize(left, h - 92 * scale)
        belongings:SetPos(left + gap, 0)
        belongings:SetSize(w - left - gap, h)
        inventoryHeading:SetPos(0, 0)
        inventoryHeading:SetSize(belongings:GetWide(), 36 * scale)
        if IsValid(canvas) and canvas:GetParent() == provider then
            canvas:InvalidateLayout(true)
        else
            scroll:SetPos(0, 44 * scale)
            scroll:SetSize(belongings:GetWide(), h - 44 * scale)
            ownScroll:SetVisible(false)
        end
    end
    container:SetProfileSection("Overview")
    container:InvalidateLayout(true)
    return profile, provider
end

function ui.MergeProfileTabs(tabs)
    local you, inventory = tabs.you, tabs.inv
    tabs.you = nil
    tabs.inv = {
        bDefault = true,
        Create = function(_, container)
            local profile, provider = createPage(container, you, inventory)
            container.fluxProviders = { { you, profile }, { inventory, provider } }
        end,
        OnSelected = function(_, container)
            for _, pair in ipairs(container.fluxProviders) do
                if istable(pair[1]) and pair[1].OnSelected then
                    pair[1]:OnSelected(pair[2])
                end
            end
            timer.Simple(0, function()
                if IsValid(container.infoPanel) then
                    container.infoPanel:Update(ui.GetCharacter())
                end
            end)
        end,
        OnDeselected = function(_, container)
            ui.ReleaseModel(container.preview)
            for _, pair in ipairs(container.fluxProviders) do
                if istable(pair[1]) and pair[1].OnDeselected then
                    pair[1]:OnDeselected(pair[2])
                end
            end
        end,
    }
end

-- Keep native storage permissions, money controls and transfer callbacks. Only
-- size/position the two inventories so wide containers stay on screen.
function ui.LayoutStorage(view)
    local own, opened = ix.gui.inv1, view.storageInventory
    if
        not IsValid(own)
        or own:GetParent() ~= view
        or not own.gridW
        or not IsValid(opened)
        or not opened.gridW
    then
        return
    end
    local gap, margin = 24 * ui.WorkspaceScale(), 32 * ui.WorkspaceScale()
    local function extra(panel, money)
        return panel:GetPadding(2)
            + panel:GetPadding(4)
            + (IsValid(money) and money:IsVisible() and money:GetTall() + 2 or 0)
    end
    local ownExtra, openedExtra = extra(own, view.localMoney), extra(opened, view.storageMoney)
    local size = math.max(
        1,
        math.min(
            64,
            (view:GetWide() - margin * 2 - gap - 16) / (own.gridW + opened.gridW),
            (view:GetTall() - margin * 2 - ownExtra) / own.gridH,
            (view:GetTall() - margin * 2 - openedExtra) / opened.gridH
        )
    )
    for _, panel in ipairs({ own, opened }) do
        if math.abs(panel:GetIconSize() - size) > 0.01 then
            panel:SetIconSize(size)
            panel:RebuildItems()
        end
        panel:SetDraggable(false)
    end
    own:SetSize(own.gridW * size + 8, own.gridH * size + ownExtra)
    opened:SetSize(opened.gridW * size + 8, opened.gridH * size + openedExtra)
    local x = (view:GetWide() - own:GetWide() - opened:GetWide() - gap) / 2
    local y = (view:GetTall() - math.max(own:GetTall(), opened:GetTall())) / 2
    opened:SetPos(x, y)
    own:SetPos(x + opened:GetWide() + gap, y)
end
local storageView = vgui.GetControlTable("ixStorageView")
if storageView and not storageView.fluxInventoryLayout then
    storageView.fluxInventoryLayout = true
    for _, name in ipairs({ "SetLocalInventory", "SetStorageInventory", "SetLocalMoney", "SetStorageMoney" }) do
        local original = storageView[name]
        storageView[name] = function(view, ...)
            original(view, ...)
            flux.ui.LayoutStorage(view)
        end
    end
    local layout = storageView.PerformLayout
    storageView.PerformLayout = function(view, ...)
        if layout then
            layout(view, ...)
        end
        flux.ui.LayoutStorage(view)
    end
end

local inventoryControl = vgui.GetControlTable("ixInventory")
if inventoryControl and not inventoryControl.fluxScaledDrop then
    inventoryControl.fluxScaledDrop = true
    local receive = inventoryControl.ReceiveDrop
    inventoryControl.ReceiveDrop = function(panel, panels, dropped, menuIndex, x, y)
        local dragged = panels[1]
        if IsValid(dragged) and dragged.gridW and dragged.gridH then
            -- Native drop/preview code uses half of its default 64px cell.
            -- Adjust coordinates before delegating when this grid is scaled.
            local offset = 32 - panel:GetIconSize() / 2
            x = x + (dragged.gridW - 1) * offset
            y = y + (dragged.gridH - 1) * offset
        end
        return receive(panel, panels, dropped, menuIndex, x, y)
    end
end
