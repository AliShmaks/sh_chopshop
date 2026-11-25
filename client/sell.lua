-- sell.lua

local pendingSales = {}
-- =========================================================
-- SELL NPC + DROP-OFF
-- =========================================================
local function SpawnPed(model, coords, scenario)
    local hash = joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetEntityHeading(ped, coords.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, scenario, 0, true)
    SetModelAsNoLongerNeeded(hash)
    return ped
end

CreateThread(function()
    Wait(1000)
    State.sellPed = SpawnPed(Config.SellNPC.model, Config.SellNPC.coords, Config.SellNPC.scenario)
    exports.ox_target:addLocalEntity(State.sellPed, {
        {
            name = 'chopshop_sell',
            icon = 'fas fa-dollar-sign',
            label = 'Sell chopped car',
            onSelect = function() SellChoppedCar() end
        }
    })
end)

CreateThread(function()
    Wait(2000)
    local spot = Config.PartDropoff
    if not spot then return end
    exports.ox_target:addSphereZone({
        coords = spot.coords,
        radius = spot.radius or 2.0,
        debug = false,
        options = {
            {
                name = 'chopshop_place_part',
                icon = spot.icon or 'fas fa-box',
                label = spot.label or 'Place Part',
                canInteract = function() return State.heldPart ~= nil end,
                onSelect = function() PlaceHeldPart() end,
            },
        },
    })
end)

-- =========================================================
-- PLACE HELD PART
-- =========================================================
function PlaceHeldPart()
    if not State.heldPart or not DoesEntityExist(State.heldPart.obj) then
        Notify('You are not holding a part.', 'error')
        return
    end

    local ped = PlayerPedId()
    local name = State.heldPart.name
    local coords = GetEntityCoords(ped)
    local dropObj = State.heldPart.obj
    local fwd = GetEntityForwardVector(ped)

    DetachEntity(dropObj, true, true)
    SetEntityCoords(dropObj, coords.x + fwd.x * 0.35, coords.y + fwd.y * 0.35, coords.z + 0.15, false, false, false, false)
    SetEntityRotation(dropObj, 0.0, 0.0, GetEntityHeading(ped), 2, false)
    SetEntityCollision(dropObj, true, true)
    SetEntityDynamic(dropObj, true)
    SetEntityHasGravity(dropObj, true)
    FreezeEntityPosition(dropObj, false)
    SetEntityVelocity(dropObj, fwd.x * 0.15, fwd.y * 0.15, -0.15)

    CreateThread(function()
        local maxSettleTime = GetGameTimer() + 1200
        while GetGameTimer() < maxSettleTime do
            Wait(100)
            if not DoesEntityExist(dropObj) then return end
            if #GetEntityVelocity(dropObj) < 0.15 then
                SetEntityVelocity(dropObj, 0.0, 0.0, 0.0)
                FreezeEntityPosition(dropObj, true)
                return
            end
        end
        if DoesEntityExist(dropObj) then
            SetEntityVelocity(dropObj, 0.0, 0.0, 0.0)
            FreezeEntityPosition(dropObj, true)
        end
    end)

    if State.heldPart.veh and State.heldProps[State.heldPart.veh] then
        for i, obj in ipairs(State.heldProps[State.heldPart.veh]) do
            if obj == State.heldPart.obj then
                table.remove(State.heldProps[State.heldPart.veh], i)
                break
            end
        end
    end

    State.heldPart = nil
    if State.heldToolProp and DoesEntityExist(State.heldToolProp) then
        SetEntityVisible(State.heldToolProp, true, false)
    end
    StopCarryPose(ped)
    State._menuDirty = true
    Notify(('%s dropped.'):format(name:sub(1, 1):upper() .. name:sub(2)), 'success')

    if name == 'gearbox' and not State.gearboxDropped then
        State.gearboxDropped = true
        SetTimeout(1000, function()
            Notify(Config.Notify.jobFinished, 'success')
        end)
    end
end

-- =========================================================
-- DELETE / SELL
-- =========================================================
RegisterNetEvent('sh_chopshop:client:deleteVehicle', function(netId)
    CreateThread(function()
        local timeout = GetGameTimer() + 5000
        local veh = 0
        while GetGameTimer() < timeout do
            veh = NetworkGetEntityFromNetworkId(netId)
            if veh ~= 0 and DoesEntityExist(veh) then break end
            Wait(100)
        end
        if veh == 0 or not DoesEntityExist(veh) then return end

        local ctrlTimeout = GetGameTimer() + 3000
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < ctrlTimeout do
            NetworkRequestControlOfEntity(veh)
            Wait(50)
        end

        if NetworkHasControlOfEntity(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            State._playerVehicleCache[veh] = nil
            State._netIdCache[veh] = nil
            State.availableParts[veh] = nil
            State.damagedParts[veh] = nil
            DeleteVehicle(veh)
        end
    end)
end)

RegisterNetEvent('sh_chopshop:client:sellResult', function(netId, success, message)
    local veh = pendingSales[netId]
    pendingSales[netId] = nil
    if veh then State._playerVehicleCache[veh] = nil end
    if message and message ~= '' then
        Notify(message, success and 'success' or 'error')
    end
    if not success then return end

    if veh and DoesEntityExist(veh) then
        CleanupVehicleDebris(veh)
        UnlockVehicle(veh)
        SetEntityAsMissionEntity(veh, true, true)
        State._netIdCache[veh] = nil
        State.availableParts[veh] = nil
        State.damagedParts[veh] = nil
        DeleteVehicle(veh)
        State.choppedParts[veh] = nil
    end

    ResetOpenedVehicle(false)
end)

function SellChoppedCar()
    if State.heldPart then
        Notify('Drop the part you are holding first.', 'error')
        return
    end

    local veh = State.openedVehicle
    if not veh or not DoesEntityExist(veh) then
        Notify(Config.Notify.noVehicle, 'error')
        return
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local vehCoords = GetEntityCoords(veh)
    local npcCoords = vector3(Config.SellNPC.coords.x, Config.SellNPC.coords.y, Config.SellNPC.coords.z)
    if #(vehCoords - npcCoords) > 40.0 or #(vehCoords - pedCoords) > 35.0 then
        Notify('Bring your chopped vehicle to the buyer.', 'error')
        return
    end

    if not IsFullyChopped(veh) then
        local missing = {}
        local cp = State.choppedParts[veh] or {}
        for _, part in ipairs(Config.VehicleParts) do
            if IsPartAvailable(veh, part.name) and not cp[part.name] then
                missing[#missing + 1] = part.label or part.name
            end
        end
        Notify(Config.Notify.notChopped, 'error')
        if #missing > 0 then
            Notify('Still on the car: ' .. table.concat(missing, ', '), 'error')
        end
        return
    end

    local damagedCount = 0
    for _ in pairs(State.damagedParts[veh] or {}) do damagedCount = damagedCount + 1 end
    local bike = IsMotorcycle(veh)
    local estimatedReward, penaltyTotal = Config.GetSaleValue(bike, damagedCount)
    local saleText = ('Sell this fully chopped %s for $%d dirty money?'):format(bike and 'motorcycle' or 'vehicle', estimatedReward)
    if damagedCount > 0 then
        saleText = saleText .. ('\n\n%d broken/missing part(s): -$%d total.'):format(damagedCount, penaltyTotal)
    end
    saleText = saleText .. '\n\nOnly parts this vehicle actually has are required.'
    local alert = lib.alertDialog({
        header = 'Sell Vehicle',
        content = saleText,
        centered = true,
        cancel = true
    })
    if alert ~= 'confirm' then return end

    local sellNetId = EnsureNetworked(veh)
    if sellNetId == 0 then
        Notify('Vehicle not networked — try again in a second.', 'error')
        return
    end
    if pendingSales[sellNetId] then
        Notify('This vehicle is already being sold. Please wait.', 'error')
        return
    end

    pendingSales[sellNetId] = veh
    TriggerServerEvent('sh_chopshop:server:sellCar', sellNetId)
end
