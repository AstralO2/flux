local ui = flux.ui

function ui.OpenCharacters()
    if IsValid(ix.gui.characterMenu) then
        ix.gui.characterMenu:Remove()
    end
    return vgui.Create("ixCharMenu")
end

-- Remove the obsolete role browser command when this file auto-refreshes.
concommand.Remove("flux_roles")
if IsValid(ui.roles) then
    ui.roles:Remove()
end
ui.roles, ui.OpenRoles, ui.PopulateRoles = nil, nil, nil

function ui.OpenSettings()
    return ui.OpenHelixTab("settings")
end

-- The workspace is the only main menu. Keep this entry point for callers of
-- earlier Flux releases, without constructing a second pause screen.
function ui.OpenPause()
    if IsValid(ix.gui.menu) and not ix.gui.menu.bClosing then
        ix.gui.menu:Remove()
        return
    end
    return ui.OpenHelixTab("inv")
end

-- Retire the custom Tab frame on auto-refresh too. Native DarkRP/base
-- scoreboard handling remains available without opening the ESC workspace.
if IsValid(ui.scoreboard) then
    ui.scoreboard:Remove()
end
ui.scoreboard = nil
GM.ScoreboardShow = flux.runtime.darkrp.ScoreboardShow
GM.ScoreboardHide = flux.runtime.darkrp.ScoreboardHide

-- ESC owns the Flux workspace; F4 retains its native DarkRP handler.
function GM:ShowHelp() end
function GM:ShowTeam() end
function GM:ShowSpare1() end
hook.Remove("PlayerButtonDown", "Flux.MenuKeys")

-- Both the native pause hook and focused VGUI panels use this toggle.
function ui.HandleEscape()
    if flux.loading and flux.loading.Active then
        return
    end
    -- The same Escape can reach both VGUI and OnPauseMenuShow. Handle it once,
    -- including when reduced motion removes the panel immediately.
    local frame = FrameNumber()
    if ui.escapeFrame == frame then
        return
    end
    ui.escapeFrame = frame
    if IsValid(ui.exitConfirmation) then
        ui.exitConfirmation:Close()
        return
    end
    -- Close the foreground Flux dialog, then native F4, before toggling the
    -- workspace. Opening another menu here would leave the old one on top.
    for index = #ui.popups, 1, -1 do
        local popup = ui.popups[index]
        if IsValid(popup) and popup:IsVisible() then
            popup:Close()
            return
        end
    end
    local f4 = DarkRP.getF4MenuPanel and DarkRP.getF4MenuPanel()
    if IsValid(f4) and f4:IsVisible() then
        DarkRP.closeF4Menu()
        return
    end
    local storage = ix.gui.openedStorage
    if IsValid(storage) and IsValid(storage.storageInventory) then
        if not storage.fluxClosing then
            storage.fluxClosing = true
            storage.storageInventory:Close()
        end
        return
    end
    if IsValid(ix.gui.characterMenu) and not ix.gui.characterMenu:IsClosing() then
        if ui.GetCharacter() then
            ix.gui.characterMenu:Close()
        end
        return
    end
    if IsValid(ix.gui.menu) then
        if not ix.gui.menu.bClosing then
            ix.gui.menu:Remove()
        end
        return
    end
    ui.OpenPause()
end

-- Retire the old registration during Lua auto-refresh as well as fresh loads.
hook.Remove("OnGameUIVisible", "Flux.Pause")
hook.Add("OnPauseMenuShow", "Flux.Pause", function()
    ui.HandleEscape()
    -- Suppress the stock pause screen after handling this attempt. The engine
    -- retains its Shift+Escape bypass for access to the original game menu.
    return false
end)

concommand.Add("flux_menu", ui.OpenPause)
concommand.Add("flux_characters", ui.OpenCharacters)
concommand.Add("flux_inventory", function()
    ui.OpenHelixTab("inv", "Inventory")
end)
concommand.Add("flux_settings", ui.OpenSettings)

hook.Add("OnScreenSizeChanged", "Flux.Interface.Layout", function()
    for _, panel in pairs({ ix.gui.characterMenu, ix.gui.menu }) do
        if IsValid(panel) then
            panel:SetSize(ScrW(), ScrH())
            panel:InvalidateLayout(true)
        end
    end
    if IsValid(ui.pause) then
        ui.pause:Remove()
    end
    for _, panel in pairs({ ui.admin }) do
        if IsValid(panel) then
            panel:SetSize(math.min(panel:GetWide(), ScrW() - 32), math.min(panel:GetTall(), ScrH() - 32))
            panel:Center()
        end
    end
end)
