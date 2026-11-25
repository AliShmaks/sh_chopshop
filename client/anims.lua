-- anims.lua

-- 👇 FIX #1: carryKillFlag was a single shared boolean that could kill the wrong
-- carry thread when you chop parts back-to-back. Now uses a generation counter.
local carryGeneration = 0

-- =========================================================
-- ANIMS
-- =========================================================
function StopCarryPose(ped)
    carryGeneration = carryGeneration + 1
    if DoesEntityExist(ped) then
        ClearPedTasksImmediately(ped)
        SetEntityCollision(ped, true, true)
        SetEntityDynamic(ped, true)
        FreezeEntityPosition(ped, false)
    end
end

function ChopWheelAnimation()
    local ped = PlayerPedId()
    local dict, clip, flag = 'wymianakola@animation', 'wymiana_clip', 39
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    if not HasAnimDictLoaded(dict) then return false end
    TaskPlayAnim(ped, dict, clip, 3.0, -1.0, -1, flag, 0.3, false, false, false)
    return true, function()
        ClearPedTasks(ped)
        SetEntityCollision(ped, true, true)
        SetEntityDynamic(ped, true)
        FreezeEntityPosition(ped, false)
    end
end

local grindAnim, grindAnimTried = nil, false

-- Returns ok, stopFn. ok=false means no grind animation exists (caller falls back).
function StartGrindAnim()
    local ped = PlayerPedId()
    if not grindAnim and not grindAnimTried then
        grindAnimTried = true
        grindAnim = LoadFirstAnim(Config.GrindAnims)
    end
    if not grindAnim then return false end
    if not HasAnimDictLoaded(grindAnim.dict) then
        RequestAnimDict(grindAnim.dict)
        local t = GetGameTimer() + 1000
        while not HasAnimDictLoaded(grindAnim.dict) and GetGameTimer() < t do Wait(0) end
        if not HasAnimDictLoaded(grindAnim.dict) then return false end
    end
    TaskPlayAnim(ped, grindAnim.dict, grindAnim.clip, 3.0, -3.0, -1, 1, 0.0, false, false, false)
    return true, function()
        ClearPedTasksImmediately(ped)
        SetEntityCollision(ped, true, true)
        SetEntityDynamic(ped, true)
        FreezeEntityPosition(ped, false)
    end
end

-- Realistic sparks: random bursts around the cut point + a flickering orange light.
-- isActive() is polled every frame, the effect stops as soon as it returns false.
function StartSparks(veh, part, isActive)
    local cfg = Config.Sparks
    if not cfg or not cfg.enabled then return end
    local isBody = part.doorIndex ~= nil
    local isWheel = part.wheelIndex ~= nil
    if isBody and not cfg.bodyParts then return end
    if isWheel and not cfg.wheels then return end
    if not isBody and not isWheel then return end

    CreateThread(function()
        local asset = cfg.asset or 'core'
        RequestNamedPtfxAsset(asset)
        local t = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < t do Wait(0) end
        if not HasNamedPtfxAssetLoaded(asset) then return end

        local boneIdx = GetEntityBoneIndexByName(veh, GetEffectivePartBone(veh, part))
        local effects = cfg.effects or {}
        local spread = tonumber(cfg.spread) or 0.1
        local blend = math.max(0.0, math.min(1.0, tonumber(cfg.blendToPart) or 0.6))
        local scale = tonumber(cfg.scale) or 0.9
        local minMs = math.floor(tonumber(cfg.burstMinMs) or 70)
        local maxMs = math.max(minMs, math.floor(tonumber(cfg.burstMaxMs) or 150))
        local nextBurst = 0

        while isActive() and DoesEntityExist(veh) do
            local partPos = (boneIdx ~= -1) and GetWorldPositionOfEntityBone(veh, boneIdx) or GetEntityCoords(veh)
            local toolPos = (State.heldToolProp and DoesEntityExist(State.heldToolProp)) and GetEntityCoords(State.heldToolProp) or GetEntityCoords(PlayerPedId())
            local pos = toolPos + (partPos - toolPos) * blend
            local now = GetGameTimer()

            if now >= nextBurst and #effects > 0 then
                for _, fx in ipairs(effects) do
                    UseParticleFxAsset(asset)
                    StartParticleFxNonLoopedAtCoord(
                        fx,
                        pos.x + (math.random() - 0.5) * spread,
                        pos.y + (math.random() - 0.5) * spread,
                        pos.z + (math.random() - 0.5) * spread,
                        0.0, 0.0, 0.0, scale, false, false, false
                    )
                end
                nextBurst = now + math.random(minMs, maxMs)
            end

            if cfg.light then
                DrawLightWithRange(
                    pos.x, pos.y, pos.z,
                    255, 140 + math.random(0, 60), 40,
                    2.0 + math.random() * 1.5,
                    2.0 + math.random() * 2.5
                )
            end
            Wait(0)
        end
    end)
end

function StartInternalChopAnim(part, veh)
    local ped = PlayerPedId()
    local crouchDict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@'
    local crouchClip = 'weed_crouch_checkingleaves_idle_01_inspector'
    local repairDict, repairClip = 'mini@repair', 'fixing_a_ped'

    RequestAnimDict(crouchDict)
    RequestAnimDict(repairDict)
    local timeout = GetGameTimer() + 3000
    while (not HasAnimDictLoaded(crouchDict) or not HasAnimDictLoaded(repairDict)) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasAnimDictLoaded(crouchDict) or not HasAnimDictLoaded(repairDict) then return false end

    TaskPlayAnim(ped, crouchDict, crouchClip, 3.0, -1.0, -1, 1, 0.0, false, false, false)
    Wait(50)
    local pedCoords = GetEntityCoords(ped)
    local pedRot = GetEntityRotation(ped, 2)
    TaskPlayAnimAdvanced(
        ped, repairDict, repairClip,
        pedCoords.x, pedCoords.y, pedCoords.z,
        pedRot.x, pedRot.y, pedRot.z,
        8.0, 8.0, -1, 49, 0.0, false, false, false
    )

    local partModel = joaat(GetPartProp(veh, part))
    RequestModel(partModel)
    return true, partModel
end

function AttachHeldPart(veh, part, partModel)
    local ped = PlayerPedId()
    if not HasModelLoaded(partModel) then
        RequestModel(partModel)
        local t = GetGameTimer() + 2000
        while not HasModelLoaded(partModel) and GetGameTimer() < t do Wait(0) end
    end
    if not HasModelLoaded(partModel) then return end

    local heldObj = CreateObject(partModel, 0.0, 0.0, 0.0, false, false, false)
    if not DoesEntityExist(heldObj) then return end

    -- 👇 keep held parts safe from GTA cleanup
    SetEntityAsMissionEntity(heldObj, true, true)

    AttachEntityToEntity(
        heldObj, ped, GetPedBoneIndex(ped, part.holdBone or 24818),
        part.holdOffset.x, part.holdOffset.y, part.holdOffset.z,
        part.holdRot.x, part.holdRot.y, part.holdRot.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(partModel)

    State.heldProps[veh] = State.heldProps[veh] or {}
    State.heldProps[veh][#State.heldProps[veh] + 1] = heldObj
    State.heldPart = { obj = heldObj, veh = veh, name = part.name }

    -- 👇 FIX #1: bump generation so any previous carry thread stops, then capture my generation
    local myGen = carryGeneration + 1
    carryGeneration = myGen

    if State.heldToolProp and DoesEntityExist(State.heldToolProp) then
        SetEntityVisible(State.heldToolProp, false, false)
    end

    local animDict = part.carryAnim and part.carryAnim.dict or 'anim@heists@box_carry@'
    local animClip = part.carryAnim and part.carryAnim.clip or 'idle'
    RequestAnimDict(animDict)
    local at = GetGameTimer() + 2000
    while not HasAnimDictLoaded(animDict) and GetGameTimer() < at do Wait(0) end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    CreateThread(function()
        while carryGeneration == myGen and DoesEntityExist(ped) and DoesEntityExist(heldObj) do
            Wait(400)
            if carryGeneration ~= myGen then break end
            if HasAnimDictLoaded(animDict) and not IsEntityPlayingAnim(ped, animDict, animClip, 3) then
                TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
        end
    end)
end