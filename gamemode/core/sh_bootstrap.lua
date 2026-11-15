-- Explicit dependency order: no runtime scans or per-package patch tables.
local files = {
    "libraries/sh_util.lua",
    "libraries/sh_rate_limit.lua",
    "systems/sh_features.lua",
    "compatibility/sh_runtime.lua",
    "compatibility/sh_voice.lua",
    "systems/sh_groups.lua",
    "systems/sh_admin.lua",
    "compatibility/sh_roles.lua",
    "compatibility/sh_character.lua",
    "compatibility/sh_lifecycle.lua",
    "compatibility/cl_notifications.lua",
    "compatibility/sh_speech.lua",
    "compatibility/cl_speech_pose.lua",
    "compatibility/sv_lifecycle.lua",
    "compatibility/sv_roles.lua",
    "interface/cl_theme.lua",
    "interface/cl_profile.lua",
    "interface/cl_workspace.lua",
    "interface/cl_menu.lua",
    "interface/cl_admin.lua",
    "systems/sv_admin.lua",
}

ix.util.Include("flux/config/sh_config.lua", "shared")
for _, path in ipairs(files) do
    ix.util.Include(flux.path .. path)
end

-- Remember the composite callbacks so a partial compatibility-file refresh
-- cannot mistake our own lifecycle wrapper for a native Helix implementation.
for key, value in pairs(GM) do
    if isfunction(value) then
        flux.runtime.composed[key] = value
    end
end
