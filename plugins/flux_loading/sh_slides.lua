local loading = flux.loading
local SLIDES = {}
SLIDES.__index = SLIDES

-- Keep the original aspect ratio while filling the viewport.
function loading.CoverUV(imageWidth, imageHeight, width, height)
    local source, target = imageWidth / imageHeight, width / height
    if source > target then
        local span = target / source
        return (1 - span) / 2, 0, (1 + span) / 2, 1
    end
    local span = source / target
    return 0, (1 - span) / 2, 1, (1 + span) / 2
end

function loading.NewSlideshow(config, loader)
    return setmetatable({ config = config, loader = loader, failed = {} }, SLIDES)
end

function SLIDES:Candidate()
    for offset = 1, #self.config.slides do
        local index = ((self.current and self.current.index or 0) + offset - 1) % #self.config.slides + 1
        if not self.failed[index] and (not self.current or index ~= self.current.index) then
            return index
        end
    end
end

function SLIDES:Step(now, motion)
    if not self.config.enabled then
        return
    end
    if self.previous and (not motion or now - self.changed >= self.config.fade) then
        self.previous = nil
    end
    -- Decode at most one local photo per step, outside the Paint callback.
    -- Prepare the following photo shortly before the transition is due.
    if
        not self.next and (not self.current or now - self.started >= self.config.interval - self.config.fade)
    then
        local index = self:Candidate()
        if index then
            local definition = self.config.slides[index]
            local ok, material, width, height = pcall(self.loader, definition.image)
            if ok and material and isnumber(width) and isnumber(height) and width > 0 and height > 0 then
                self.next = {
                    index = index,
                    definition = definition,
                    material = material,
                    width = width,
                    height = height,
                }
            else
                self.failed[index] = true
            end
        end
    end
    if self.next and (not self.current or now - self.started >= self.config.interval) then
        self.previous = motion and self.config.fade > 0 and self.current or nil
        self.current, self.next, self.started, self.changed = self.next, nil, now, now
    end
end

function SLIDES:Fraction(now, motion)
    if not self.previous or not motion or self.config.fade <= 0 then
        return 1
    end
    local value = math.Clamp((now - self.changed) / self.config.fade, 0, 1)
    return value * value * (3 - 2 * value)
end
