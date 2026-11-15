flux.util = flux.util or {}
flux.nativeBindings = flux.nativeBindings or {}

-- Re-including a bridge must not capture its own wrapper as the native API.
-- If an upstream reload replaces the implementation, capture that new one.
function flux.util.CaptureNative(owner, key, id)
    local binding = flux.nativeBindings[id] or {}
    if owner[key] ~= binding.wrapper then
        binding.original = owner[key]
    end
    assert(isfunction(binding.original), "Missing native API: " .. id)
    flux.nativeBindings[id] = binding
    return binding.original
end

function flux.util.TrackWrapper(owner, key, id)
    flux.nativeBindings[id].wrapper = owner[key]
end

function flux.util.IsFinite(value)
    return isnumber(value) and value == value and value ~= math.huge and value ~= -math.huge
end

function flux.util.Identifier(value)
    return isstring(value) and #value > 0 and #value <= 64 and value:match("^[a-z][a-z0-9_]*$") ~= nil
end

function flux.util.Log(message)
    MsgN("[Flux] " .. tostring(message))
end
