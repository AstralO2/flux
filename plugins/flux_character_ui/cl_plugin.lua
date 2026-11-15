flux.characterUI = flux.characterUI or {}
local state = flux.characterUI

if not state.nativeMenu then
    state.nativeMenu = {}
    for key, value in pairs(vgui.GetControlTable("ixCharMenu")) do
        state.nativeMenu[key] = value
    end
    vgui.Register("FluxNativeCharacterMenu", state.nativeMenu, "EditablePanel")
end

function state.Apply(enabled)
    local base = enabled and "FluxCharacterMenu" or "FluxNativeCharacterMenu"
    local registered = vgui.GetControlTable("ixCharMenu")
    if state.enabled == enabled and registered and registered.Base == base then
        return true
    end
    local menu = ix.gui.characterMenu
    if IsValid(menu) then
        local form = menu.newCharacterPanel
        -- Never throw away a submitted creation/deletion/selection request.
        if menu.requesting or IsValid(form) and form.awaitingResponse then
            return false
        end
    end
    local reopen = IsValid(menu) and (menu:IsVisible() or menu.fluxLoadingPending)
    if IsValid(menu) then
        menu:Remove()
    end
    vgui.Register("ixCharMenu", {}, base)
    state.enabled = enabled
    if reopen then
        vgui.Create("ixCharMenu")
    end
    return true
end
