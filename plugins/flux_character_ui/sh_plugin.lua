PLUGIN.name = "Flux Character UI"
PLUGIN.author = "Flux contributors"
PLUGIN.description =
    "The Flux character roster and creation workspace. Disable to use native Helix character menus."

local pluginID = PLUGIN.uniqueID
local stateKey = "Flux.CharacterUI.Enabled"

ix.util.Include("sh_roster.lua")
ix.util.Include("cl_characters.lua")
ix.util.Include("cl_plugin.lua")

function PLUGIN:OnLoaded()
    if SERVER then
        SetGlobalBool(stateKey, not ix.plugin.unloaded[pluginID])
    else
        flux.characterUI.Apply(GetGlobalBool(stateKey, false))
    end
end

function PLUGIN:OnUnload()
    if SERVER then
        SetGlobalBool(stateKey, false)
    else
        flux.characterUI.Apply(false)
    end
end

function PLUGIN:Think()
    if (self.nextStateCheck or 0) > RealTime() then
        return
    end
    self.nextStateCheck = RealTime() + 0.25
    if SERVER then
        -- Native plugin toggles persist in ix.plugin.unloaded. A plugin that
        -- was present at map start can also switch the current clients live.
        local enabled = not ix.plugin.unloaded[pluginID]
        if GetGlobalBool(stateKey, false) ~= enabled then
            SetGlobalBool(stateKey, enabled)
        end
    else
        flux.characterUI.Apply(GetGlobalBool(stateKey, false))
    end
end
