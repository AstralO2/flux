-- Register privileges in both realms. CAMI's client access query needs the same
-- definitions as the authoritative server; the UI check never grants access.
flux.admin = { actions = { "heal", "respawn", "freeze", "unfreeze", "bring", "goto", "kick" } }
CAMI.RegisterPrivilege({
    Name = "Flux - Administration",
    MinAccess = "admin",
    Description = "Open Flux staff tools",
})
for _, name in ipairs(flux.admin.actions) do
    CAMI.RegisterPrivilege({
        Name = "Flux - " .. name,
        MinAccess = "admin",
        Description = "Flux staff action: " .. name,
    })
end
