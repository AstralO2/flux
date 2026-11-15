-- Optional presentation; character IDs, payload validation and transport stay native.
local ui, c = flux.ui, flux.ui.colors
local nativeForm = vgui.GetControlTable("ixCharMenuNew")
local rosterColors = {
    background = Color(24, 26, 27),
    text = Color(240, 240, 237),
    muted = Color(178, 180, 177),
    accent = Color(202, 190, 151),
    line = Color(81, 81, 73, 120),
    danger = Color(242, 108, 94),
}

local function rosterScale()
    return math.Clamp(math.min(ScrW() / 1672, ScrH() / 941), 0.65, 1.6)
end

local function rosterFonts()
    local scale = rosterScale()
    for name, definition in pairs({
        Brand = { 28, 600 },
        Title = { 42, 500 },
        Heading = { 27, 600 },
        Body = { 22, 400 },
        Small = { 19, 400 },
        Action = { 24, 600 },
    }) do
        surface.CreateFont("Flux.Roster." .. name, {
            font = "Roboto",
            size = math.max(13, math.floor(definition[1] * scale + 0.5)),
            weight = definition[2],
            extended = true,
        })
    end
end
rosterFonts()
hook.Add("OnScreenSizeChanged", "Flux.RosterFonts", rosterFonts)
hook.Add("OnScreenSizeChanged", "Flux.RosterLayout", function()
    local menu = ix.gui.characterMenu
    if not IsValid(menu) or not menu.fluxCustom then
        return
    end
    menu:SetSize(ScrW(), ScrH())
    menu:InvalidateLayout(true)
    if IsValid(menu.list) and not menu.creating then
        for _, row in ipairs(menu.list:GetCanvas():GetChildren()) do
            row:SetTall(79 * rosterScale())
            row:DockMargin(0, 0, 0, 12 * rosterScale())
        end
        menu:ShowCharacterTab(menu.activeTab)
    end
end)

local function rosterDate(timestamp, fallback)
    return isnumber(timestamp) and timestamp > 0 and os.date("%d %b %Y", timestamp)
        or fallback
        or "Not recorded"
end

local function rosterButton(button, primary)
    button:SetFont("Flux.Roster." .. (primary and "Action" or "Body"))
    button.UpdateColours = function() end
    button.Paint = function(panel, w, h)
        local hover = panel:IsHovered() and panel:IsEnabled()
        panel.fluxHover = ui.Ease(panel.fluxHover or 0, hover and 1 or 0)
        if primary then
            draw.RoundedBox(2, 0, 0, w, h, rosterColors.accent)
            surface.SetDrawColor(255, 255, 255, panel.fluxHover * 20)
            surface.DrawRect(0, 0, w, h)
            panel:SetTextColor(panel:IsEnabled() and rosterColors.background or Color(103, 100, 89))
            if not panel.rosterNoIcon then
                local x, y = 30 * rosterScale(), h / 2
                draw.NoTexture()
                surface.SetDrawColor(rosterColors.background)
                surface.DrawPoly({
                    { x = x, y = y - 8 * rosterScale() },
                    { x = x + 14 * rosterScale(), y = y },
                    { x = x, y = y + 8 * rosterScale() },
                })
            end
        else
            panel:SetTextColor(hover and Color(255, 155, 140) or rosterColors.danger)
        end
    end
end
local FORM = {}
for _, method in ipairs({
    "ResetPayload",
    "SetPayload",
    "AddPayloadHook",
    "RunPayloadHook",
    "VerifyProgression",
    "AttachCleanup",
}) do
    FORM[method] = nativeForm[method]
end

function FORM:Init()
    flux.characterUI.InstallReceivers()
    self:ResetPayload(true)
    self.inputs = {}
    self.repopulatePanels = {}
    self.scroll = ui.Scroll(self:Add("DScrollPanel"))
    self.scroll:Dock(FILL)
    self:AddPayloadHook("model", function(value)
        local faction = ix.faction.Get(self.payload.faction)
        local model = faction and faction:GetModels(LocalPlayer())[value]
        if model then
            self:GetParent():SetPreview(model)
        end
    end)
end

function FORM:GetContainerPanel()
    return self.scroll
end

function FORM:SetPayload(key, value)
    local menu = self:GetParent()
    if IsValid(menu) and menu.HideNotice and not self.awaitingResponse then
        menu:HideNotice()
    end
    nativeForm.SetPayload(self, key, value)
end

function FORM:Begin(faction)
    self:ResetPayload()
    self.payload:Set("faction", faction)
    self.payload:Set("model", 1)
    self:Populate()
end

function FORM:SelectFaction(index)
    -- Keep entered text when the player changes their faction or model.
    self.payload:Set("faction", index)
    self.payload:Set("model", 1)
    self:Populate()
end

function FORM:FocusSection(name)
    local label = self.sections and self.sections[name]
    if IsValid(label) then
        self:GetParent().creationSection = name
        self.scroll:ScrollToChild(label)
    end
end

function FORM:CycleModel(direction)
    local faction = ix.faction.Get(self.payload.faction)
    if not faction then
        return
    end
    local keys = {}
    for key in SortedPairs(faction:GetModels(LocalPlayer())) do
        keys[#keys + 1] = key
    end
    if #keys == 0 then
        return
    end
    local current = table.KeyFromValue(keys, self.payload.model) or 1
    self.payload:Set("model", keys[(current - 1 + direction) % #keys + 1])
    self:FocusSection("Appearance")
end

function FORM:StyleAttributes(panel)
    local scale, height = rosterScale(), 0
    -- A replacement provider may return a different editor entirely.
    for _, attribute in ipairs(panel:GetChildren()) do
        if
            not (
                IsValid(attribute.bar)
                and IsValid(attribute.label)
                and isfunction(attribute.GetValue)
                and isfunction(attribute.GetMax)
            )
        then
            return
        end
    end
    panel.Paint = function() end
    for _, attribute in ipairs(panel:GetChildren()) do
        if IsValid(attribute.bar) and IsValid(attribute.label) and isfunction(attribute.GetValue) then
            attribute:SetTall(34 * scale)
            attribute:DockMargin(0, 0, 0, 5 * scale)
            attribute.Paint = function() end
            attribute.label:SetFont("Flux.Roster.Small")
            attribute.label:SetTextColor(rosterColors.text)
            attribute.label:SetExpensiveShadow(0)
            attribute.label:SetContentAlignment(4)
            attribute.label:SetTextInset(8 * scale, 0)
            attribute.label:DockMargin(0, 0, 80 * scale, 4 * scale)
            attribute.bar.Paint = function(_, w, h)
                local maximum, value = attribute:GetMax(), attribute:GetValue()
                local progress = maximum > 0 and math.Clamp(attribute.deltaValue / maximum, 0, 1) or 0
                surface.SetDrawColor(31, 34, 35)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(rosterColors.line)
                surface.DrawRect(0, h - 3 * scale, w, 3 * scale)
                surface.SetDrawColor(rosterColors.accent)
                surface.DrawRect(0, h - 3 * scale, w * progress, 3 * scale)
                draw.SimpleText(
                    value .. " / " .. maximum,
                    "Flux.Roster.Small",
                    w - 8 * scale,
                    (h - 3 * scale) / 2,
                    rosterColors.accent,
                    TEXT_ALIGN_RIGHT,
                    TEXT_ALIGN_CENTER
                )
            end
            for _, direction in ipairs({ -1, 1 }) do
                local button = direction == 1 and attribute.add or attribute.sub
                if IsValid(button) then
                    button:SetImageVisible(false)
                    button:SetWide(28 * scale)
                    button:DockMargin(0, 0, 0, 0)
                    button:SetTooltip(direction == 1 and "Increase attribute" or "Decrease attribute")
                    button.Paint = function(control, w, h)
                        surface.SetDrawColor(
                            control:IsHovered() and rosterColors.accent or rosterColors.muted
                        )
                        local x, y, arm = w / 2, h / 2, 5 * scale
                        surface.DrawRect(x - arm, y - scale / 2, arm * 2, scale)
                        if direction == 1 then
                            surface.DrawRect(x - scale / 2, y - arm, scale, arm * 2)
                        end
                    end
                end
            end
            height = height + 39 * scale
        else
            height = height + attribute:GetTall()
        end
    end
    panel:SetTall(height)
end

function FORM:Populate()
    for _, panel in ipairs(self.repopulatePanels) do
        if IsValid(panel) then
            panel:Remove()
        end
    end
    self.repopulatePanels = {}
    self.scroll:Clear()
    self.inputs, self.sections = {}, {}
    local scale = rosterScale()
    local order = 0
    local function label(text, section)
        local panel = ui.Label(self.scroll, text, "Flux.Roster.Small", rosterColors.muted, 26 * scale)
        panel:SetZPos(order)
        panel:DockMargin(0, 0, 10 * scale, 4 * scale)
        order = order + 1
        if section then
            self.sections[section] = panel
        end
        return panel
    end
    label("Faction", "Faction")
    local factionChoice = self.scroll:Add("DComboBox")
    factionChoice:Dock(TOP)
    factionChoice:SetTall(42 * scale)
    factionChoice:SetFont("Flux.Roster.Body")
    factionChoice:SetTextColor(rosterColors.text)
    factionChoice:SetSortItems(false)
    factionChoice:SetZPos(order)
    factionChoice:DockMargin(0, 0, 10 * scale, 20 * scale)
    factionChoice.Paint = function(panel, w, h)
        surface.SetDrawColor(31, 34, 35)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(panel:IsHovered() and rosterColors.accent or rosterColors.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    order = order + 1
    for index, faction in ipairs(ix.faction.indices) do
        if ix.faction.HasWhitelist(index) then
            factionChoice:AddChoice(faction.name, index, index == self.payload.faction)
        end
    end
    factionChoice.OnSelect = function(_, _, _, index)
        if index ~= self.payload.faction then
            self:SelectFaction(index)
        end
    end
    self.factionChoice = factionChoice

    local definitions = {}
    for key, definition in SortedPairsByMemberValue(ix.char.vars, "index") do
        if key ~= "__SortedIndex" and not definition.bNoDisplay then
            definitions[#definitions + 1] = { key, definition }
        end
    end
    for _, section in ipairs({ "Appearance", "Details" }) do
        local heading = label(section, section)
        heading:SetTextColor(rosterColors.accent)
        for _, entry in ipairs(definitions) do
            local key, definition = entry[1], entry[2]
            if
                (key == "model" and "Appearance" or "Details") == section
                and (
                    not definition.ShouldDisplay
                    or definition:ShouldDisplay(self.scroll, self.payload) ~= false
                )
            then
                local fieldKey = key
                local fieldLabel = key ~= "model" and label(L(key)) or nil
                local panel
                if definition.OnDisplay then
                    panel = definition:OnDisplay(self.scroll, self.payload)
                elseif isstring(definition.default) then
                    panel = self.scroll:Add("ixTextEntry")
                    panel:SetTall(44 * scale)
                    panel:SetUpdateOnType(true)
                    panel.OnValueChange = function(_, value)
                        self.payload:Set(fieldKey, value)
                    end
                    panel:SetValue(self.payload[key] or "")
                end
                if not IsValid(panel) then
                    if IsValid(fieldLabel) then
                        fieldLabel:Remove()
                    end
                else
                    panel:Dock(TOP)
                    panel:SetZPos(order)
                    order = order + 1
                    panel:DockMargin(0, 0, 10 * scale, 16 * scale)
                    if definition.OnPostSetup then
                        definition:OnPostSetup(panel, self.payload)
                    end
                    if ui.IsTextEntry(panel) then
                        ui.TextEntry(panel, "Flux.Roster.Body")
                        if key == "description" then
                            panel:SetTall(92 * scale)
                        end
                        local focus = panel.OnGetFocus
                        panel.OnGetFocus = function(input)
                            self:GetParent().creationSection = section
                            if focus then
                                focus(input)
                            end
                        end
                    end
                    if key == "model" and isfunction(panel.GetCanvas) and isfunction(panel.GetVBar) then
                        panel:SetTall(162 * scale)
                        ui.Scroll(panel)
                        panel.Paint = function() end
                        local layout = panel:GetCanvas():GetChildren()[1]
                        if IsValid(layout) and isfunction(layout.SetSpaceX) then
                            layout:Dock(TOP)
                            layout:SetSpaceX(6 * scale)
                            layout:SetSpaceY(6 * scale)
                            local originalLayout = layout.PerformLayout
                            layout.PerformLayout = function(grid, w, h)
                                local size = math.max(44, math.floor((w - 30 * scale) / 6))
                                for _, icon in ipairs(grid:GetChildren()) do
                                    if icon:GetWide() ~= size or icon:GetTall() ~= size then
                                        icon:SetSize(size, size)
                                    end
                                end
                                if originalLayout then
                                    originalLayout(grid, w, h)
                                end
                            end
                        end
                    elseif key == "attributes" then
                        self:StyleAttributes(panel)
                    end
                    self.inputs[key] = panel
                    hook.Run("FluxCharacterFieldCreated", self, key, panel)
                end
            end
        end
    end
    self.scroll:InvalidateLayout(true)
end

function FORM:SendPayload()
    if self.awaitingResponse or not self:VerifyProgression() then
        return false
    end
    local count = 0
    for _, value in pairs(self.payload) do
        if not isfunction(value) then
            count = count + 1
        end
    end
    if count > 255 then
        self:GetParent():ShowNotice(3, "Too many character fields.")
        return false
    end
    self.awaitingResponse = true
    self:GetParent():ShowNotice(1, "Creating character…")
    self:GetParent().primary:SetEnabled(false)
    net.Start("ixCharacterCreate")
    net.WriteUInt(count, 8)
    for key, value in pairs(self.payload) do
        if not isfunction(value) then
            net.WriteString(key)
            net.WriteType(value)
        end
    end
    net.SendToServer()
    timer.Simple(10, function()
        if IsValid(self) and self.awaitingResponse then
            self.awaitingResponse = false
            self:GetParent().primary:SetEnabled(true)
            self:GetParent():ShowNotice(3, "The server did not respond. Please try again.")
        end
    end)
    return true
end

function FORM:SlideUp()
    self:GetParent():StartCreate()
end
function FORM:SlideDown()
    self:SetVisible(false)
end
function FORM:SetActiveSubpanel(name)
    self:FocusSection(name == "faction" and "Faction" or "Details")
end
vgui.Register("FluxCharacterForm", FORM, "EditablePanel")

local PANEL = {}

function PANEL:Init()
    -- Native Helix bars inspect this even while menu construction is deferred.
    self.currentAlpha = 255
    if flux.loading and isfunction(flux.loading.DeferMenu) and flux.loading.DeferMenu(self) then
        return
    end
    self:Build()
end

function PANEL:Build()
    self:SetVisible(true)
    if IsValid(ix.gui.loading) then
        ix.gui.loading:Remove()
    end
    if IsValid(ix.gui.characterMenu) and ix.gui.characterMenu ~= self then
        ix.gui.characterMenu:Remove()
    end
    if IsValid(ix.gui.menu) then
        ix.gui.menu:Remove()
    end
    if IsValid(ui.pause) then
        ui.pause:Remove()
    end
    ix.gui.characterMenu = self
    self.fluxCustom = true
    self.currentAlpha = 255
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self.rosterGradient = Material("vgui/gradient-l")
    self.rail = self:Add("Panel")
    self.listHeading = ui.Label(self.rail, "Your Characters", "Flux.Roster.Heading", rosterColors.text, 64)
    self.listHeading:SetContentAlignment(7)
    self.slotCount = self.rail:Add("DLabel")
    self.slotCount:SetFont("Flux.Roster.Body")
    self.slotCount:SetTextColor(rosterColors.muted)
    self.slotCount:SetContentAlignment(6)
    self.slotCount:SetText("")
    self.list = ui.Scroll(self.rail:Add("DScrollPanel"))
    self.list:Dock(FILL)
    self.list:SetZPos(20)
    self.createButton = ui.Button(self.rail, "+  New character", function()
        self:StartCreate()
    end)
    self.createButton:Dock(BOTTOM)
    self.createButton:DockMargin(0, 12, 0, 0)
    self.createButton:SetVisible(false)

    self.stage = self:Add("Panel")
    self.stage.Paint = function(_, w, h)
        -- A soft grounding shadow; the stage itself stays open to the backdrop.
        draw.NoTexture()
        for layer = 3, 1, -1 do
            local points = {}
            for step = 0, 40 do
                local angle = step / 40 * math.pi * 2
                points[#points + 1] = {
                    x = w * 0.5 + math.cos(angle) * w * (0.16 + layer * 0.035),
                    y = h * 0.92 + math.sin(angle) * h * (0.007 + layer * 0.005),
                }
            end
            surface.SetDrawColor(0, 0, 0, 16 + (4 - layer) * 8)
            surface.DrawPoly(points)
        end
    end
    self.preview = ui.Model(self.stage)
    self.preview:Dock(FILL)
    self.preview:SetMouseInputEnabled(false)
    self.preview:SetFOV(31.5)
    self.preview:SetLookAt(Vector(0, 0, 34))
    self.preview:SetAmbientLight(Color(135, 139, 140))
    self.preview:SetDirectionalLight(BOX_FRONT, Color(235, 225, 205))
    self.preview:SetDirectionalLight(BOX_BACK, Color(75, 85, 95))
    self.modelBar = self.stage:Add("Panel")
    self.modelBar:SetVisible(false)
    self.modelBar.Paint = function(_, w, h)
        draw.SimpleText(
            "Model Preview",
            "Flux.Roster.Small",
            w / 2,
            h / 2,
            rosterColors.muted,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end
    self.modelArrows = {}
    for _, direction in ipairs({ -1, 1 }) do
        local button = self.modelBar:Add("DButton")
        button:SetText("")
        button:SetTooltip(direction == -1 and "Previous model" or "Next model")
        button.DoClick = function()
            self.newCharacterPanel:CycleModel(direction)
        end
        button.Paint = function(panel, w, h)
            local color = panel:IsHovered() and rosterColors.accent or rosterColors.text
            surface.SetDrawColor(color)
            local x, y, arm = w / 2, h / 2, 6 * rosterScale()
            surface.DrawLine(x - direction * arm / 2, y - arm, x + direction * arm / 2, y)
            surface.DrawLine(x + direction * arm / 2, y, x - direction * arm / 2, y + arm)
        end
        self.modelArrows[#self.modelArrows + 1] = button
    end
    self.details = self:Add("Panel")
    self.title = ui.Label(self.details, "Characters", "Flux.Roster.Title", rosterColors.text, 52)
    self.subtitle = ui.Label(self.details, "", "Flux.Roster.Action", rosterColors.accent, 36)
    self.tabs = self.details:Add("Panel")
    self.tabs:Dock(TOP)
    self.tabs:SetZPos(10)
    self.tabs.Paint = function(_, w, h)
        surface.SetDrawColor(rosterColors.line)
        surface.DrawRect(0, h - 1, w, 1)
    end
    self.tabButtons = {}
    for index, name in ipairs({ "Overview", "Details" }) do
        local button = self.tabs:Add("DButton")
        button:SetText(name)
        button:SetFont("Flux.Roster.Body")
        button.UpdateColours = function() end
        button.DoClick = function()
            self:ShowCharacterTab(name)
        end
        button.Paint = function(panel, w, h)
            local selected = self.activeTab == name
            panel:SetTextColor(selected and rosterColors.text or rosterColors.muted)
            if selected then
                surface.SetDrawColor(rosterColors.accent)
                surface.DrawRect(0, h - 5 * rosterScale(), w, 5 * rosterScale())
            elseif panel:IsHovered() then
                surface.SetDrawColor(255, 255, 255, 4)
                surface.DrawRect(0, 0, w, h)
            end
        end
        self.tabButtons[index] = button
    end
    self.body = self.details:Add("DScrollPanel")
    self.body:Dock(FILL)
    self.body:SetZPos(20)
    ui.Scroll(self.body)
    self.actions = self.details:Add("Panel")
    self.actions:Dock(BOTTOM)
    self.actions:SetZPos(15)
    self.primary = ui.Button(self.actions, "Play Character", function()
        self:Continue()
    end)
    self.primary.fluxPrimary = true
    self.primary:SetContentAlignment(4)
    self.primary:SetTextInset(68 * rosterScale(), 0)
    rosterButton(self.primary, true)
    self.secondary = ui.Button(self.actions, "Delete Character", function()
        self:ConfirmDelete()
    end, true)
    self.secondary:SetContentAlignment(4)
    self.secondary:SetTextInset(26 * rosterScale(), 0)
    rosterButton(self.secondary, false)
    self.notice = ui.Label(self.actions, "", "Flux.Roster.Small", rosterColors.muted, 42)
    self.notice:SetWrap(true)
    self.newCharacterPanel = self:Add("FluxCharacterForm")
    self.newCharacterPanel:SetVisible(false)
    -- Preserve native menu callback entry points used by the character library.
    self.mainPanel = self.rail
    self.mainPanel.UpdateReturnButton = function()
        self:RefreshRoster()
    end
    self.mainPanel.Undim = function()
        self:RefreshRoster()
    end
    self.mainPanel.Dim = function() end
    self.loadCharacterPanel = self.list
    self.loadCharacterPanel.SlideUp = function()
        self:RefreshRoster()
    end
    self.loadCharacterPanel.SlideDown = function() end
    self.loadCharacterPanel.OnCharacterDeleted = function()
        self:RefreshRoster()
    end
    self:PerformLayout(ScrW(), ScrH())
    self:RefreshRoster()
    ui.FadeIn(self)
    hook.Run("OnCharacterMenuCreated", self)
end

function PANEL:PerformLayout(w, h)
    if not IsValid(self.rail) then
        return
    end
    local scale = rosterScale()
    local margin = math.Clamp(w * 0.042, 24, 110)
    local top = h * (self.creating and 0.105 or 0.142)
    local bottom = h * (self.creating and 0.08 or 0.115)
    local rail = w * (self.creating and 0.167 or 0.26)
    local details = w * (self.creating and 0.30 or 0.267)
    local detailsX = w - w * 0.032 - details
    local gap = w * 0.024
    self.margin, self.scale = margin, scale
    self.listHeading:SetTall(74 * scale)
    self.listHeading:SetTextInset(0, 12 * scale)
    self.rail:SetPos(margin, top)
    self.rail:SetSize(rail, h - top - bottom)
    self.slotCount:SetPos(rail - 70 * scale, 0)
    self.slotCount:SetSize(70 * scale, 44 * scale)
    self.stage:SetPos(margin + rail + gap, top - 15 * scale)
    self.stage:SetSize(detailsX - margin - rail - gap * 2, h - top - bottom + 15 * scale)
    self.preview:SetFOV(self.creating and 37 or 31.5)
    self.modelBar:SetPos(0, self.stage:GetTall() - 38 * scale)
    self.modelBar:SetSize(self.stage:GetWide(), 38 * scale)
    for index, button in ipairs(self.modelArrows) do
        button:SetSize(38 * scale, 38 * scale)
        button:SetPos(self.stage:GetWide() / 2 + (index == 1 and -125 or 87) * scale, 0)
    end
    self.details:SetPos(detailsX, top - 7 * scale)
    self.details:SetSize(details, h - top - bottom + 7 * scale)
    self.title:SetTall(52 * scale)
    self.subtitle:SetTall(36 * scale)
    self.tabs:SetTall(62 * scale)
    self.tabs:DockMargin(0, 8 * scale, 0, 28 * scale)
    for index, button in ipairs(self.tabButtons) do
        button:SetPos((index - 1) * details / #self.tabButtons, 0)
        button:SetSize(details / #self.tabButtons - 16 * scale, 62 * scale)
    end
    self.actions:SetTall((self.creating and 94 or 154) * scale)
    self.actions:DockPadding(0, 8 * scale, 0, 0)
    self.primary:SetTall((self.creating and 44 or 54) * scale)
    self.primary:DockMargin(0, 0, 0, self.creating and 0 or 13 * scale)
    self.primary:SetTextInset(self.creating and 0 or 68 * scale, 0)
    self.primary:SetContentAlignment(self.creating and 5 or 4)
    self.primary:SetZPos(self.creating and 1 or 0)
    self.secondary:SetTall(42 * scale)
    self.secondary:DockMargin(0, 0, 0, 0)
    self.notice:SetTall(30 * scale)
    self.notice:SetZPos(self.creating and 0 or 2)
    self.secondary:SetZPos(self.creating and 2 or 1)
    self.newCharacterPanel:SetPos(detailsX, top + 90 * scale)
    self.newCharacterPanel:SetSize(
        details,
        h - top - bottom - 90 * scale - (self.creating and 94 or 154) * scale
    )
    self.createButton:SetTall(42 * scale)
    self.createButton:SetFont("Flux.Roster.Small")
end

function PANEL:SetPreview(model, character)
    local path = istable(model) and model[1] or model
    if not isstring(path) or not util.IsValidModel(path) then
        path = "models/player/kleiner.mdl"
    end
    self.preview:SetModel(path)
    if IsValid(self.preview.Entity) then
        local sequence = self.preview.Entity:LookupSequence("idle_all_01")
        if sequence < 0 then
            sequence = self.preview.Entity:LookupSequence("idle")
        end
        if sequence >= 0 then
            self.preview.Entity:ResetSequence(sequence)
        end
        self.preview.Entity:SetSkin(
            istable(model) and model[2] or character and character:GetData("skin", 0) or 0
        )
        if istable(model) and isstring(model[3]) then
            self.preview.Entity:SetBodyGroups(model[3])
        end
        if character then
            for id, value in pairs(character:GetData("groups", {})) do
                self.preview.Entity:SetBodygroup(id, value)
            end
        end
    end
end

function PANEL:AddRosterRow(character)
    local row = self.list:Add("DButton")
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 12 * rosterScale())
    row:SetTall(79 * rosterScale())
    row:SetText("")
    row.character = character
    row:SetTooltip(character and character:GetName() or "Create a character in this slot")
    row.DoClick = function()
        if character then
            self:SelectCharacter(character)
        else
            self:StartCreate()
        end
    end
    row.Paint = function(panel, w, h)
        local scale = rosterScale()
        local selected = character and self.selected == character
        panel.hover = ui.Ease(panel.hover or 0, panel:IsHovered() and 1 or 0)
        if selected or panel.hover > 0.01 then
            surface.SetMaterial(self.rosterGradient)
            surface.SetDrawColor(99, 102, 94, selected and 27 or panel.hover * 15)
            surface.DrawTexturedRect(0, 0, w, h)
        end
        if selected then
            draw.RoundedBox(1, 0, 0, 7 * scale, h, rosterColors.accent)
        end
        local faction = character and ix.faction.Get(character:GetFaction())
        local inset = character and 40 * scale or 78 * scale
        if not character then
            surface.SetDrawColor(rosterColors.muted)
            local x, y, arm = 29 * scale, h / 2, 10 * scale
            surface.DrawRect(x - arm, y - scale, arm * 2, 2 * scale)
            surface.DrawRect(x - scale, y - arm, 2 * scale, arm * 2)
        end
        draw.SimpleText(
            character and character:GetName() or "Create Character",
            "Flux.Roster.Body",
            inset,
            15 * scale,
            rosterColors.text
        )
        draw.SimpleText(
            character and (faction and faction.name or "") or "Empty Slot",
            "Flux.Roster.Small",
            inset,
            45 * scale,
            selected and rosterColors.accent or rosterColors.muted
        )
    end
    return row
end

function PANEL:RefreshRoster(selectedID)
    self.creating, self.deleting, self.requesting = false, false, false
    self.subtitle:SetFont("Flux.Roster.Action")
    self.subtitle:SetTextColor(rosterColors.accent)
    self.modelBar:SetVisible(false)
    self.listHeading:SetVisible(true)
    self.rail:DockPadding(0, 0, 0, 0)
    self.newCharacterPanel:SetVisible(false)
    self.primary.DoClick = function()
        self:Continue()
    end
    self.body:SetVisible(true)
    self.tabs:SetVisible(true)
    self.list:Clear()
    self.listHeading:SetText("Your Characters")
    self.slotCount:SetVisible(true)
    self.createButton:SetVisible(false)
    self.createButton:SetText("+  New character")
    self.createButton.DoClick = function()
        self:StartCreate()
    end
    local client = LocalPlayer()
    self.waitingForPlayer = not IsValid(client) or not isfunction(client.GetCharacter)
    self.createButton:SetEnabled(not self.waitingForPlayer)
    if self.waitingForPlayer then
        self.selected = nil
        self.title:SetText("Loading characters")
        self.subtitle:SetText("Waiting for your player to be ready…")
        self.body:Clear()
        self.primary:SetEnabled(false)
        self.secondary:SetVisible(false)
        self.tabs:SetVisible(false)
        return
    end
    local maximum = hook.Run("GetMaxPlayerCharacter", client) or ix.config.Get("maxCharacters", 5)
    self.slotCount:SetText(#(ix.characters or {}) .. " / " .. maximum)
    local first
    for _, id in ipairs(ix.characters or {}) do
        local character = ix.char.loaded[id]
        if character then
            first = first or character
            self:AddRosterRow(character)
        end
    end
    -- Represent every unused slot; the roster scrolls when the limit exceeds its height.
    for _ = 1, maximum - #(ix.characters or {}) do
        self:AddRosterRow()
    end
    local active = ui.GetCharacter()
    local selected = selectedID and ix.char.loaded[selectedID] or self.selected or active or first
    if selected and ix.char.loaded[selected:GetID()] then
        self:SelectCharacter(selected)
    else
        self.selected = nil
        self.title:SetText("No characters yet")
        self.subtitle:SetText("Create your first character")
        self.body:Clear()
        self.tabs:SetVisible(false)
        local info = ui.Label(
            self.body,
            "Choose a faction, add a name and select an appearance to get started.",
            "Flux.Body",
            c.muted,
            100
        )
        info:SetWrap(true)
        self:SetPreview("models/player/kleiner.mdl")
        self.primary:SetText("Create character")
        self.primary:SetEnabled(true)
        self.secondary:SetVisible(false)
    end
    if flux.roster then
        flux.roster.Request()
    end
    self:InvalidateLayout(true)
end

function PANEL:Think()
    if self.waitingForPlayer then
        local client = LocalPlayer()
        if IsValid(client) and isfunction(client.GetCharacter) then
            self:RefreshRoster()
        end
    end
end

function PANEL:ShowCharacterTab(name)
    if not self.selected or self.creating or self.deleting then
        return
    end
    self.activeTab = name == "Details" and "Details" or "Overview"
    self.body:Clear()
    self.editDescription = nil
    local character = self.selected
    local faction = ix.faction.Get(character:GetFaction())
    local metadata = flux.roster and flux.roster.records[character:GetID()] or {}
    metadata = metadata or {}
    local scale = rosterScale()
    local function text(value, muted, height)
        local label = ui.Label(
            self.body,
            value,
            "Flux.Roster.Body",
            muted and rosterColors.muted or rosterColors.text,
            height or 30 * scale
        )
        label:SetContentAlignment(7)
        return label
    end
    local function rule()
        local panel = ui.Rule(self.body, 24 * scale, 20 * scale)
        panel.Paint = function(_, w)
            surface.SetDrawColor(rosterColors.line)
            surface.DrawRect(0, 0, w, 1)
        end
    end
    local function row(label, value, accent)
        local panel = self.body:Add("Panel")
        panel:Dock(TOP)
        panel:SetTall(42 * scale)
        local key = panel:Add("DLabel")
        key:Dock(LEFT)
        key:SetWide(118 * scale)
        key:SetFont("Flux.Roster.Body")
        key:SetTextColor(rosterColors.muted)
        key:SetText(label)
        local result = panel:Add("DLabel")
        result:Dock(FILL)
        result:SetFont("Flux.Roster.Body")
        result:SetContentAlignment(6)
        result:SetTextColor(accent and rosterColors.accent or rosterColors.text)
        result:SetText(tostring(value))
        result:SetTooltip(tostring(value))
    end
    local created = rosterDate(metadata.created)
    local lastPlayed = ui.GetCharacter() == character and "This session"
        or metadata.lastPlayed and metadata.lastPlayed > 0 and metadata.lastPlayed == metadata.created and "Never"
        or rosterDate(metadata.lastPlayed)
    if self.activeTab == "Overview" then
        text("Description", true, 32 * scale)
        local description = text(character:GetDescription(), false)
        description:SetWrap(true)
        description:SetAutoStretchVertical(true)
        description:DockMargin(0, 0, 5 * scale, 4 * scale)
        if ui.GetCharacter() == character then
            self.editDescription = ui.Button(self.body, "Edit Description", ui.EditDescription)
            self.editDescription:SetFont("Flux.Roster.Small")
            self.editDescription:SetTall(34 * scale)
            self.editDescription:DockMargin(0, 8 * scale, 0, 0)
        end
        rule()
        row("Faction", faction and faction.name or "Unaffiliated", true)
        row("Created", created)
        row("Last Played", lastPlayed)
    elseif self.activeTab == "Details" then
        text("Character Details", true, 40 * scale)
        row("Name", character:GetName())
        row("Faction", faction and faction.name or "Unaffiliated", true)
        local class = ix.class.Get(character:GetClass())
        row("Job", class and class.name or "Unassigned")
        row("Wallet", ix.currency.Get(character:GetMoney()))
        rule()
        text("Appearance", true, 32 * scale)
        local model = text(character:GetModel(), false)
        model:SetWrap(true)
        model:SetAutoStretchVertical(true)
    end
end

function PANEL:SelectCharacter(character)
    if self.requesting then
        return
    end
    self.creating, self.deleting = false, false
    self.selected = character
    self.newCharacterPanel:SetVisible(false)
    self.body:SetVisible(true)
    self.tabs:SetVisible(true)
    self.title:SetText(character:GetName())
    local faction = ix.faction.Get(character:GetFaction())
    self.subtitle:SetText(faction and faction.name or "")
    self:ShowCharacterTab(self.activeTab)
    self:SetPreview(character:GetModel(), character)
    self.primary.rosterNoIcon = false
    self.primary:SetText(ui.GetCharacter() == character and "Return to Game" or "Play Character")
    self.primary:SetEnabled(true)
    self.secondary:SetVisible(true)
    self.secondary:SetText("Delete Character")
    self.secondary.DoClick = function()
        self:ConfirmDelete()
    end
    self:HideNotice()
end

function PANEL:StartCreate()
    local client = LocalPlayer()
    if not IsValid(client) or not isfunction(client.GetCharacter) then
        self:ShowNotice(1, "Waiting for your player to be ready…")
        return
    end
    if self.requesting or self.newCharacterPanel.awaitingResponse then
        return
    end
    local maximum = hook.Run("GetMaxPlayerCharacter", LocalPlayer()) or ix.config.Get("maxCharacters", 5)
    if #(ix.characters or {}) >= maximum then
        self:ShowNotice(3, L("maxCharacters"))
        return
    end
    self.creating, self.deleting = true, false
    self.primary.rosterNoIcon = true
    self.primary.DoClick = function()
        self:Continue()
    end
    self.title:SetText("Create Character")
    self.subtitle:SetText("Make this character your own.")
    self.subtitle:SetFont("Flux.Roster.Small")
    self.subtitle:SetTextColor(rosterColors.muted)
    self.body:SetVisible(false)
    self.tabs:SetVisible(false)
    self.newCharacterPanel:SetVisible(true)
    self.listHeading:SetVisible(false)
    self.rail:DockPadding(0, 14 * rosterScale(), 0, 0)
    self.slotCount:SetVisible(false)
    self.createButton:SetVisible(true)
    self.list:Clear()
    local first
    for index, faction in ipairs(ix.faction.indices) do
        if ix.faction.HasWhitelist(index) then
            first = first or index
        end
    end
    self.createButton:SetText("Back to Characters")
    self.createButton.DoClick = function()
        if not self.newCharacterPanel.awaitingResponse then
            self:RefreshRoster()
        end
    end
    self.secondary:SetVisible(false)
    self.primary:SetText("Create Character")
    self.primary:SetEnabled(first ~= nil)
    self:HideNotice()
    self.modelBar:SetVisible(true)
    self:InvalidateLayout(true)
    if first then
        self.newCharacterPanel:Begin(first)
    else
        self:ShowNotice(3, "There are no available factions.")
    end
end

function PANEL:Continue()
    if self.creating then
        return self.newCharacterPanel:SendPayload()
    end
    if not self.selected then
        self:StartCreate()
        return
    end
    if self.deleting then
        return
    end
    self:ChooseCharacter(self.selected:GetID())
end

function PANEL:ChooseCharacter(id)
    if self.requesting then
        return
    end
    local active = ui.GetCharacter()
    if active and active:GetID() == id then
        self:Close()
        return
    end
    self.requesting = true
    self.primary:SetEnabled(false)
    self:ShowNotice(1, "Loading character…")
    net.Start("ixCharacterChoose")
    net.WriteUInt(id, 32)
    net.SendToServer()
    timer.Simple(10, function()
        if IsValid(self) and self.requesting then
            self:OnCharacterLoadFailed("The server did not respond. Please try again.")
        end
    end)
end

function PANEL:ConfirmDelete()
    if not self.selected or self.requesting then
        return
    end
    self.deleting = true
    self.tabs:SetVisible(false)
    self.primary.rosterNoIcon = true
    self.body:Clear()
    self.title:SetText("Delete character?")
    local label = ui.Label(
        self.body,
        "This permanently removes this character and their inventory. Type the character's name to confirm.",
        "Flux.Body",
        c.muted,
        100
    )
    label:SetWrap(true)
    self.deleteEntry = ui.TextEntry(self.body:Add("DTextEntry"))
    self.deleteEntry:Dock(TOP)
    self.deleteEntry:SetTall(44)
    self.deleteEntry:SetPlaceholderText(self.selected:GetName())
    self.deleteEntry:SetUpdateOnType(true)
    self.deleteEntry.OnValueChange = function(_, value)
        self.primary:SetEnabled(value == self.selected:GetName())
    end
    self.primary:SetText("Permanently delete")
    self.primary:SetEnabled(false)
    self.primary.DoClick = function()
        if self.deleteEntry:GetValue() ~= self.selected:GetName() then
            return
        end
        self.requesting = true
        self.primary:SetEnabled(false)
        net.Start("ixCharacterDelete")
        net.WriteUInt(self.selected:GetID(), 32)
        net.SendToServer()
        timer.Simple(10, function()
            if IsValid(self) and self.requesting and self.deleting then
                self.requesting = false
                self.primary:SetEnabled(true)
                self:ShowNotice(3, "The server did not confirm deletion. Please try again.")
            end
        end)
    end
    self.secondary:SetText("Keep character")
    self.secondary.DoClick = function()
        self:RefreshRoster()
    end
end

function PANEL:ShowNotice(kind, text)
    self.notice:SetText(text)
    self.notice:SetTextColor(kind == 3 and c.danger or c.muted)
end
function PANEL:HideNotice()
    self.notice:SetText("")
end
function PANEL:OnCharacterDeleted()
    self.selected = nil
    self.primary.DoClick = function()
        self:Continue()
    end
    self:RefreshRoster()
    self:ShowNotice(1, "Character deleted.")
end

function PANEL:OnKeyCodePressed(key)
    if key == KEY_ESCAPE and ui.GetCharacter() then
        ui.HandleEscape()
    end
end
function PANEL:OnCharacterLoadFailed(message)
    self.requesting = false
    self.primary:SetEnabled(true)
    self:ShowNotice(3, message)
end
function PANEL:IsClosing()
    return self.bClosing == true
end
function PANEL:PlayMusic() end -- Native intro can call this; Flux intentionally uses no menu music.
function PANEL:Close()
    if self.bClosing then
        return
    end
    self.bClosing = true
    ui.ReleaseModel(self.preview)
    self:SetMouseInputEnabled(false)
    self:SetKeyboardInputEnabled(false)
    self:AlphaTo(0, ix.option.Get("fluxMotion", true) and 0.16 or 0, 0, function()
        if IsValid(self) then
            self:Remove()
        end
    end)
end
function PANEL:Paint(w, h)
    local scale, margin = self.scale or rosterScale(), self.margin or 40
    surface.SetDrawColor(rosterColors.background)
    surface.DrawRect(0, 0, w, h)
    local headerY, headerLine = 40 * scale, 74 * scale
    draw.SimpleText(
        "FLUX",
        "Flux.Roster.Brand",
        margin,
        headerY,
        rosterColors.text,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
    local players = player.GetCount() .. " / " .. game.MaxPlayers()
    surface.SetFont("Flux.Roster.Small")
    local countWidth = surface.GetTextSize(players)
    draw.SimpleText(
        players,
        "Flux.Roster.Small",
        w - margin,
        headerY,
        rosterColors.text,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
    local divider = w - margin - countWidth - 28 * scale
    surface.SetDrawColor(rosterColors.line)
    surface.DrawRect(divider, 29 * scale, 1, 22 * scale)
    draw.SimpleText(
        GetHostName(),
        "Flux.Roster.Small",
        divider - 28 * scale,
        headerY,
        rosterColors.text,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
    surface.SetDrawColor(rosterColors.line)
    surface.DrawRect(margin - 14 * scale, headerLine, w - margin * 2 + 28 * scale, 1)
    local footer = h - 65 * scale
    surface.DrawRect(margin - 14 * scale, footer, w - margin * 2 + 28 * scale, 1)
    draw.SimpleText(
        "FLUX v" .. flux.version,
        "Flux.Roster.Small",
        margin - 4 * scale,
        h - 37 * scale,
        rosterColors.muted,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
    draw.SimpleText(
        "A HELIX FRAMEWORK",
        "Flux.Roster.Small",
        w - margin + 4 * scale,
        h - 37 * scale,
        rosterColors.muted,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
end
vgui.Register("FluxCharacterMenu", PANEL, "EditablePanel")

flux.characterUI = flux.characterUI or {}
function flux.characterUI.InstallReceivers()
    net.Receive("ixCharacterAuthed", function()
        local id, count = net.ReadUInt(32), net.ReadUInt(6)
        ix.characters = {}
        for _ = 1, count do
            ix.characters[#ix.characters + 1] = net.ReadUInt(32)
        end
        local menu = ix.gui.characterMenu
        if not IsValid(menu) then
            return
        end
        menu.newCharacterPanel.awaitingResponse = false
        if ui.GetCharacter() then
            menu:RefreshRoster(id)
            menu:ShowNotice(1, "Character created.")
        else
            menu:ChooseCharacter(id)
        end
    end)

    net.Receive("ixCharacterAuthFailed", function()
        local message, arguments = net.ReadString(), net.ReadTable()
        local menu = ix.gui.characterMenu
        if not IsValid(menu) then
            return
        end
        menu.newCharacterPanel.awaitingResponse = false
        menu.primary:SetEnabled(true)
        menu:ShowNotice(3, L(message, unpack(arguments)))
    end)
end
