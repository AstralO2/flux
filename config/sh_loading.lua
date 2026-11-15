-- Runs after GMod downloads/mounts server content, before character selection.
return {
    enabled = true,
    frameBudgetMS = 3,
    modelsPerFrame = 1,
    materialsPerFrame = 6,
    maxModels = 1024,
    maxMaterials = 4096,
    timeout = 120,
    connectionTimeout = 90,
    includeSceneModels = true,
    slideshow = {
        enabled = true,
        interval = 10,
        fade = 1.5,
        slides = {
            {
                image = "flux/loading/scp_970.jpg",
                caption = "SCP-970",
                credit = "SCP - Containment Breach contributors",
                source = "https://github.com/Regalis11/scpcb/blob/edb8fe0840b78f14d1aef3a0bf6174630e7be296/Loadingscreens/970.jpg",
                license = "https://creativecommons.org/licenses/by-sa/3.0/",
            },
            {
                image = "flux/loading/scp_914.jpg",
                caption = "SCP-914",
                credit = "SCP - Containment Breach contributors",
                source = "https://github.com/Regalis11/scpcb/blob/edb8fe0840b78f14d1aef3a0bf6174630e7be296/Loadingscreens/914.jpg",
                license = "https://creativecommons.org/licenses/by-sa/3.0/",
            },
            {
                image = "flux/loading/scp_079.jpg",
                caption = "SCP-079",
                credit = "SCP - Containment Breach contributors",
                source = "https://github.com/Regalis11/scpcb/blob/edb8fe0840b78f14d1aef3a0bf6174630e7be296/Loadingscreens/079.jpg",
                license = "https://creativecommons.org/licenses/by-sa/3.0/",
            },
            {
                image = "flux/loading/scp_939.jpg",
                caption = "SCP-939",
                credit = "SCP - Containment Breach contributors",
                source = "https://github.com/Regalis11/scpcb/blob/edb8fe0840b78f14d1aef3a0bf6174630e7be296/Loadingscreens/939.jpg",
                license = "https://creativecommons.org/licenses/by-sa/3.0/",
            },
        },
    },
    additionalModels = {},
    additionalMaterials = {}, -- Relative to materials/, including PNG/JPG icons.
}
