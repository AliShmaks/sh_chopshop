-- parts.lua

local INTERNAL_PARTS = { battery = true, radiator = true, exhaust = true, gearbox = true }
local INTERNAL_ORDER = { 'battery', 'radiator', 'exhaust', 'gearbox' }

local function IsOptionalMotorcyclePart(partName, isBike, modelHash)
    if not isBike then return false end
    if Config.MotorcycleOptionalParts and Config.MotorcycleOptionalParts[partName] == true then return true end
    local byModel = Config.MotorcyclePartsByModel
    local modelConfig = byModel and (byModel[modelHash] or byModel[tostring(modelHash)])
    if modelConfig and modelConfig[partName] == false then return true end
    return false
end

function BuildRequiredParts(reported, reportedDamaged, isBike, modelHash)
    local required, reportedSet, damaged = {}, {}, {}
    if type(reported) == 'table' then
        for _, name in ipairs(reported) do
            if type(name) == 'string' and VALID_PARTS[name] then
                reportedSet[name] = true
                required[name] = true
            end
        end
    end

    for name in pairs(INTERNAL_PARTS) do
        if not IsOptionalMotorcyclePart(name, isBike, modelHash) then
            required[name] = true
        end
    end

    if type(reportedDamaged) == 'table' then
        for _, name in ipairs(reportedDamaged) do
            local part = type(name) == 'string' and VALID_PARTS[name] or nil
            if part and reportedSet[name] and (part.doorIndex ~= nil or part.wheelIndex ~= nil) then
                damaged[name] = true
                required[name] = nil
            end
        end
    end
    return required, damaged
end

function ValidateReportedParts(reported, isBike)
    if type(reported) ~= 'table' or #reported > 64 then
        return false, 'Invalid vehicle data.'
    end

    -- 👇 Bikes: skip the anti-cheat entirely. Bike part reporting varies per model
    -- (some bikes use wheel_f/wheel_r, some don't have those bones at all) and the
    -- anti-cheat was rejecting legitimate bikes. Server-side CanChopPart still
    -- enforces wheels-before-internals order, so nothing can be cheated.
    if isBike then
        return true
    end

    local cfg = Config.AntiCheat or {}
    local minWheels = tonumber(cfg.minWheelsCar) or 3
    local minBody = tonumber(cfg.minBodyPanels) or 1

    local wheels, body, seen = 0, 0, {}
    for _, name in ipairs(reported) do
        local part = type(name) == 'string' and VALID_PARTS[name] or nil
        if part and not seen[name] then
            seen[name] = true
            if part.wheelIndex ~= nil then wheels = wheels + 1 end
            if part.doorIndex ~= nil then body = body + 1 end
        end
    end

    if wheels < minWheels or body < minBody then
        return false, 'This vehicle cannot be chopped (invalid part data).'
    end
    return true
end

local function IsRequired(netId, partName)
    local req = State.requiredPartsByVehicle[netId]
    if not req then return true end
    return req[partName] == true
end

function HasAllParts(netId, chopped)
    for _, part in ipairs(Config.VehicleParts or {}) do
        if IsRequired(netId, part.name) and not chopped[part.name] then
            return false, part.label or part.name
        end
    end
    return true
end

function CanChopPart(netId, chopped, part)
    if not IsRequired(netId, part.name) then
        return false, 'This vehicle does not have that part.'
    end

    if part.wheelIndex ~= nil then
        if not State.motorcycleByVehicle[netId] then
            for _, p in ipairs(Config.VehicleParts) do
                if p.doorIndex ~= nil and IsRequired(netId, p.name) and not chopped[p.name] then
                    return false, 'Remove all doors, hood, and trunk before removing wheels.'
                end
            end
        end
    elseif part.internal then
        for _, p in ipairs(Config.VehicleParts) do
            if p.wheelIndex ~= nil and IsRequired(netId, p.name) and not chopped[p.name] then
                return false, 'Remove all wheels before removing internal parts.'
            end
        end
        for _, required in ipairs(INTERNAL_ORDER) do
            if required == part.name then break end
            if IsRequired(netId, required) and not chopped[required] then
                return false, ('Remove the %s first.'):format(required)
            end
        end
    end
    return true
end

function ClearClaim(netId, unlock)
    State.choppingNow[netId] = nil
    State.claimedVehicles[netId] = nil
    State.requiredPartsByVehicle[netId] = nil
    State.damagedPartsByVehicle[netId] = nil
    State.motorcycleByVehicle[netId] = nil
    State.choppedPartsByVehicle[netId] = nil
    State.rewardedPartsByVehicle[netId] = nil
    State.sellingVehicles[netId] = nil

    if not unlock then return end
    local veh = GetVehicleForNetId(netId)
    if veh == 0 then return end
    SetVehicleUndriveable(veh, false)
    SetVehicleDoorsLocked(veh, 0)
    SetVehicleHandbrake(veh, false)
end

function GiveInternalReward(src, netId, partName)
    local cfg = Config.Reward and Config.Reward.perPart
    if not cfg or not cfg.enabled or not INTERNAL_PARTS[partName] then return end

    State.rewardedPartsByVehicle[netId] = State.rewardedPartsByVehicle[netId] or {}
    if State.rewardedPartsByVehicle[netId][partName] then return end

    local pool = cfg.pool
    if type(pool) ~= 'table' or #pool == 0 then return end
    if not Inventory.AddItem then return end

    local item = pool[math.random(1, #pool)]
    local minQty = math.max(1, tonumber(cfg.amountMin) or 15)
    local maxQty = math.max(minQty, tonumber(cfg.amountMax) or 23)
    local amount = math.random(minQty, maxQty)

    local success = Inventory.AddItem(src, item, amount)
    local itemLabel = (QBCore.Shared.Items[item] and QBCore.Shared.Items[item].label) or item

    if not success then
        Notify(src, ('Inventory full — could not add %dx %s'):format(amount, itemLabel), 'error')
        return
    end

    State.rewardedPartsByVehicle[netId][partName] = true
    Notify(src, ('+ %s x%d'):format(itemLabel, amount), 'success')
end

function MinChopMs(part)
    local ms = tonumber(part.chopTime) or tonumber(Config.ChopTime) or 1000
    return math.max(250, math.floor(ms * 0.55))
end