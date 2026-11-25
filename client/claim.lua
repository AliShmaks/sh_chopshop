-- claim.lua

local claimWaiters = {}
-- =========================================================
-- CLAIM
-- =========================================================
RegisterNetEvent('sh_chopshop:client:claimResult', function(netId, granted, reason)
    local w = claimWaiters[netId]
    if not w or w.resolved then return end
    w.resolved = true
    w.reason = reason
    w.p:resolve(granted == true)
end)

local function RequestClaim(netId, partNames, damagedNames, isBike, vehClass)
    local p = promise.new()
    claimWaiters[netId] = { p = p, resolved = false }
    TriggerServerEvent('sh_chopshop:server:claimVehicle', netId, partNames, damagedNames, isBike == true, vehClass)
    SetTimeout(3000, function()
        local w = claimWaiters[netId]
        if w and not w.resolved then
            w.resolved = true
            w.p:resolve(false)
        end
    end)
    local granted = Citizen.Await(p)
    local reason = claimWaiters[netId] and claimWaiters[netId].reason
    claimWaiters[netId] = nil
    return granted, reason
end

function ReleaseClaim(veh)
    if veh and DoesEntityExist(veh) then
        local netId = VehToNet(veh)
        if netId ~= 0 then
            TriggerServerEvent('sh_chopshop:server:releaseVehicle', netId)
        end
    elseif State.openedNetId ~= 0 then
        TriggerServerEvent('sh_chopshop:server:releaseVehicle', State.openedNetId)
    end
end

RegisterNetEvent('sh_chopshop:client:claimReleased', function(netId)
    if State.openedNetId == netId then
        ResetOpenedVehicle(true)
        Notify('Chop claim released — you left the area.', 'inform')
    end
end)

-- =========================================================
-- OPEN / CLAIM
-- =========================================================
-- Opens ONLY the doors / hood / trunk this exact car really has.
-- (2-door car = 2 doors, no rear doors; no trunk bone = nothing to open there; bikes = nothing to open.)
local function OpenAllValidDoors(veh, avail)
    if not DoesEntityExist(veh) or IsMotorcycle(veh) then return end
    for _, part in ipairs(Config.VehicleParts) do
        if part.doorIndex ~= nil and avail[part.name] and not IsVehicleDoorDamaged(veh, part.doorIndex) then
            SetVehicleDoorOpen(veh, part.doorIndex, false, false)
        end
    end
end

local function TryOpenParts()
    if not IsInChopShopZone() then return end
    if State.vehicleClaimedOnce then return end
    State.vehicleClaimedOnce = true

    local ped = PlayerPedId()
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local veh

    if inVehicle then
        veh = GetVehiclePedIsIn(ped, false)
    else
        veh = GetNearestVehicle(6.0)
    end

    if not veh or veh == 0 or not DoesEntityExist(veh) then
        State.vehicleClaimedOnce = false
        return
    end
    if IsVehicleBlacklisted(veh) then
        Notify(Config.Notify.blacklisted, 'error')
        State.vehicleClaimedOnce = false
        return
    end
    if IsPlayerVehicle(veh) then
        Notify('You cannot chop a player-owned vehicle', 'error')
        State.vehicleClaimedOnce = false
        return
    end

    local netId = EnsureNetworked(veh)
    if netId == 0 then
        Notify('This car is not networked yet — try again in a second.', 'error')
        State.vehicleClaimedOnce = false
        return
    end

    -- figure out which parts this specific car actually has (and which are already broken off)
    local avail = ComputeAvailableParts(veh)
    local damaged = ComputeDamagedParts(veh, avail)
    local partNames, damagedNames = {}, {}
    for name in pairs(avail) do partNames[#partNames + 1] = name end
    for name in pairs(damaged) do damagedNames[#damagedNames + 1] = name end
    local isBike = IsMotorcycle(veh)

    local granted, denyReason = RequestClaim(netId, partNames, damagedNames, isBike, GetVehicleClass(veh))
    if not granted then
        -- when the server sent a reason it already notified the player
        if not denyReason then
            Notify('Someone else is already chopping this car.', 'error')
        end
        State.vehicleClaimedOnce = false
        return
    end

    -- The car is ours now. If the player is inside: stop it, open everything, then get out.
    if inVehicle then
        SetVehicleEngineOn(veh, false, true, true)
        SetVehicleUndriveable(veh, true)
        OpenAllValidDoors(veh, avail)
        Wait(300)
        TaskLeaveVehicle(ped, veh, 0)
        local waited = 0
        while IsPedInAnyVehicle(ped, false) and waited < 100 do
            Wait(50)
            waited = waited + 1
        end
    end

    State.availableParts[veh] = avail
    State.damagedParts[veh] = damaged
    State.manualClosed[veh] = {}
    State.openedVehicle = veh
    State.openedNetId = netId
    State.wheelsDoneLock = false
    State.choppedParts[veh] = State.choppedParts[veh] or {}
    -- Parts already destroyed before the claim count as completed, but reduce the final sale payout.
    for name in pairs(damaged) do State.choppedParts[veh][name] = true end
    State.gearboxDropped = false
    State._menuDirty = true

    SetVehicleEngineOn(veh, false, true, true)
    OpenAllValidDoors(veh, avail)
    LockVehicle(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    Notify(Config.Notify.opened, 'success')
end

-- Keep every door / hood / trunk OPEN. GTA likes to swing them shut when the car settles or gets bumped.
-- A panel only stays closed if the player closed it on purpose with "Toggle".
CreateThread(function()
    while true do
        Wait(700)
        local veh = State.openedVehicle
        if veh and DoesEntityExist(veh) and not IsMotorcycle(veh) then
            local avail = State.availableParts[veh]
            if avail then
                local cp = State.choppedParts[veh] or {}
                local closedByPlayer = State.manualClosed[veh] or {}
                for _, part in ipairs(Config.VehicleParts) do
                    if part.doorIndex ~= nil and avail[part.name] and not cp[part.name] and not closedByPlayer[part.name] then
                        if not IsVehicleDoorDamaged(veh, part.doorIndex)
                            and GetVehicleDoorAngleRatio(veh, part.doorIndex) < 0.05 then
                            SetVehicleDoorOpen(veh, part.doorIndex, false, false)
                        end
                    end
                end
            end
        end
    end
end)

RegisterCommand('chopshop_open', function()
    CreateThread(TryOpenParts)
end, false)
RegisterCommand('chopshop_open_alt', function()
    CreateThread(TryOpenParts)
end, false)
RegisterKeyMapping('chopshop_open', 'Open Chop Shop Parts', 'keyboard', 'E')
RegisterKeyMapping('chopshop_open_alt', 'Open Chop Shop Parts (G)', 'keyboard', 'G')
