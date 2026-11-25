-- claim.lua
-- =========================================================
-- VEHICLE OWNERSHIP / CLAIM
-- =========================================================
lib.callback.register('sh_chopshop:isPlayerVehicle', function(source, plate)
    -- Rate limit: one lookup per 500 ms per player. The claim itself re-checks ownership
    -- on the server, so answering "false" here when throttled is safe.
    local now = GetGameTimer()
    if (State.plateCallbackLast[source] or 0) + 500 > now then return false end
    State.plateCallbackLast[source] = now
    return LookupPlayerPlate(plate)
end)

RegisterNetEvent('sh_chopshop:server:claimVehicle', function(netId, reportedParts, reportedDamagedParts, isBike, vehClass)
    local src = source
    netId = tonumber(netId)
    if not netId or netId == 0 or not IsNearChopShop(src) then
        TriggerClientEvent('sh_chopshop:client:claimResult', src, netId or 0, false)
        return
    end

    local veh = GetVehicleForNetId(netId)
    if veh == 0 then
        TriggerClientEvent('sh_chopshop:client:claimResult', src, netId, false)
        return
    end

    local blacklisted = IsBlacklistedVehicle(veh) or IsBlacklistedClass(vehClass)
    if blacklisted or IsPlayerOwnedVehicle(veh) then
        TriggerClientEvent('sh_chopshop:client:claimResult', src, netId, false, 'handled')
        Notify(src, blacklisted and 'This vehicle cannot be chopped.' or 'Player-owned vehicles cannot be chopped.')
        return
    end

    if #(GetEntityCoords(veh) - Config.ChopShop.coords) > (Config.ChopShop.radius + 15.0) then
        TriggerClientEvent('sh_chopshop:client:claimResult', src, netId, false, 'handled')
        Notify(src, 'Bring the vehicle into the chop shop area first.')
        return
    end

    local owner = State.claimedVehicles[netId]
    if owner and owner.src ~= src then
        TriggerClientEvent('sh_chopshop:client:claimResult', src, netId, false)
        return
    end

    -- 30 minute cooldown (re-opening your own active claim does not count as a new job)
    local isNewJob = not (owner and owner.src == src)
    if isNewJob then
        local remaining = GetChopCooldownRemaining(src)
        if remaining > 0 then
            Notify(src, ('You can chop again in %s.'):format(FormatCooldown(remaining)), 'error', 6000)
            TriggerClientEvent('sh_chopshop:client:claimResult', src, netId, false, 'cooldown')
            return
        end
    end

    local okType, vType = pcall(GetVehicleType, veh)
    if okType and type(vType) == 'string' and vType ~= '' then
        isBike = (vType == 'bike')
    else
        isBike = isBike == true
    end

    local validParts, invalidReason = ValidateReportedParts(reportedParts, isBike)
    if not validParts then
        Notify(src, invalidReason)
        TriggerClientEvent('sh_chopshop:client:claimResult', src, netId, false, 'handled')
        return
    end

    State.claimedVehicles[netId] = { src = src, last = GetGameTimer() }
    local required, damaged = BuildRequiredParts(reportedParts, reportedDamagedParts, isBike, GetEntityModel(veh))
    State.requiredPartsByVehicle[netId] = required
    State.damagedPartsByVehicle[netId] = damaged
    State.motorcycleByVehicle[netId] = isBike
    State.choppedPartsByVehicle[netId] = State.choppedPartsByVehicle[netId] or {}
    for name in pairs(damaged) do State.choppedPartsByVehicle[netId][name] = true end
    State.rewardedPartsByVehicle[netId] = State.rewardedPartsByVehicle[netId] or {}
    if isNewJob then StartChopCooldown(src) end
    TriggerClientEvent('sh_chopshop:client:claimResult', src, netId, true)
end)

RegisterNetEvent('sh_chopshop:server:releaseVehicle', function(netId)
    local src = source
    netId = tonumber(netId)
    local claim = netId and State.claimedVehicles[netId]
    if claim and claim.src == src and not State.sellingVehicles[netId] then
        ClearClaim(netId, true)
    end
end)
