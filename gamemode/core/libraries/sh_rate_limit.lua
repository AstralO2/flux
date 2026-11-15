flux.rateLimit = {}
local buckets = setmetatable({}, { __mode = "k" })

-- Account for rejected requests too. Weak keys release disconnected players.
function flux.rateLimit.Allow(owner, key, interval)
    local now = CurTime()
    local state = buckets[owner]
    if not state then
        state = {}
        buckets[owner] = state
    end
    if now < (state[key] or 0) then
        return false
    end
    state[key] = now + interval
    return true
end
