-- sounds.lua

local SOUND_RANGE = 40.0
-- =========================================================
-- WHEEL SOUND (nearby only)
-- =========================================================
function StopWheelSound(netId)
    if not State.activeWheelSounds[netId] then return end
    State.activeWheelSounds[netId] = nil
    TriggerNearby('sh_chopshop:client:stopWheelSound', Config.ChopShop.coords, SOUND_RANGE + 20.0, netId)
end

RegisterNetEvent('sh_chopshop:server:startWheelSound', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId or netId == 0 then return end

    local claim = State.claimedVehicles[netId]
    if not claim or claim.src ~= src then return end

    local veh = GetVehicleForNetId(netId)
    if veh == 0 then return end

    local coords = GetEntityCoords(veh)
    if #(coords - Config.ChopShop.coords) > (Config.ChopShop.radius + 15.0) then return end

    State.activeWheelSounds[netId] = src
    TriggerNearby('sh_chopshop:client:startWheelSound', coords, SOUND_RANGE + 15.0, netId, {
        x = coords.x, y = coords.y, z = coords.z
    })
end)

RegisterNetEvent('sh_chopshop:server:stopWheelSound', function(netId)
    netId = tonumber(netId)
    if not netId then return end
    if State.activeWheelSounds[netId] ~= source then return end
    StopWheelSound(netId)
end)

-- =========================================================
-- GRINDER SOUND (nearby only)
-- =========================================================
function StopGrinderSound(netId)
    if not State.activeGrinderSounds[netId] then return end
    State.activeGrinderSounds[netId] = nil
    TriggerNearby('sh_chopshop:client:stopGrinderSound', Config.ChopShop.coords, SOUND_RANGE + 20.0, netId)
end

RegisterNetEvent('sh_chopshop:server:startGrinderSound', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId or netId == 0 then return end

    local claim = State.claimedVehicles[netId]
    if not claim or claim.src ~= src then return end

    local veh = GetVehicleForNetId(netId)
    if veh == 0 then return end

    local coords = GetEntityCoords(veh)
    if #(coords - Config.ChopShop.coords) > (Config.ChopShop.radius + 15.0) then return end

    State.activeGrinderSounds[netId] = src
    TriggerNearby('sh_chopshop:client:startGrinderSound', coords, SOUND_RANGE + 15.0, netId, {
        x = coords.x, y = coords.y, z = coords.z
    })
end)

RegisterNetEvent('sh_chopshop:server:stopGrinderSound', function(netId)
    netId = tonumber(netId)
    if not netId then return end
    if State.activeGrinderSounds[netId] ~= source then return end
    StopGrinderSound(netId)
end)
