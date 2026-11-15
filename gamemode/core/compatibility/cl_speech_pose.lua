local names = {
    "ValveBiped.Bip01_R_UpperArm",
    "ValveBiped.Bip01_R_Forearm",
    "ValveBiped.Bip01_R_Hand",
    "ValveBiped.Bip01_Head1",
}

local function eligible(client)
    return client:Alive()
        and client:GetCharacter() ~= nil
        and not client:IsPlayingTaunt()
        and not client:GetNetVar("forcedSequence")
end

local function modelState(client, state)
    if state.fluxSpeechPoseModel ~= client:GetModel() then
        state.fluxSpeechPoseModel = client:GetModel()
        state.fluxSpeechBones = nil
        state.fluxSpeechBonesChecked = nil
        if state.fluxSpeechNativeActive then
            client:AnimResetGestureSlot(GESTURE_SLOT_VCD)
            state.fluxSpeechNativeActive = nil
        end
        state.fluxSpeechNative = client:SelectWeightedSequence(ACT_GMOD_IN_CHAT) >= 0
    end
end

local function blend(client, state)
    if not eligible(client) then
        state.fluxSpeechBlend = 0
        return 0
    end
    -- A player may build bones several times in one frame (shadows, mirrors).
    -- Advance once, so the transition takes 0.25 seconds at any frame rate.
    if state.fluxSpeechBlendFrame ~= FrameNumber() then
        state.fluxSpeechBlendFrame = FrameNumber()
        state.fluxSpeechBlend = math.Approach(
            state.fluxSpeechBlend or 0,
            client:GetNW2Bool(flux.speech.key, false) and 1 or 0,
            FrameTime() * 4
        )
    end
    local value = state.fluxSpeechBlend or 0
    return value * value * (3 - 2 * value)
end

function GM:GrabEarAnimation(client, state)
    state = state or client:GetTable()
    modelState(client, state)
    local weight = blend(client, state)
    if not state.fluxSpeechNative or not eligible(client) then
        return
    end
    if weight > 0 then
        -- This is GMod's native ear-grab path, with the shared activity flag
        -- and eased blend in place of its typing-only condition.
        client:AnimRestartGesture(GESTURE_SLOT_VCD, ACT_GMOD_IN_CHAT, true)
        client:AnimSetGestureWeight(GESTURE_SLOT_VCD, weight)
        state.fluxSpeechNativeActive = true
    elseif state.fluxSpeechNativeActive then
        client:AnimSetGestureWeight(GESTURE_SLOT_VCD, 0)
        state.fluxSpeechNativeActive = nil
    end
end

local function cacheBones(client, state)
    local bones = {}
    for index, name in ipairs(names) do
        bones[index] = client:LookupBone(name)
        if not bones[index] then
            return
        end
    end
    bones.children = {}
    local function collect(index, branch)
        if client:GetBoneName(index) == "__INVALIDBONE__" then
            return
        end
        branch = index == bones[3] and 3 or index == bones[2] and 2 or branch
        bones.children[#bones.children + 1] = { index, branch }
        for _, child in ipairs(client:GetChildBones(index) or {}) do
            collect(child, branch)
        end
    end
    collect(bones[1], 1)
    state.fluxSpeechBones = bones
end

local function rotateToward(matrix, original, target, position)
    local from, toward = original:GetNormalized(), target:GetNormalized()
    local axis = from:Cross(toward)
    local dot = math.Clamp(from:Dot(toward), -1, 1)
    if axis:LengthSqr() < 0.000001 then
        axis = from:Cross(matrix:GetUp())
    end
    axis:Normalize()
    local angles = matrix:GetAngles()
    angles:RotateAroundAxis(axis, math.deg(math.acos(dot)))
    local result = Matrix()
    result:Set(matrix)
    result:SetAngles(angles)
    result:SetScale(matrix:GetScale())
    result:SetTranslation(position)
    return result
end

local function pose(client)
    local state = client:GetTable()
    local amount = blend(client, state)
    if amount == 0 then
        return
    end
    modelState(client, state)
    if state.fluxSpeechNative then
        return
    end
    if not state.fluxSpeechBones and not state.fluxSpeechBonesChecked then
        state.fluxSpeechBonesChecked = true
        cacheBones(client, state)
    end
    local bones = state.fluxSpeechBones
    if not bones then
        return
    end
    local upper, lower = client:GetBoneMatrix(bones[1]), client:GetBoneMatrix(bones[2])
    local hand, head = client:GetBoneMatrix(bones[3]), client:GetBoneMatrix(bones[4])
    if not upper or not lower or not hand or not head then
        return
    end
    local shoulder, elbow, wrist = upper:GetTranslation(), lower:GetTranslation(), hand:GetTranslation()
    local facing = Angle(0, client:EyeAngles().y, 0)
    local target = LerpVector(amount, wrist, head:GetTranslation() + facing:Right() * 5 + Vector(0, 0, 4))
    local nextElbow, nextHand = flux.speech.SolveArm(shoulder, elbow, wrist, target, facing:Forward())
    if not nextElbow then
        return
    end
    local upperInverse, lowerInverse, handInverse = upper:GetInverse(), lower:GetInverse(), hand:GetInverse()
    if not upperInverse or not lowerInverse or not handInverse then
        return
    end
    local heldHand = Matrix()
    heldHand:Set(hand)
    heldHand:SetTranslation(nextHand)
    local transforms = {
        rotateToward(upper, elbow - shoulder, nextElbow - shoulder, shoulder) * upperInverse,
        rotateToward(lower, wrist - elbow, nextHand - nextElbow, nextElbow) * lowerInverse,
        heldHand * handInverse,
    }
    -- Capture the unmodified matrices before applying parent transforms.
    local matrices = {}
    for index, child in ipairs(bones.children) do
        matrices[index] = client:GetBoneMatrix(child[1])
    end
    for index, child in ipairs(bones.children) do
        if matrices[index] then
            client:SetBoneMatrix(child[1], transforms[child[2]] * matrices[index])
        end
    end
end

local function attach(client)
    if not IsValid(client) or not client:IsPlayer() then
        return
    end
    local state = client:GetTable()
    if state.fluxSpeechBoneCallback then
        client:RemoveCallback("BuildBonePositions", state.fluxSpeechBoneCallback)
    end
    -- Dispose the previous gesture on refresh. When the flag clears, the next
    -- native bone build restores the arm without persistent bone manipulation.
    if state.fluxSpeechSequence or state.fluxSpeechNativeActive then
        client:AnimResetGestureSlot(GESTURE_SLOT_VCD)
    end
    state.ChatGestureWeight = 0
    state.fluxSpeechSequence, state.fluxSpeechUntil, state.fluxSpeechNext = nil, nil, nil
    state.fluxSpeechPoseModel, state.fluxSpeechBones = nil, nil
    state.fluxSpeechBonesChecked, state.fluxSpeechNativeActive = nil, nil
    state.fluxSpeechBlend, state.fluxSpeechBlendFrame = 0, nil
    state.fluxSpeechBoneCallback = client:AddCallback("BuildBonePositions", pose)
end

hook.Add("NetworkEntityCreated", "Flux.Speech.Pose", attach)
for _, client in player.Iterator() do
    attach(client)
end
