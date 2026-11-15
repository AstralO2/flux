Schema.name = "Flux"
Schema.author = "Flux contributors"
Schema.description = "Your next chapter starts here."
-- Class uniqueID (the filename after sh_). This is the server's default job.
Schema.defaultClass = "citizen"

ix.config.SetDefault("defaultMoney", 500)
ix.config.SetDefault("inventoryWidth", 6)
ix.config.SetDefault("inventoryHeight", 5)
ix.config.SetDefault("intro", false)
ix.config.SetDefault("color", flux.config.accent)

ix.util.Include("cl_schema.lua")
