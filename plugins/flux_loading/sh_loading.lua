flux.loading = flux.loading or {}
local loading = flux.loading
loading.config = ix.util.Include("flux/config/sh_loading.lua", "shared")
local config = loading.config
assert(istable(config) and isbool(config.enabled) and isbool(config.includeSceneModels))
for key, range in pairs({
    frameBudgetMS = { 1, 10 },
    modelsPerFrame = { 1, 4 },
    materialsPerFrame = { 1, 16 },
    maxModels = { 1, 2048 },
    maxMaterials = { 1, 8192 },
    timeout = { 10, 300 },
    connectionTimeout = { 10, 300 },
}) do
    local value = config[key]
    assert(
        flux.util.IsFinite(value) and value >= range[1] and value <= range[2] and value % 1 == 0,
        "Invalid Flux loading setting: " .. key
    )
end
assert(istable(config.additionalModels) and istable(config.additionalMaterials))
local slideshow = config.slideshow
assert(istable(slideshow) and isbool(slideshow.enabled), "Invalid loading slideshow")
assert(flux.util.IsFinite(slideshow.interval) and slideshow.interval >= 3 and slideshow.interval <= 60)
assert(flux.util.IsFinite(slideshow.fade) and slideshow.fade >= 0 and slideshow.fade <= 2)
assert(istable(slideshow.slides) and #slideshow.slides <= 8)
for _, slide in ipairs(slideshow.slides) do
    assert(istable(slide) and isstring(slide.image) and slide.image:match("^flux/loading/[%w_%-]+%.jpg$"))
    for _, key in ipairs({ "caption", "credit" }) do
        assert(isstring(slide[key]) and #slide[key] <= 160 and not slide[key]:find("[%c]"))
    end
    for _, key in ipairs({ "source", "license" }) do
        assert(isstring(slide[key]) and #slide[key] <= 512 and slide[key]:match("^https://[^%s%c]+$"))
    end
end
loading.Ready = loading.Ready or not config.enabled

local QUEUE = {}
QUEUE.__index = QUEUE

local function normalize(path, kind)
    if not isstring(path) or #path == 0 or #path > 240 or path:find("[%c]") then
        return
    end
    path = path:gsub("\\", "/"):lower()
    if path:find("..", 1, true) or path:find(":", 1, true) or path:sub(1, 1) == "/" then
        return
    end
    if kind == "models" then
        return path:match("^models/.+%.mdl$") and path or nil
    end
    path = path:gsub("^materials/", ""):gsub("%.vmt$", "")
    return #path > 0 and path or nil
end

function loading.NewQueue()
    return setmetatable({
        models = {},
        materials = {},
        seen = { models = {}, materials = {} },
        at = { models = 1, materials = 1 },
        finished = { models = 0, materials = 0 },
        failures = {},
        overflow = {},
        materialSources = {},
    }, QUEUE)
end

function QUEUE:Add(kind, path)
    path = normalize(path, kind)
    if not path or self.seen[kind][path] then
        return false
    end
    local limit = kind == "models" and config.maxModels or config.maxMaterials
    if #self[kind] >= limit then
        if not self.overflow[kind] then
            self.failures[#self.failures + 1] = "Preparation limit reached: " .. kind
            self.overflow[kind] = true
        end
        return false
    end
    self.seen[kind][path] = true
    self[kind][#self[kind] + 1] = path
    return true
end

function QUEUE:AddModel(path)
    return self:Add("models", path)
end
function QUEUE:AddMaterial(path, source)
    local key = normalize(path, "materials")
    if key and source and not self.materialSources[key] then
        self.materialSources[key] = source
    end
    return self:Add("materials", path)
end

-- Definition models may be strings, lists, or Helix {path, skin, groups} tuples.
function QUEUE:AddModels(models, depth)
    if isstring(models) then
        self:AddModel(models)
    elseif istable(models) and (depth or 0) < 3 then
        for _, value in pairs(models) do
            self:AddModels(value, (depth or 0) + 1)
        end
    end
end

function QUEUE:IsDone()
    return self.at.models > #self.models and self.at.materials > #self.materials
end

function QUEUE:Progress()
    if self.at.models <= #self.models then
        return 0.1 + 0.45 * self.finished.models / math.max(#self.models, 1)
    end
    return 0.55 + 0.45 * self.finished.materials / math.max(#self.materials, 1)
end

function QUEUE:Step(handlers)
    local deadline = SysTime() + config.frameBudgetMS / 1000
    for _, kind in ipairs({ "models", "materials" }) do
        local count = kind == "models" and config.modelsPerFrame or config.materialsPerFrame
        for _ = 1, count do
            local path = self[kind][self.at[kind]]
            if not path or SysTime() >= deadline then
                break
            end
            self.detail = path
            local ok, result, reason = pcall(handlers[kind], path, self)
            if not ok or not result then
                local message = kind .. ": " .. path .. " (" .. tostring(ok and reason or result) .. ")"
                if kind == "materials" and self.materialSources[path] then
                    message = message .. " from " .. self.materialSources[path]
                end
                self.failures[#self.failures + 1] = message
            end
            self.at[kind] = self.at[kind] + 1
            self.finished[kind] = self.finished[kind] + 1
        end
        -- Discover model materials before processing their queue.
        if self.at.models <= #self.models then
            break
        end
    end
end
