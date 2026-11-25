-- chop.lua

local CHOP_TIME = tonumber(Config.ChopTime) or 5000
-- =========================================================
-- CHOP
-- =========================================================
local function GetBoneCoords(veh, bone)
    local idx = GetEntityBoneIndexByName(veh, bone)
    if idx == -1 then return nil end
    return GetWorldPositionOfEntityBone(veh, idx)
end

-- Full wheel (rim + rubber): first configured model that exists in the game, else the part's own prop.
local function ResolveWheelModel(part)
    local cfg = Config.WheelDebris
    for _, name in ipairs((cfg and cfg.props) or {}) do
        local h = joaat(name)
        if IsModelInCdimage(h) and IsModelValid(h) then return h end
    end
    return joaat(part.prop)
end

local function SpawnDebris(veh, part)
    local coords = GetBoneCoords(veh, GetEffectivePartBone(veh, part))
    if not coords then return end
    local hash = (part.wheelIndex ~= nil) and ResolveWheelModel(part) or joaat(part.prop)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 20 do Wait(50) timeout = timeout + 1 end
    if not HasModelLoaded(hash) then return end

    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(obj, true, true)
    SetEntityDynamic(obj, true)
    SetEntityHasGravity(obj, true)
    SetEntityVelocity(obj, (math.random() - 0.5), (math.random() - 0.5), -1.0)
    -- 👇 protect from GTA cleanup
    SetEntityAsMissionEntity(obj, true, true)

    State.vehicleDebris[veh] = State.vehicleDebris[veh] or {}
    State.vehicleDebris[veh][#State.vehicleDebris[veh] + 1] = obj
    local lifetime = tonumber(Config.WheelDebris and Config.WheelDebris.lifetimeMs) or 10000
    SetTimeout(lifetime, function() if DoesEntityExist(obj) then DeleteEntity(obj) end end)
    SetModelAsNoLongerNeeded(hash)
end

local function RemovePart(veh, part)
    if not DoesEntityExist(veh) then return end

    if part.doorIndex ~= nil then
        SetVehicleDoorCanBreak(veh, part.doorIndex, false)
        SetVehicleDoorBroken(veh, part.doorIndex, false)
        SetVehicleDoorOpen(veh, part.doorIndex, false, false)
        PlaySoundFromEntity(-1, 'Metal_Snapping', veh, 'GTAO_FM_Events_Soundset', true, 0)
    end

    if part.wheelIndex ~= nil then
        local propMode = (Config.WheelDebris and Config.WheelDebris.mode) == 'prop'
        if propMode then SpawnDebris(veh, part) end
        FreezeEntityPosition(veh, false)
        SetVehicleHandbrake(veh, false)
        local wheelIndex = GetEffectiveWheelIndex(veh, part)
        if propMode then
            SetVehicleWheelHealth(veh, wheelIndex, 0.0)
            SetVehicleWheelTireColliderWidth(veh, wheelIndex, 0.0)
            SetVehicleWheelTireColliderSize(veh, wheelIndex, 0.0)
        end
        local breakFlag = (Config.WheelDebris and Config.WheelDebris.breakFlag) == true
        BreakOffVehicleWheel(veh, wheelIndex, true, propMode, breakFlag, false)

        local wheelBoneIdx = GetEntityBoneIndexByName(veh, GetEffectivePartBone(veh, part))
        if wheelBoneIdx ~= -1 then
            CreateThread(function()
                local start = GetGameTimer()
                while GetGameTimer() - start < 2000 do
                    if DoesEntityExist(veh) then
                        local wheelPos = GetWorldPositionOfEntityBone(veh, wheelBoneIdx)
                        RemoveParticleFxInRange(wheelPos.x, wheelPos.y, wheelPos.z, 2.5)
                    end
                    Wait(200)
                end
            end)
        end

        local coords = GetEntityCoords(veh)
        SetEntityCoords(veh, coords.x, coords.y, coords.z + 0.05, false, false, false, false)
        Wait(1500)
        if DoesEntityExist(veh) then
            SetEntityVelocity(veh, 0.0, 0.0, 0.0)
            SetVehicleHandbrake(veh, true)
        end
    end

    if part.internal then
        SetVehicleDoorOpen(veh, 4, false, false)
    end

    PlaySoundFrontend(-1, 'Metal_Snapping', 'GTAO_FM_Events_Soundset', true)
end

-- 👇 FIX #2: SetVehicleBodyHealth(200.0) is the most likely GTA-side trigger for
-- broken-off wheel debris being cleaned up. Removed.
local function MakeCarWrecked(veh)
    -- SetVehicleBodyHealth(veh, 200.0)   -- removed to protect real wheel debris
    SetVehicleEngineHealth(veh, 500.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleUndriveable(veh, true)
    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleDirtLevel(veh, 15.0)
    StartVehicleAlarm(veh)
end

-- 👇 FIX #2b: While a claim is open, pin every loose object near the car as a
-- mission entity, so GTA never garbage-collects broken-off wheels / dropped parts.
CreateThread(function()
    while true do
        Wait(1500)
        local veh = State.openedVehicle
        if veh and DoesEntityExist(veh) then
            local pos = GetEntityCoords(veh)
            local ok, objects = pcall(GetGamePool, 'CObject')
            if ok and objects then
                for _, obj in ipairs(objects) do
                    if DoesEntityExist(obj) and not IsEntityAMissionEntity(obj) then
                        if #(GetEntityCoords(obj) - pos) < 10.0 then
                            SetEntityAsMissionEntity(obj, true, true)
                        end
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('sh_chopshop:client:chopPart', function(veh, partName)
    if State.isChopping or not DoesEntityExist(veh) then return end
    if veh ~= State.openedVehicle then
        Notify('Open the car first (press E near it)', 'error')
        return
    end
    if IsPlayerVehicle(veh) then
        Notify('You cannot chop a player-owned vehicle', 'error')
        return
    end

    local part
    for _, p in ipairs(Config.VehicleParts) do
        if p.name == partName then part = p break end
    end
    if not part then return end

    if not IsPartAvailable(veh, partName) then
        Notify('This car does not have that part.', 'error')
        return
    end
    if not IsNearPart(veh, part) then
        Notify(('Get closer to the %s.'):format(part.label), 'error')
        return
    end

    if part.internal and State.heldPart then
        Notify('Drop the part you are holding first.', 'error')
        return
    end
    if State.choppedParts[veh] and State.choppedParts[veh][partName] then
        Notify('Already removed', 'error')
        return
    end
    if part.wheelIndex and not IsMotorcycle(veh) and not AreDoorsDone(veh) then
        Notify('Remove all doors, hood, and trunk first before the wheels.', 'error')
        return
    end
    if part.wheelIndex and State.heldTool ~= 'drill' then
        Notify(Config.Notify.needDrill, 'error')
        return
    end
    if part.doorIndex ~= nil and State.heldTool ~= 'grinder' then
        Notify(Config.Notify.needGrinder, 'error')
        return
    end
    if part.internal and not AreWheelsDone(veh) then
        Notify('Remove all wheels first before the internal parts.', 'error')
        return
    end
    if part.internal then
        local ok, needs = CanChopInternal(veh, partName)
        if not ok then
            Notify(('Chop the %s first.'):format(needs), 'error')
            return
        end
    end

    local netId = EnsureNetworked(veh)
    if netId == 0 then
        Notify('Vehicle is not networked yet.', 'error')
        return
    end

    State.isChopping = true
    local allowed, reason = lib.callback.await('sh_chopshop:beginChop', false, netId, partName)
    if not allowed then
        State.isChopping = false
        Notify(reason or 'Cannot chop that part.', 'error')
        return
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, veh, 1000)
    Wait(400)

    local isWheel = part.wheelIndex ~= nil
    local isBody = part.doorIndex ~= nil
    local isInternal = part.internal == true
    local stopAnim
    local partModel

    if isInternal then
        local ok, model = StartInternalChopAnim(part, veh)
        if not ok then
            TriggerServerEvent('sh_chopshop:server:cancelChop', netId)
            State.isChopping = false
            return
        end
        partModel = model
        stopAnim = function()
            ClearPedTasks(ped)
            SetEntityCollision(ped, true, true)
            SetEntityDynamic(ped, true)
            FreezeEntityPosition(ped, false)
        end
    elseif isWheel then
        local ok, stop = ChopWheelAnimation()
        if not ok then
            TriggerServerEvent('sh_chopshop:server:cancelChop', netId)
            State.isChopping = false
            return
        end
        stopAnim = stop
        TriggerServerEvent('sh_chopshop:server:startWheelSound', netId)
    else
        local usedGrindAnim = false
        if isBody then
            local ok, stop = StartGrindAnim()
            if ok then
                stopAnim = stop
                usedGrindAnim = true
            end
            TriggerServerEvent('sh_chopshop:server:startGrinderSound', netId)
        end
        if not usedGrindAnim then
            local animDict, animClip = 'mini@repair', 'fixing_a_ped'
            RequestAnimDict(animDict)
            local timeout = GetGameTimer() + 3000
            while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do Wait(50) end
            if not HasAnimDictLoaded(animDict) then
                TriggerServerEvent('sh_chopshop:server:cancelChop', netId)
                State.isChopping = false
                return
            end
            TaskPlayAnim(ped, animDict, animClip, 4.0, -4.0, -1, 1, 0.0, false, false, false)
            stopAnim = function()
                ClearPedTasks(ped)
                RemoveAnimDict(animDict)
            end
        end
    end

    local ms = tonumber(part.chopTime) or CHOP_TIME
    local verb = isBody and 'Grinding ' or (isWheel and 'Unbolting ' or 'Removing ')
    local sparking = true
    StartSparks(veh, part, function() return sparking end)
    local success = WorkBar(ms / 1000, verb .. part.label .. '...')
    sparking = false
    if isWheel then
        TriggerServerEvent('sh_chopshop:server:stopWheelSound', netId)
    end
    if isBody then
        TriggerServerEvent('sh_chopshop:server:stopGrinderSound', netId)
    end
    if stopAnim then stopAnim() else ClearPedTasksImmediately(ped) end
    State.isChopping = false
    if State.heldTool == 'grinder' then
        Wait(0)
        if not State.heldToolProp or not DoesEntityExist(State.heldToolProp) then
            AttachToolToHand(State.heldTool, ped)
        end
        ApplyHoldAnim()
    end

    if not success then
        TriggerServerEvent('sh_chopshop:server:cancelChop', netId)
        State.isChopping = false
        return
    end

    local finished, failReason = lib.callback.await('sh_chopshop:finishChop', false, netId, partName)
    if not finished then
        State.isChopping = false
        Notify(failReason or 'Chop was not accepted.', 'error')
        return
    end

    RemovePart(veh, part)
    State.choppedParts[veh] = State.choppedParts[veh] or {}
    State.choppedParts[veh][partName] = true
    State._menuDirty = true

    if isInternal and partModel then
        AttachHeldPart(veh, part, partModel)
    end

    Notify(Config.Notify.partChopped, 'success')

    if AreWheelsDone(veh) and not State.choppedParts[veh].wheelsNotified then
        State.choppedParts[veh].wheelsNotified = true
        State.wheelsDoneLock = true
        Notify('All wheels removed. You can now remove the battery, radiator, exhaust, and gearbox!', 'success')
    end

    if isBody and AreDoorsDone(veh) and not State.choppedParts[veh].bodyNotified then
        State.choppedParts[veh].bodyNotified = true
        if not IsFullyChopped(veh) then
            Notify('All body panels removed. Drop the grinder (X), then grab an impact driver for the wheels.', 'success')
        end
    end

    if IsFullyChopped(veh) then
        MakeCarWrecked(veh)
        Notify(Config.Notify.allChopped, 'success')
    end

    State.isChopping = false
end)

RegisterNetEvent('sh_chopshop:client:togglePart', function(veh, partName)
    if not DoesEntityExist(veh) or veh ~= State.openedVehicle then return end
    local part
    for _, p in ipairs(Config.VehicleParts) do
        if p.name == partName then part = p break end
    end
    if not part or not part.doorIndex then return end
    if State.choppedParts[veh] and State.choppedParts[veh][partName] then
        Notify('This part is removed', 'error')
        return
    end

    State.manualClosed[veh] = State.manualClosed[veh] or {}
    if GetVehicleDoorAngleRatio(veh, part.doorIndex) > 0.1 then
        State.manualClosed[veh][partName] = true
        SetVehicleDoorShut(veh, part.doorIndex, false)
        Notify(part.label .. ' closed', 'inform')
    else
        State.manualClosed[veh][partName] = nil
        SetVehicleDoorOpen(veh, part.doorIndex, false, false)
        Notify(part.label .. ' opened', 'success')
    end
end)

CreateThread(function()
    while true do
        Wait(400)
        if State.openedVehicle and DoesEntityExist(State.openedVehicle) and State._menuDirty then
            State._menuDirty = false
            exports.ox_target:removeLocalEntity(State.openedVehicle)

            local options = {}
            for _, part in ipairs(Config.VehicleParts) do
                local alreadyChopped = State.choppedParts[State.openedVehicle] and State.choppedParts[State.openedVehicle][part.name]
                if IsPartAvailable(State.openedVehicle, part.name) and not alreadyChopped then
                    local blocked = false
                    if part.wheelIndex and ((not IsMotorcycle(State.openedVehicle) and not AreDoorsDone(State.openedVehicle)) or State.heldTool ~= 'drill') then blocked = true end
                    if part.internal and not AreWheelsDone(State.openedVehicle) then blocked = true end
                    if part.internal and not blocked then
                        local ok = CanChopInternal(State.openedVehicle, part.name)
                        if not ok then blocked = true end
                    end
                    if part.internal and State.heldPart then blocked = true end

                    if not blocked then
                        options[#options + 1] = {
                            name = 'chop_' .. part.name,
                            icon = 'fas fa-wrench',
                            label = 'Chop ' .. part.label,
                            bones = { GetEffectivePartBone(State.openedVehicle, part) },
                            distance = part.wheelIndex and 1.0 or 1.1,
                            canInteract = function(entity, _, coords)
                                return IsNearPart(entity, part, coords)
                            end,
                            onSelect = function()
                                TriggerEvent('sh_chopshop:client:chopPart', State.openedVehicle, part.name)
                            end
                        }
                        if part.doorIndex then
                            options[#options + 1] = {
                                name = 'toggle_' .. part.name,
                                icon = 'fas fa-door-open',
                                label = 'Toggle ' .. part.label,
                                bones = { GetEffectivePartBone(State.openedVehicle, part) },
                                distance = 1.1,
                                canInteract = function(entity, _, coords)
                                    return IsNearPart(entity, part, coords)
                                end,
                                onSelect = function()
                                    TriggerEvent('sh_chopshop:client:togglePart', State.openedVehicle, part.name)
                                end
                            }
                        end
                    end
                end
            end

            if #options > 0 then
                exports.ox_target:addLocalEntity(State.openedVehicle, options)
            end
        end
    end
end)