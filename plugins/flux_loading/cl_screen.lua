local loading, ui = flux.loading, flux.ui
local c, config = ui.colors, loading.config
local gradientDown = Material("vgui/gradient-d")
local gradientLeft = Material("vgui/gradient-l")
local PANEL = {}
local titles = {
    waiting = "Connecting to the server",
    assets = "Loading models",
    connectionError = "Still waiting for the server",
}

local function loadPhoto(path)
    local material = Material(path, "smooth")
    if material:IsError() then
        MsgC(c.danger, "[Flux loading] Background unavailable: " .. path .. "\n")
        return
    end
    return material, material:Width(), material:Height()
end

local function drawPhoto(slide, width, height, alpha)
    if not slide then
        return
    end
    local u0, v0, u1, v1 = loading.CoverUV(slide.width, slide.height, width, height)
    surface.SetMaterial(slide.material)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRectUV(0, 0, width, height, u0, v0, u1, v1)
end

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:SetZPos(32767)
    self:MakePopup()
    self:SetKeyboardInputEnabled(false)
    self.slideshow = loading.NewSlideshow(config.slideshow, loadPhoto)
    self.retry = ui.Button(self, "Retry connection", loading.Retry)
    self.disconnect = ui.Button(self, "Exit server", function()
        RunConsoleCommand("disconnect")
    end, true)
    for _, button in ipairs({ self.retry, self.disconnect }) do
        button:Dock(NODOCK)
        button:SetVisible(false)
    end
    self.detail = ui.Label(self, "", "Flux.Small", c.text)
    self.detail:Dock(NODOCK)
    self.detail:SetWrap(true)
    self.detail:SetContentAlignment(7)
end

function PANEL:Think()
    if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then
        self:SetSize(ScrW(), ScrH())
    end
    self.slideshow:Step(RealTime(), ix.option.Get("fluxMotion", true))
    local waiting = loading.phase == "connectionError"
    self.retry:SetVisible(waiting)
    self.disconnect:SetVisible(waiting)
    local queue = loading.queue
    local detail = "Waiting for your character data…"
    if queue then
        detail = (queue.finished.models + queue.finished.materials)
            .. " / "
            .. (#queue.models + #queue.materials)
            .. " assets prepared"
    end
    if waiting then
        detail = "Please retry or reconnect. Check the server console if this continues."
    end
    if self.detail:GetText() ~= detail then
        self.detail:SetText(detail)
    end
end

function PANEL:PerformLayout(w, h)
    self.margin = math.Clamp(w * 0.06, 28, 100)
    self.contentY = h - 190
    self.contentWidth = math.min(640, w - self.margin * 2)
    local y = h - 80
    self.retry:SetPos(self.margin, y)
    self.retry:SetSize(180, 42)
    self.disconnect:SetPos(w - self.margin - 140, y)
    self.disconnect:SetSize(140, 42)
    self.detail:SetPos(self.margin, self.contentY + 52)
    self.detail:SetSize(self.contentWidth, 42)
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(13, 17, 19)
    surface.DrawRect(0, 0, w, h)
    local slides = self.slideshow
    drawPhoto(slides.previous, w, h, 255)
    drawPhoto(slides.current, w, h, slides:Fraction(RealTime(), ix.option.Get("fluxMotion", true)) * 255)
    -- Simple texture shading, with no blur, post-processing or render targets.
    surface.SetDrawColor(8, 14, 17, 95)
    surface.DrawRect(0, 0, w, h)
    surface.SetMaterial(gradientLeft)
    surface.SetDrawColor(8, 12, 14, 205)
    surface.DrawTexturedRect(0, 0, w * 0.85, h)
    surface.SetMaterial(gradientDown)
    surface.SetDrawColor(8, 12, 14, 235)
    surface.DrawTexturedRect(0, h * 0.35, w, h * 0.65)
    local x, y, width = self.margin or 40, self.contentY or h - 190, self.contentWidth or 640
    local queue = loading.queue
    local title = titles[loading.phase] or "Opening character selection"
    if loading.phase == "assets" and queue and queue.at.models > #queue.models then
        title = "Loading materials"
    end
    draw.SimpleText(title, "Flux.Body", x, y, c.text)
    local target = loading.Ready and 1 or queue and queue:Progress() or 0.03
    self.progress = ui.Ease(self.progress or 0, target)
    surface.SetDrawColor(231, 230, 224, 55)
    surface.DrawRect(x, y + 36, width, 2)
    surface.SetDrawColor(c.accent)
    surface.DrawRect(x, y + 36, width * self.progress, 2)
    draw.SimpleText(math.floor(target * 100) .. "%", "Flux.Mono", x + width, y, c.text, TEXT_ALIGN_RIGHT)
end
vgui.Register("FluxLoading", PANEL, "EditablePanel")
