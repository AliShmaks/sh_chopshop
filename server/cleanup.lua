-- cleanup.lua

local CLAIM_STALE_MS = 180000
-- =========================================================
-- CLEANUP
-- =========================================================
CreateThread(function()
    while true do
        Wait(10000)
        local now = GetGameTimer()
        local nowSec = os.time()
        for key, untilAt in pairs(State.chopCooldown) do
            if untilAt <= nowSec then State.chopCooldown[key] = nil end
        end
        for netId, claim in pairs(State.claimedVehicles) do
            if not State.sellingVehicles[netId] then
                local stale = (now - (claim.last or 0)) > CLAIM_STALE_MS
                local leftArea = not IsInJobArea(claim.src)
                local veh = GetVehicleForNetId(netId)
                if stale or leftArea or veh == 0 then
                    if State.activeWheelSounds[netId] then StopWheelSound(netId) end
                    if State.activeGrinderSounds[netId] then StopGrinderSound(netId) end
                    ClearClaim(netId, true)
                    TriggerClientEvent('sh_chopshop:client:claimReleased', claim.src, netId)
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped ~= 0 then
        TriggerNearby('sh_chopshop:client:hideHeldTool', GetEntityCoords(ped), BROADCAST_RANGE, tonumber(src))
    end
    State.playerTool[src] = nil
    State.playerToolSlot[src] = nil
    State.lastDrop[src] = nil
    State.plateCallbackLast[src] = nil

    for netId, owner in pairs(State.activeWheelSounds) do
        if owner == src then StopWheelSound(netId) end
    end
    for netId, owner in pairs(State.activeGrinderSounds) do
        if owner == src then StopGrinderSound(netId) end
    end

    for netId, claim in pairs(State.claimedVehicles) do
        if claim.src == src then
            State.choppingNow[netId] = nil
            ClearClaim(netId, true)
        end
    end
end)
