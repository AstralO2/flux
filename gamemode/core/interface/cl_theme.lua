flux.ui = {
    popups = {},
    colors = {
        background = Color(21, 23, 24, 254),
        panel = Color(30, 33, 34),
        hover = Color(43, 46, 46),
        line = Color(58, 61, 60),
        text = Color(231, 230, 224),
        muted = Color(144, 150, 147),
        accent = flux.config.accent,
        danger = Color(199, 123, 114),
    },
}
local ui = flux.ui

function ui.WorkspaceScale()
    return math.Clamp(math.min(ScrW() / 1672, ScrH() / 941), 0.65, 1.6)
end
ui.workspaceColors = {
    background = Color(16, 18, 19, 180),
    text = Color(240, 240, 237),
    muted = Color(178, 180, 177),
    accent = Color(202, 190, 151),
    line = Color(81, 81, 73, 120),
    danger = Color(242, 108, 94),
}

local function createFonts()
    surface.CreateFont("Flux.Profile", { font = "Roboto", size = 30, weight = 500 })
    surface.CreateFont(
        "Flux.Title",
        { font = "Roboto", size = math.Clamp(ScrH() / 27, 30, 42), weight = 500 }
    )
    surface.CreateFont("Flux.Heading", { font = "Roboto", size = 23, weight = 500 })
    surface.CreateFont("Flux.Body", { font = "Roboto", size = 18, weight = 400 })
    surface.CreateFont("Flux.Small", { font = "Roboto", size = 15, weight = 400 })
    surface.CreateFont(
        "Flux.Display",
        { font = "Roboto", size = math.Clamp(ScrH() * 0.065, 40, 64), weight = 300 }
    )
    surface.CreateFont("Flux.Mono", { font = "Consolas", size = 14, weight = 400 })
    local scale = ui.WorkspaceScale()
    for name, definition in pairs({
        Brand = { 28, 600 },
        Title = { 42, 500 },
        Heading = { 27, 600 },
        Body = { 22, 400 },
        Small = { 19, 400 },
    }) do
        surface.CreateFont("Flux.Shell." .. name, {
            font = "Roboto",
            size = math.max(13, math.floor(definition[1] * scale + 0.5)),
            weight = definition[2],
            extended = true,
        })
    end
end
createFonts()
hook.Add("OnScreenSizeChanged", "Flux.Fonts", createFonts)

function ui.Label(parent, text, font, color, height)
    local label = parent:Add("DLabel")
    label:SetText(text)
    label:SetFont(font or "Flux.Body")
    label:SetTextColor(color or ui.colors.text)
    label:SetTall(height or 28)
    label:Dock(TOP)
    return label
end

function ui.Button(parent, text, callback, danger)
    local button = parent:Add("DButton")
    button:SetText(text)
    button:SetFont("Flux.Body")
    button:SetTextColor(danger and ui.colors.danger or ui.colors.text)
    button:SetTall(46)
    button.UpdateColours = function(panel)
        panel:SetTextStyleColor(
            not panel:IsEnabled() and ui.colors.muted
                or panel.fluxPrimary and ui.colors.background
                or danger and ui.colors.danger
                or ui.colors.text
        )
    end
    button:Dock(TOP)
    button:DockMargin(0, 0, 0, 8)
    button.Paint = function(panel, width, height)
        panel.fluxHover = ui.Ease(panel.fluxHover or 0, panel:IsHovered() and panel:IsEnabled() and 1 or 0)
        local primary = panel.fluxPrimary
        draw.RoundedBox(3, 0, 0, width, height, primary and ui.colors.accent or ui.colors.panel)
        surface.SetDrawColor(255, 255, 255, panel.fluxHover * 7)
        surface.DrawRect(0, 0, width, height)
        panel:SetTextColor(
            not panel:IsEnabled() and ui.colors.muted
                or primary and ui.colors.background
                or danger and ui.colors.danger
                or ui.colors.text
        )
        surface.SetDrawColor(ui.colors.line)
        if not primary then
            surface.DrawOutlinedRect(0, 0, width, height, 1)
        end
    end
    button.DoClick = callback
    return button
end

function ui.Frame(title, width, height)
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(width or 860, ScrW() - 32), math.min(height or 620, ScrH() - 32))
    frame:Center()
    frame:SetTitle("")
    frame:SetSizable(false)
    frame:SetDeleteOnClose(true)
    ui.popups[#ui.popups + 1] = frame
    local onRemove = frame.OnRemove
    frame.OnRemove = function(panel)
        table.RemoveByValue(ui.popups, panel)
        if onRemove then
            onRemove(panel)
        end
    end
    local onKeyCodePressed = frame.OnKeyCodePressed
    frame.OnKeyCodePressed = function(panel, key)
        if key == KEY_ESCAPE then
            ui.HandleEscape()
        elseif onKeyCodePressed then
            return onKeyCodePressed(panel, key)
        end
    end
    frame:DockPadding(28, 78, 28, 28)
    frame.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, ui.colors.background)
        draw.SimpleText(title, "Flux.Heading", 28, 25, ui.colors.text)
        surface.SetDrawColor(ui.colors.line)
        surface.DrawRect(28, 61, w - 56, 1)
    end
    frame.btnMaxim:SetVisible(false)
    frame.btnMinim:SetVisible(false)
    frame.btnClose:SetText("")
    frame.btnClose.Paint = function(panel, w, h)
        local color = panel:IsHovered() and ui.colors.text or ui.colors.muted
        surface.SetDrawColor(color)
        surface.DrawLine(w / 2 - 4, h / 2 - 4, w / 2 + 4, h / 2 + 4)
        surface.DrawLine(w / 2 + 4, h / 2 - 4, w / 2 - 4, h / 2 + 4)
    end
    frame:MakePopup()
    ui.FadeIn(frame)
    return frame
end

function ui.List(parent, columns)
    local list = parent:Add("DListView")
    list:SetMultiSelect(false)
    list:SetHeaderHeight(32)
    list:SetDataHeight(30)
    list.Paint = function(_, width, height)
        draw.RoundedBox(5, 0, 0, width, height, ui.colors.panel)
    end
    for _, title in ipairs(columns) do
        local column = list:AddColumn(title)
        column.Header:SetFont("Flux.Small")
        column.Header:SetTextColor(ui.colors.muted)
        column.Header.Paint = function(_, width, height)
            surface.SetDrawColor(ui.colors.hover)
            surface.DrawRect(0, 0, width, height)
        end
    end
    return list
end

function ui.ListLine(list, ...)
    local row = list:AddLine(...)
    for _, label in ipairs(row.Columns) do
        label:SetFont("Flux.Small")
        label:SetTextColor(ui.colors.text)
    end
    row.Paint = function(panel, width, height)
        if panel:IsSelected() or panel:IsHovered() then
            surface.SetDrawColor(ui.colors.hover)
            surface.DrawRect(0, 0, width, height)
        end
        if panel:IsSelected() then
            surface.SetDrawColor(ui.colors.accent)
            surface.DrawRect(0, 5, 2, height - 10)
        end
    end
    return row
end

-- Character-menu messages can arrive before the local player entity exists.
function ui.GetCharacter()
    local client = LocalPlayer()
    if IsValid(client) and isfunction(client.GetCharacter) then
        return client:GetCharacter()
    end
end

function ui.OpenHelixTab(name, section)
    if name == "you" then
        name = "inv"
    end
    if not ui.GetCharacter() then
        vgui.Create("ixCharMenu")
        return
    end
    if IsValid(ix.gui.menu) then
        ix.gui.menu:Remove()
    end
    local menu = vgui.Create("ixMenu")
    for _, button in ipairs(menu.tabs.buttons) do
        if button.name == name then
            for _, other in ipairs(menu.tabs.buttons) do
                if other ~= button then
                    other:SetSelected(false)
                end
            end
            button:SetSelected(true)
            break
        end
    end
    if name == "inv" and section then
        local page = menu:GetSubpanel("inv")
        if IsValid(page) and page.SetProfileSection then
            page:SetProfileSection(section)
        end
    end
    return menu
end

ix.lang.AddTable("english", {
    flux = "Flux",
    classes = "Roles",
})
ix.option.Add("fluxMotion", ix.type.bool, true, { category = "flux" })
ix.lang.AddTable(
    "english",
    { optFluxMotion = "Interface transitions", optdFluxMotion = "Use brief fades and smooth HUD bars." }
)

function ui.Ease(value, target)
    if not ix.option.Get("fluxMotion", true) then
        return target
    end
    return Lerp(1 - math.exp(-RealFrameTime() * 18), value, target)
end

function ui.FadeIn(panel)
    if ix.option.Get("fluxMotion", true) then
        panel:SetAlpha(0)
        panel:AlphaTo(255, 0.16)
    end
end

function ui.IsTextEntry(panel)
    -- DrawTextEntryText belongs to the engine Panel API, so its presence alone
    -- also matches scroll panels, sliders and other non-text controls.
    return isfunction(panel.SetFont)
        and isfunction(panel.GetValue)
        and isfunction(panel.SetCursorColor)
        and isfunction(panel.SetHighlightColor)
        and isfunction(panel.GetPlaceholderText)
end

function ui.TextEntry(panel, font)
    -- ixTextEntry sizes itself in SetFont; preserve provider/default heights,
    -- especially the native multiline description field.
    local height = panel:GetTall()
    panel:SetFont(font or "Flux.Body")
    panel:SetTall(height)
    panel:SetTextColor(ui.colors.text)
    panel:SetCursorColor(ui.colors.accent)
    panel:SetHighlightColor(ui.colors.hover)
    panel.Paint = function(entry, width, height)
        draw.RoundedBox(3, 0, 0, width, height, ui.colors.panel)
        surface.SetDrawColor(entry:HasFocus() and ui.colors.accent or ui.colors.line)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
        entry:DrawTextEntryText(ui.colors.text, ui.colors.accent, ui.colors.text)
        if entry:GetValue() == "" and not entry:HasFocus() then
            draw.SimpleText(entry:GetPlaceholderText() or "", "Flux.Small", 9, 12, ui.colors.muted)
        end
    end
    return panel
end

function ui.Scroll(panel)
    local bar = panel:GetVBar()
    bar:SetWide(5)
    bar:SetHideButtons(true)
    bar.Paint = function() end
    bar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, ui.colors.line)
    end
    return panel
end

function ui.Rule(parent, top, bottom)
    local rule = parent:Add("Panel")
    rule:Dock(TOP)
    rule:SetTall(1)
    rule:DockMargin(0, top or 12, 0, bottom or 12)
    rule.Paint = function(_, w, h)
        surface.SetDrawColor(ui.colors.line)
        surface.DrawRect(0, 0, w, h)
    end
    return rule
end

function ui.ReleaseModel(panel)
    if not IsValid(panel) then
        return
    end
    -- DModelPanel's 3D draw does not follow parent alpha reliably. Stop it
    -- immediately, rather than leaving it visible during a menu fade.
    panel:SetVisible(false)
    if IsValid(panel.Entity) then
        panel.Entity:Remove()
    end
    panel.Entity = nil
end

function ui.Model(parent)
    local model = parent:Add("DModelPanel")
    model:SetFOV(32)
    model:SetCamPos(Vector(115, 0, 40))
    model:SetLookAt(Vector(0, 0, 37))
    model:SetAmbientLight(Color(130, 135, 130))
    model:SetDirectionalLight(BOX_FRONT, Color(210, 205, 190))
    model:SetDirectionalLight(BOX_BACK, Color(65, 73, 77))
    model.LayoutEntity = function(panel, entity)
        entity:SetAngles(Angle(0, 24, 0))
        if ix.option.Get("fluxMotion", true) then
            panel:RunAnimation()
        end
    end
    return model
end

function ui.Confirm(title, message, action, callback)
    local frame = ui.Frame(title, 460, 320)
    local label = ui.Label(frame, message, "Flux.Body", ui.colors.muted, 74)
    label:SetWrap(true)
    local confirm = ui.Button(frame, action, function()
        frame:Close()
        callback()
    end, true)
    confirm:Dock(BOTTOM)
    local cancel = ui.Button(frame, "Cancel", function()
        frame:Close()
    end)
    cancel:Dock(BOTTOM)
    return frame
end
