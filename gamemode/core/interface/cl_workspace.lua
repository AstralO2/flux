-- Keep the native tab registry and callbacks, with a new Flux menu shell.
local ui, c = flux.ui, flux.ui.colors
local shell = ui.workspaceColors
if not vgui.GetControlTable("FluxNativeMenu") then
    vgui.Register("FluxNativeMenu", table.Copy(vgui.GetControlTable("ixMenu")), "ixSubpanelParent")
end
local PANEL = {}
-- Reuse methods, not the native control as a base: VGUI runs base Init methods
-- too, which would construct the old menu underneath this one.
local nativeMenu = vgui.GetControlTable("FluxNativeMenu")
local hiddenTabs = { business = true, classes = true, roles = true, assignments = true, scoreboard = true }

function ui.MenuTabOrder(tabs)
    local order, priority = {}, { inv = 1, settings = 2, help = 3 }
    for name in pairs(tabs) do
        order[#order + 1] = name
    end
    table.sort(order, function(a, b)
        local first, second = priority[a] or 4, priority[b] or 4
        return first == second and a < b or first < second
    end)
    return order
end

function ui.CanShowMenuTab(name)
    local root = name:match("^[^/]+")
    if hiddenTabs[root] then
        return false
    end
    if root == "config" then
        local client = LocalPlayer()
        return IsValid(client) and client:IsAdmin()
    end
    return true
end
for _, method in ipairs({
    "Remove",
    "GetCharacterOverview",
    "GetOverviewInfo",
    "GetActiveTab",
}) do
    PANEL[method] = nativeMenu[method]
end

local function styleSettings(settings)
    if not IsValid(settings) or not settings.GetRows then
        return
    end
    for _, row in ipairs(settings:GetRows()) do
        row:DockPadding(12, 12, 12, 12)
        row:GetLabel():SetFont("Flux.Body")
        row:GetLabel():SetTextColor(c.text)
        row:GetLabel():SetExpensiveShadow(0)
        row:SizeToContents()
        row.Paint = function(_, w, h)
            surface.SetDrawColor(c.line)
            surface.DrawLine(0, h - 1, w, h - 1)
        end
        if IsValid(row.setting) then
            local control = row.setting
            if control.SetFont then
                control:SetFont("Flux.Small")
            end
            if control.SetTextColor then
                control:SetTextColor(c.text)
            end
            if control.GetChecked then
                control:SetText("")
                control:SetWide(46)
                control.Paint = function(toggle, w, h)
                    local checked = toggle:GetChecked()
                    draw.RoundedBox(9, w - 36, h / 2 - 9, 36, 18, checked and c.accent or c.line)
                    draw.RoundedBox(6, w - (checked and 15 or 33), h / 2 - 6, 12, 12, c.background)
                end
            elseif ui.IsTextEntry(control) then
                ui.TextEntry(control, "Flux.Small")
            elseif control.GetLabel and control.GetSlider then
                -- Native numeric sliders keep their value in a separate label.
                local value = control:GetLabel()
                value:SetFont("Flux.Small")
                value:SetTextColor(c.text)
                value:SizeToContents()
                if row.OpenEntry and not row.fluxEntryStyled then
                    local openEntry = row.OpenEntry
                    row.OpenEntry = function(setting, ...)
                        openEntry(setting, ...)
                        if IsValid(setting.entry) and IsValid(setting.entry.textEntry) then
                            ui.TextEntry(setting.entry.textEntry, "Flux.Small")
                        end
                    end
                    row.fluxEntryStyled = true
                end
            end
        end
    end
    if settings.canvas then
        ui.Scroll(settings.canvas)
    end
    for name, category in pairs(settings.categories or {}) do
        category.paddingTop = 38
        category:DockPadding(0, 38, 0, 0)
        category.Paint = function(_, w)
            draw.SimpleText(name, "Flux.Heading", 0, 3, c.text)
        end
    end
    settings:SizeToContents()
end

function PANEL:Init()
    if IsValid(ix.gui.menu) then
        ix.gui.menu:Remove()
    end
    if IsValid(ui.pause) then
        ui.pause:Remove()
    end
    ix.gui.menu = self
    self.fluxCustom = true
    self.currentAlpha, self.currentBlur = 255, 0
    self.fluxAdmin = LocalPlayer():IsAdmin()
    self.manualChildren = {}
    self.subpanels = {}
    self.rotationOffset = Angle(0, 180, 0)
    self.projectedTexturePosition = Vector(0, 0, 6)
    self.projectedTextureRotation = Angle(-45, 60, 0)
    self.overviewFraction, self.bCharacterOverview, self.bOverviewOut = 0, false, false
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:SetPadding(28)
    self:UpdateGeometry()
    self.navigationGradient = Material("vgui/gradient-l")
    self.buttons = self:Add("Panel")
    self.tabs = ui.Scroll(self.buttons:Add("DScrollPanel"))
    self.tabs:Dock(FILL)
    self.tabs:SetZPos(20)
    self.tabs.buttons = {}
    self.exitButton = ui.Button(self.buttons, "Disconnect", function()
        if IsValid(ui.exitConfirmation) then
            return
        end
        ui.exitConfirmation = ui.Confirm("Exit server", "Leave this server?", "Exit server", function()
            RunConsoleCommand("disconnect")
        end)
    end, true)
    self.exitButton:Dock(BOTTOM)
    self.exitButton:SetZPos(0)
    local characters = ui.Button(self.buttons, "Change Character", function()
        self:Remove()
        ui.OpenCharacters()
    end)
    characters:Dock(BOTTOM)
    characters:SetZPos(1)
    self.charactersButton = characters
    for _, button in ipairs({ characters, self.exitButton }) do
        button:SetFont("Flux.Shell.Small")
        button.UpdateColours = function() end
        button.Paint = function(control, w, h)
            local hovered = control:IsHovered()
            control:SetTextColor(control == self.exitButton and shell.danger or shell.text)
            surface.SetDrawColor(31, 34, 35)
            surface.DrawRect(0, 0, w, h)
            if hovered then
                surface.SetDrawColor(255, 255, 255, 9)
                surface.DrawRect(0, 0, w, h)
            end
            surface.SetDrawColor(shell.line)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
    end
    self:PerformLayout()
    self:PopulateTabs()
    self:MakePopup()
    ui.FadeIn(self)
end

function PANEL:Add(name)
    return vgui.Create(name, self)
end
function PANEL:GetStandardSubpanelSize()
    return self.contentWidth, self.contentHeight - 62 * self.scale
end
function PANEL:UpdateGeometry()
    local w, h = self:GetWide(), self:GetTall()
    self.scale = ui.WorkspaceScale()
    self.margin = math.Clamp(w * 0.042, 24, 110)
    self.sidebar = math.Clamp(w * 0.167, 190, 350)
    self.contentX = self.margin + self.sidebar + w * 0.024
    self.contentY = 112 * self.scale
    self.contentWidth = w - self.contentX - self.margin
    self.contentHeight = h - self.contentY - self.margin
end
function PANEL:AddSubpanel(name)
    local panel = self:Add("ixSubpanel")
    panel.subpanelName, panel.subpanelID = name, #self.subpanels + 1
    panel:SetTitle(nil)
    local you = name == "inv"
    panel:SetPos(self.contentX, self.contentY + (you and 0 or 62 * self.scale))
    panel:SetSize(self.contentWidth, self.contentHeight - (you and 0 or 62 * self.scale))
    panel:SetVisible(false)
    self.subpanels[panel.subpanelID] = panel
    return panel
end

function PANEL:SetupTab(name, info, parentName)
    local qualified = parentName and parentName .. "/" .. name or name
    if not ui.CanShowMenuTab(qualified) then
        return
    end
    local panel = self:AddSubpanel(qualified)
    panel.info = info
    local button = self.tabs:Add("ixMenuSelectionButton")
    button:SetText(name == "inv" and "YOU" or L(name), true)
    button:SetFont("Flux.Shell.Body")
    button:SetTextColor(shell.text)
    button:SetContentAlignment(4)
    button:SetTextInset((parentName and 40 or 24) * self.scale, 0)
    button:SetTall(60 * self.scale)
    button:Dock(TOP)
    button:DockMargin(0, 0, 0, 4 * self.scale)
    button:SetButtonList(self.tabs.buttons)
    button:SetBackgroundColor(c.hover)
    button.name, button.id = qualified, panel.subpanelID
    button.OnSelected = function()
        self:TransitionSubpanel(panel.subpanelID)
    end
    if istable(info) and info.PopulateTabButton then
        info:PopulateTabButton(button)
    end
    button.Paint = function(row, w, h)
        row.fluxHover = ui.Ease(row.fluxHover or 0, row:IsHovered() and 1 or 0)
        surface.SetDrawColor(10, 12, 13, 115)
        surface.DrawRect(0, 0, w, h)
        if row:GetSelected() then
            surface.SetMaterial(self.navigationGradient)
            surface.SetDrawColor(99, 102, 94, 40)
            surface.DrawTexturedRect(0, 0, w, h)
            surface.SetDrawColor(shell.accent)
            surface.DrawRect(0, 0, 5 * self.scale, h)
        else
            surface.SetDrawColor(255, 255, 255, row.fluxHover * 4)
            surface.DrawRect(0, 0, w, h)
        end
        row:SetTextColor(row:GetSelected() and shell.text or shell.muted)
    end
    if istable(info) and info.Sections and not parentName then
        for childName, childInfo in SortedPairs(info.Sections) do
            self:SetupTab(childName, childInfo, name)
        end
    end
    return istable(info) and info.bDefault, button, panel
end

function PANEL:PopulateTabs()
    local tabs, first, preferred = {}, nil, nil
    hook.Run("CreateMenuButtons", tabs)
    ui.MergeProfileTabs(tabs)
    for _, name in ipairs(ui.MenuTabOrder(tabs)) do
        local info = tabs[name]
        if ui.CanShowMenuTab(name) then
            local default, button = self:SetupTab(name, info)
            first = first or button
            if default then
                preferred = button
            end
        end
    end
    for _, button in ipairs(self.tabs.buttons) do
        if button.name == "inv" then
            preferred = button
            break
        end
    end
    local selected = preferred or first
    if selected then
        selected:SetSelected(true)
    end
end

function PANEL:SetActiveSubpanel(id)
    if id == "you" then
        id = "inv"
    end
    if isstring(id) then
        for index, panel in ipairs(self.subpanels) do
            if panel.subpanelName == id then
                id = index
                break
            end
        end
    end
    if not self.subpanels[id] then
        return false
    end
    if not ui.CanShowMenuTab(self.subpanels[id].subpanelName) then
        return false
    end
    for index, panel in ipairs(self.subpanels) do
        panel:SetVisible(index == id)
    end
    self.activeSubpanel = id
    self.subpanels[id]:OnSetActive()
    return true
end

function PANEL:GetSubpanel(id)
    if id == "you" then
        id = "inv"
    end
    if isstring(id) then
        for _, panel in ipairs(self.subpanels) do
            if panel.subpanelName == id then
                return panel
            end
        end
    end
    return self.subpanels[id]
end

function PANEL:TransitionSubpanel(id)
    local panel = self:GetSubpanel(id)
    local previous = self:GetActiveSubpanel()
    if not IsValid(panel) or panel == previous then
        return
    end
    if not ui.CanShowMenuTab(panel.subpanelName) then
        return
    end
    if previous and istable(previous.info) and previous.info.OnDeselected then
        previous.info:OnDeselected(previous)
    end
    if not panel.bPopulated then
        if istable(panel.info) and panel.info.Create then
            panel.info:Create(panel)
        elseif isfunction(panel.info) then
            panel.info(panel)
        end
        panel.bPopulated = true
        styleSettings(panel.panel)
        hook.Run("MenuSubpanelCreated", panel.subpanelName, panel)
    end
    self:SetActiveSubpanel(id)
    ui.FadeIn(panel)
    self.pageTitle = panel.subpanelName == "inv" and "You" or L(panel.subpanelName:match("[^/]+$"))
    if istable(panel.info) and panel.info.OnSelected then
        panel.info:OnSelected(panel)
    end
    ix.gui.lastMenuTab = id
end

function PANEL:AddManuallyPaintedChild(panel)
    panel:SetParent(self)
    panel:SetPaintedManually(false)
end
function PANEL:SetCharacterOverview()
    self.bCharacterOverview, self.overviewFraction = false, 0
end
function PANEL:ShowBackground() end
function PANEL:HideBackground() end
function PANEL:Think()
    -- A permission change invalidates an open admin menu immediately. Reopening
    -- rebuilds providers under the new usergroup; server CAMI checks stay native.
    if self.fluxAdmin ~= LocalPlayer():IsAdmin() and not self.bClosing then
        self:Remove()
    end
end
function PANEL:PerformLayout()
    if not IsValid(self.buttons) then
        return
    end
    self:UpdateGeometry()
    self.buttons:SetPos(self.margin, self.contentY)
    self.buttons:SetSize(self.sidebar, self.contentHeight)
    for _, button in ipairs({ self.charactersButton, self.exitButton }) do
        if IsValid(button) then
            button:SetTall(44 * self.scale)
            button:DockMargin(0, 10 * self.scale, 0, 0)
        end
    end
    for _, button in ipairs(self.tabs.buttons) do
        button:SetTall(60 * self.scale)
        button:SetTextInset((button.name:find("/", 1, true) and 40 or 24) * self.scale, 0)
    end
    for _, panel in ipairs(self.subpanels) do
        local titleHeight = panel.subpanelName == "inv" and 0 or 62 * self.scale
        panel:SetPos(self.contentX, self.contentY + titleHeight)
        panel:SetSize(self.contentWidth, self.contentHeight - titleHeight)
    end
end
function PANEL:Remove()
    if self.bClosing then
        return
    end
    for _, page in ipairs(self.subpanels) do
        ui.ReleaseModel(page.preview)
    end
    if not ix.option.Get("fluxMotion", true) then
        self.bClosing = true
        if IsValid(self.projectedTexture) then
            self.projectedTexture:Remove()
        end
        return vgui.GetControlTable("ixSubpanelParent").Remove(self)
    end
    return nativeMenu.Remove(self)
end
function PANEL:OnKeyCodePressed(key)
    if key == KEY_ESCAPE then
        ui.HandleEscape()
    end
end
function PANEL:Paint(w, h)
    local scale, margin = self.scale, self.margin
    surface.SetDrawColor(shell.background)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(10, 12, 13, 125)
    surface.DrawRect(0, 0, w, 74 * scale)
    draw.SimpleText(
        "FLUX",
        "Flux.Shell.Brand",
        margin,
        40 * scale,
        shell.text,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
    surface.SetFont("Flux.Shell.Brand")
    local brandWidth = surface.GetTextSize("FLUX")
    draw.SimpleText(
        "v-" .. flux.version,
        "Flux.Shell.Small",
        margin + brandWidth + 16 * scale,
        40 * scale,
        shell.muted,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
    local count = player.GetCount() .. " / " .. game.MaxPlayers()
    surface.SetFont("Flux.Shell.Small")
    local countWidth = surface.GetTextSize(count)
    local divider = w - margin - countWidth - 28 * scale
    draw.SimpleText(
        count,
        "Flux.Shell.Small",
        w - margin,
        40 * scale,
        shell.text,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
    draw.SimpleText(
        GetHostName(),
        "Flux.Shell.Small",
        divider - 28 * scale,
        40 * scale,
        shell.text,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
    surface.SetDrawColor(shell.line)
    surface.DrawRect(divider, 29 * scale, 1, 22 * scale)
    surface.DrawRect(margin - 14 * scale, 74 * scale, w - margin * 2 + 28 * scale, 1)
    local page = self:GetActiveSubpanel()
    if IsValid(page) and page.subpanelName ~= "inv" then
        surface.SetDrawColor(10, 12, 13, 125)
        surface.DrawRect(
            self.contentX - 12 * scale,
            self.contentY - 8 * scale,
            self.contentWidth + 24 * scale,
            self.contentHeight + 16 * scale
        )
        draw.SimpleText(self.pageTitle or "", "Flux.Shell.Title", self.contentX, self.contentY, shell.text)
    end
end
vgui.Register("ixMenu", PANEL, "ixSubpanelParent")
