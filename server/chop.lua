-- chop.lua
-- =========================================================
-- CHOP (begin / finish / cancel)
-- =========================================================
lib.callback.register('sh_chopshop:beginChop', function(source, netId, partName)
    netId = tonumber(netId)
    if not netId or netId == 0 or type(partName) ~= 'string' then return false, 'Invalid vehicle.' end

    local claim = State.claimedVehicles[netId]
    if not claim or claim.src ~= source then return false, 'You do not own this vehicle claim.' end
    if not IsNearChopShop(source, Config.ChopShop.radius + 8.0) then return false, 'You must be in the chop shop.' end

    local veh = GetVehicleForNetId(netId)
    if veh == 0 then return false, 'Vehicle not found.' end
    if #(GetEntityCoords(veh) - Config.ChopShop.coords) > (Config.ChopShop.radius + 15.0) then
        return false, 'Vehicle is outside the chop shop.'
    end
    -- 🆕 player must be near the vehicle, not just in the zone
    if not IsNearVehicle(source, veh, 6.0) then
        return false, 'You are too far from the vehicle.'
    end

    local part = VALID_PARTS[partName]
    if not part then return false, 'Unknown part.' end

    local active = State.choppingNow[netId]
    if active then return false, 'Already chopping this vehicle.' end

    State.choppedPartsByVehicle[netId] = State.choppedPartsByVehicle[netId] or {}
    local chopped = State.choppedPartsByVehicle[netId]
    if chopped[partName] then return false, 'Already removed.' end

    local ok, reason = CanChopPart(netId, chopped, part)
    if not ok then return false, reason end

    if part.wheelIndex ~= nil and State.playerTool[source] ~= 'drill' then
        return false, 'You need the impact driver first.'
    end
    if part.doorIndex ~= nil and State.playerTool[source] ~= 'grinder' then
        return false, 'You need an angle grinder first.'
    end

    State.choppingNow[netId] = { src = source, part = partName, started = GetGameTimer() }
    TouchClaim(netId)
    return true
end)

lib.callback.register('sh_chopshop:finishChop', function(source, netId, partName)
    netId = tonumber(netId)
    if not netId or type(partName) ~= 'string' then return false, 'Invalid request.' end

    local active = State.choppingNow[netId]
    if not active or active.src ~= source or active.part ~= partName then
        return false, 'Chop was not started.'
    end

    local claim = State.claimedVehicles[netId]
    if not claim or claim.src ~= source then
        State.choppingNow[netId] = nil
        return false, 'Claim lost.'
    end

    if not IsNearChopShop(source, Config.ChopShop.radius + 8.0) then
        State.choppingNow[netId] = nil
        return false, 'You left the chop shop.'
    end

    -- 🆕 finishChop must also re-validate vehicle proximity (prevents teleport-away cheat)
    local veh = GetVehicleForNetId(netId)
    if veh == 0 or not IsNearVehicle(source, veh, 8.0) then
        State.choppingNow[netId] = nil
        return false, 'You are too far from the vehicle.'
    end

    local part = VALID_PARTS[partName]
    if not part then
        State.choppingNow[netId] = nil
        return false
    end

    if (GetGameTimer() - active.started) < MinChopMs(part) then
        State.choppingNow[netId] = nil
        return false, 'Too fast.'
    end

    local chopped = State.choppedPartsByVehicle[netId] or {}
    if chopped[partName] then
        State.choppingNow[netId] = nil
        if part.internal then GiveInternalReward(source, netId, partName) end
        return true
    end

    local ok, reason = CanChopPart(netId, chopped, part)
    if not ok then
        State.choppingNow[netId] = nil
        return false, reason
    end

    chopped[partName] = true
    State.choppedPartsByVehicle[netId] = chopped
    State.choppingNow[netId] = nil
    TouchClaim(netId)

    if part.internal then
        GiveInternalReward(source, netId, partName)
    end

    return true
end)

RegisterNetEvent('sh_chopshop:server:cancelChop', function(netId)
    local src = source
    netId = tonumber(netId)
    local active = netId and State.choppingNow[netId]
    if active and active.src == src then
        State.choppingNow[netId] = nil
    end
end)

RegisterNetEvent('sh_chopshop:server:givePartMaterials', function() end)
RegisterNetEvent('sh_chopshop:server:giveMaterials', function() end)
