-- sell.lua
-- =========================================================
-- SELL
-- =========================================================
RegisterNetEvent('sh_chopshop:server:sellCar', function(netId)
    local src = source
    netId = tonumber(netId)
    if not QBCore.Functions.GetPlayer(src) then return end

    local function Fail(message)
        TriggerClientEvent('sh_chopshop:client:sellResult', src, netId or 0, false, message)
    end

    if not netId or netId == 0 then
        Fail('Vehicle is not networked — try again.')
        return
    end
    if State.sellingVehicles[netId] then
        Fail('This vehicle is already being sold.')
        return
    end

    local claim = State.claimedVehicles[netId]
    if not claim or claim.src ~= src then
        Fail('You do not own this vehicle claim.')
        return
    end
    if not IsNearSaleNPC(src, 7.0) then
        Fail('You must be beside the buyer to sell the vehicle.')
        return
    end

    local veh = GetVehicleForNetId(netId)
    if veh == 0 then
        Fail('The vehicle could not be found. Bring it closer and try again.')
        return
    end

    local npcCoords = vector3(Config.SellNPC.coords.x, Config.SellNPC.coords.y, Config.SellNPC.coords.z)
    if #(GetEntityCoords(veh) - npcCoords) > 40.0 then
        Fail('Bring the chopped vehicle closer to the buyer.')
        return
    end

    local chopped = State.choppedPartsByVehicle[netId] or {}
    local complete, missingPart = HasAllParts(netId, chopped)
    if not complete then
        Fail(('Vehicle is not fully chopped yet. Missing: %s'):format(missingPart))
        return
    end

    local reward = Config.Reward and Config.Reward.dirtyMoney
    local moneyItem = reward and reward.item
    local isBike = State.motorcycleByVehicle[netId] == true
    local damagedCount = 0
    for _ in pairs(State.damagedPartsByVehicle[netId] or {}) do damagedCount = damagedCount + 1 end
    local moneyAmount, penaltyTotal, baseAmount = Config.GetSaleValue(isBike, damagedCount)
    if not moneyItem or baseAmount < 1 then
        Fail('The sale reward is not configured correctly. Contact an administrator.')
        return
    end

    State.sellingVehicles[netId] = true
    local success = true
    if moneyAmount > 0 then
        success = Inventory.AddItem and Inventory.AddItem(src, moneyItem, moneyAmount)
    end
    if not success then
        State.sellingVehicles[netId] = nil
        Fail('Inventory full — cannot give dirty money!')
        return
    end

    local soldCoords = GetEntityCoords(veh)
    ClearClaim(netId, false)

    ForEachNearby(soldCoords, 100.0, function(playerId)
        TriggerClientEvent('sh_chopshop:client:deleteVehicle', playerId, netId)
    end)
    if DoesEntityExist(veh) then
        DeleteEntity(veh)
    end

    local saleMessage = ('%s sold! +$%d dirty money'):format(isBike and 'Motorcycle' or 'Vehicle', moneyAmount)
    if damagedCount > 0 then
        saleMessage = saleMessage .. (' (%d broken/missing part(s), -$%d)'):format(damagedCount, penaltyTotal)
    end
    TriggerClientEvent('sh_chopshop:client:sellResult', src, netId, true, saleMessage)
end)
