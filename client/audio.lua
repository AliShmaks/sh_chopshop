-- audio.lua

local activeWheelSounds = {}
local lastNuiListener = { x = 0.0, y = 0.0, z = 0.0, t = 0 }
-- =========================================================
-- WHEEL AUDIO (3D NUI — nearby only, no spam)
-- =========================================================
RegisterNetEvent('sh_chopshop:client:startWheelSound', function(netId, coords)
    if not netId or not coords then return end
    local pos = vector3(coords.x, coords.y, coords.z)
    if #(GetEntityCoords(PlayerPedId()) - pos) > 40.0 then return end
    activeWheelSounds[netId] = { coords = pos }
    SendNUIMessage({
        action = 'start',
        id = tostring(netId),
        x = pos.x, y = pos.y, z = pos.z
    })
end)

RegisterNetEvent('sh_chopshop:client:stopWheelSound', function(netId)
    if not netId then return end
    activeWheelSounds[netId] = nil
    SendNUIMessage({ action = 'stop', id = tostring(netId) })
end)

-- 🆕 GRINDER SOUND (doors/hood/trunk) — nearby only
RegisterNetEvent('sh_chopshop:client:startGrinderSound', function(netId, coords)
    if not netId or not coords then return end
    local pos = vector3(coords.x, coords.y, coords.z)
    if #(GetEntityCoords(PlayerPedId()) - pos) > 40.0 then return end
    activeWheelSounds[netId .. '_grinder'] = { coords = pos }   -- reuse listener thread
    SendNUIMessage({
        action = 'startGrinder',
        id = tostring(netId),
        x = pos.x, y = pos.y, z = pos.z
    })
end)

RegisterNetEvent('sh_chopshop:client:stopGrinderSound', function(netId)
    if not netId then return end
    activeWheelSounds[netId .. '_grinder'] = nil
    SendNUIMessage({ action = 'stop', id = tostring(netId) })
end)

CreateThread(function()
    while true do
        if not next(activeWheelSounds) then
            Wait(750)
        else
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local fwd = GetEntityForwardVector(ped)
            local now = GetGameTimer()
            if now - lastNuiListener.t > 180 then
                local moved = #(playerCoords - vector3(lastNuiListener.x, lastNuiListener.y, lastNuiListener.z))
                if moved > 0.35 then
                    lastNuiListener = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z, t = now }
                    SendNUIMessage({
                        action = 'listener',
                        x = playerCoords.x, y = playerCoords.y, z = playerCoords.z,
                        fx = fwd.x, fy = fwd.y, fz = fwd.z
                    })
                else
                    lastNuiListener.t = now
                end
            end
            Wait(200)
        end
    end
end)
