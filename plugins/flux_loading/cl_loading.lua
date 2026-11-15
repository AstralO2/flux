local loading, ui = flux.loading, flux.ui
local config = loading.config
local hookID = "Flux.SessionPreparation"

local function revealMenu()
    local menu = ix.gui.characterMenu
    if not IsValid(menu) or not menu.fluxLoadingPending then
        return
    end
    menu.fluxLoadingPending = nil
    if isfunction(menu.Build) and not menu.fluxCustom then
        menu:Build()
    else
        menu:SetVisible(true)
        menu:MakePopup()
    end
end

function loading.Finish()
    if
        not loading.Active
        or not loading.queue
        or (
            loading.phase ~= "issues"
            and not (loading.phase == "assets" and (loading.queue:IsDone() or loading.queue.timedOut))
        )
    then
        return false
    end
    loading.Active, loading.Ready, loading.phase = false, true, "ready"
    loading.prepared = true
    hook.Remove("Think", hookID)
    for _, message in ipairs(loading.queue.failures) do
        MsgC(Color(199, 123, 114), "[Flux loading] " .. message .. "\n")
    end
    local frame = loading.frame
    loading.frame = nil
    revealMenu()
    if IsValid(frame) then
        frame:SetMouseInputEnabled(false)
        frame:AlphaTo(0, ix.option.Get("fluxMotion", true) and 0.25 or 0, 0, function()
            if IsValid(frame) then
                frame:Remove()
            end
        end)
    end
    hook.Run("FluxClientPrepared", loading.queue)
    return true
end

function loading.Prepare()
    local ok, queue = xpcall(loading.Gather, debug.traceback)
    if not ok then
        local message = queue
        queue = loading.NewQueue()
        queue.failures[1] = "Could not collect content: " .. tostring(message)
    end
    loading.queue = queue
    loading.phase, loading.assetStarted = "assets", RealTime()
end

function loading.Retry()
    if not loading.Active then
        return
    end
    if loading.phase == "connectionError" then
        loading.phase, loading.started = "waiting", RealTime()
    end
end

function loading.Step()
    if not loading.Active then
        return
    end
    if not IsValid(loading.frame) then
        loading.frame = vgui.Create("FluxLoading")
    end
    -- Let sessions paused by the previous version continue on refresh too.
    if loading.phase == "issues" then
        loading.Finish()
        return
    end
    if loading.phase == "waiting" or loading.phase == "connectionError" then
        if loading.worldReady and flux.roles.ready and IsValid(LocalPlayer()) and loading.menuReceived then
            if IsValid(ix.gui.loading) then
                ix.gui.loading:Remove()
            end
            loading.Prepare()
        elseif RealTime() - loading.started >= config.connectionTimeout then
            loading.phase = "connectionError"
        end
        return
    end
    if loading.phase ~= "assets" then
        return
    end
    local queue = loading.queue
    queue:Step(loading.handlers)
    if not queue:IsDone() and RealTime() - loading.assetStarted >= config.timeout then
        queue.failures[#queue.failures + 1] = "Preparation timed out; some assets were not loaded."
        queue.timedOut = true
    end
    if queue:IsDone() or queue.timedOut then
        loading.Finish()
    end
end

function loading.Begin()
    if loading.enabled == false or not config.enabled or loading.Ready or loading.Active then
        return
    end
    loading.Active, loading.phase, loading.started = true, "waiting", RealTime()
    loading.queue = nil
    loading.frame = vgui.Create("FluxLoading")
    hook.Add("Think", hookID, loading.Step)
end

function loading.DeferMenu(menu)
    if loading.enabled == false or loading.Ready then
        return false
    end
    local previous = ix.gui.characterMenu
    if IsValid(previous) and previous ~= menu then
        previous:Remove()
    end
    ix.gui.characterMenu = menu
    menu.fluxLoadingPending = true
    menu:SetVisible(false)
    loading.menuReceived = true
    loading.Begin()
    return true
end

function loading.SetEnabled(enabled)
    enabled = enabled and config.enabled or false
    if loading.enabled == enabled then
        return
    end
    loading.enabled = enabled
    if not enabled then
        loading.Active, loading.Ready, loading.phase = false, true, "disabled"
        hook.Remove("Think", hookID)
        if IsValid(loading.frame) then
            loading.frame:Remove()
        end
        loading.frame = nil
        revealMenu()
        return
    end
    -- Re-enabling affects the next join; never interrupt someone playing.
    if loading.prepared or ui.GetCharacter() then
        loading.Ready, loading.phase = true, "ready"
        return
    end
    loading.Ready = false
    if IsValid(ix.gui.characterMenu) then
        loading.DeferMenu(ix.gui.characterMenu)
    end
    loading.Begin()
end

hook.Add("FluxReady", hookID, loading.Begin)
-- Native Helix and optional menu plugins share the same preparation boundary.
hook.Add("OnCharacterMenuCreated", hookID, function(menu)
    if not loading.Ready and not menu.fluxLoadingPending then
        loading.DeferMenu(menu)
    end
end)
hook.Add("InitPostEntity", hookID, function()
    loading.worldReady = true
    loading.Begin()
end)

if loading.Active then
    hook.Add("Think", hookID, loading.Step)
end
