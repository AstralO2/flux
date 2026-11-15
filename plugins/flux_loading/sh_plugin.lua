PLUGIN.name = "Flux Loading Screen"
PLUGIN.author = "Flux contributors"
PLUGIN.description =
    "SCP loading slideshow and client asset preparation. Disable to open character selection directly."

local pluginID = PLUGIN.uniqueID
local stateKey = "Flux.Loading.Enabled"

ix.util.Include("sh_loading.lua")
ix.util.Include("sh_slides.lua")
ix.util.Include("sv_resources.lua")
ix.util.Include("cl_screen.lua")
ix.util.Include("cl_assets.lua")
ix.util.Include("cl_loading.lua")

function PLUGIN:OnLoaded()
    if SERVER then
        SetGlobalBool(stateKey, not ix.plugin.unloaded[pluginID])
    else
        flux.loading.SetEnabled(GetGlobalBool(stateKey, false))
    end
end

function PLUGIN:OnUnload()
    if SERVER then
        SetGlobalBool(stateKey, false)
    else
        flux.loading.SetEnabled(false)
    end
end

function PLUGIN:Think()
    if (self.nextStateCheck or 0) > RealTime() then
        return
    end
    self.nextStateCheck = RealTime() + 0.25
    if SERVER then
        local enabled = not ix.plugin.unloaded[pluginID]
        if GetGlobalBool(stateKey, false) ~= enabled then
            SetGlobalBool(stateKey, enabled)
        end
    else
        flux.loading.SetEnabled(GetGlobalBool(stateKey, false))
    end
end
