-- parts.lua

local INTERNAL_ORDER = { 'battery', 'radiator', 'exhaust', 'gearbox' }
-- ---------------------------------------------------------
-- Which parts does THIS car actually have?
-- (2-door cars have no rear doors, some cars have no trunk, etc.)
-- ---------------------------------------------------------
function IsMotorcycle(veh)
    return DoesEntityExist(veh) and IsThisModelABike(GetEntityModel(veh))
end

local function IsOptionalMotorcyclePart(veh, partName)
    if not IsMotorcycle(veh) then return false end

    -- Global opt-out: Config.MotorcycleOptionalParts = { radiator = true, gearbox = true }
    if Config.MotorcycleOptionalParts and Config.MotorcycleOptionalParts[partName] == true then
        return true
    end

    -- Optional model-specific overrides (key by model hash or display name):
    -- Config.MotorcyclePartsByModel = { [joaat('bati')] = { radiator = false } }
    local modelHash = GetEntityModel(veh)
    local modelName = GetDisplayNameFromVehicleModel(modelHash)
    local byModel = Config.MotorcyclePartsByModel
    local modelConfig = byModel and (byModel[modelHash] or byModel[tostring(modelHash)] or byModel[modelName] or byModel[modelName:lower()])
    if modelConfig and modelConfig[partName] == false then return true end
    return false
end

function GetEffectivePartBone(veh, part)
    if not IsMotorcycle(veh) or part.wheelIndex == nil then return part.bone end
    local key = ((part.name or '') .. ' ' .. (part.bone or '') .. ' ' .. (part.label or '')):lower()
    if key:find('wheel_lf', 1, true) or key:find('wheel_rf', 1, true)
        or key:find('front_left', 1, true) or key:find('front_right', 1, true)
        or key:find('frontleft', 1, true) or key:find('frontright', 1, true)
        or key:find('front', 1, true) then
        return 'wheel_f'
    end
    if key:find('wheel_lr', 1, true) or key:find('wheel_rr', 1, true)
        or key:find('rear_left', 1, true) or key:find('rear_right', 1, true)
        or key:find('rearleft', 1, true) or key:find('rearright', 1, true)
        or key:find('rear', 1, true) then
        return 'wheel_r'
    end
    return part.bone
end

local function IsMotorcycleWheelRepresentative(veh, part)
    if not IsMotorcycle(veh) or part.wheelIndex == nil then return true end
    local key = ((part.name or '') .. ' ' .. (part.bone or '') .. ' ' .. (part.label or '')):lower()
    -- Keep one configured entry for each physical bike wheel (front=LF, rear=LR).
    if key:find('wheel_lf', 1, true) or key:find('front_left', 1, true) or key:find('frontleft', 1, true) then return true end
    if key:find('wheel_rf', 1, true) or key:find('front_right', 1, true) or key:find('frontright', 1, true) then return false end
    if key:find('wheel_lr', 1, true) or key:find('rear_left', 1, true) or key:find('rearleft', 1, true) then return true end
    if key:find('wheel_rr', 1, true) or key:find('rear_right', 1, true) or key:find('rearright', 1, true) then return false end
    if key:find('front', 1, true) then return true end
    if key:find('rear', 1, true) then return true end
    return false
end

function GetEffectiveWheelIndex(veh, part)
    if IsMotorcycle(veh) and part.wheelIndex ~= nil then
        local bone = GetEffectivePartBone(veh, part) or ''
        if bone == 'wheel_f' then return 0 end
        if bone == 'wheel_r' then return 1 end
    end
    return part.wheelIndex
end

local function PartExistsOnVehicle(veh, part)
    if part.internal then
        return not IsOptionalMotorcyclePart(veh, part.name)
    end

    if not IsMotorcycleWheelRepresentative(veh, part) then return false end
    local bone = GetEffectivePartBone(veh, part)
    -- The model must actually contain the configured bone (or the bike wheel equivalent).
    if not bone or GetEntityBoneIndexByName(veh, bone) == -1 then return false end

    -- Doors, hood and trunk must also be valid door indexes.
    if part.doorIndex ~= nil and not GetIsDoorValid(veh, part.doorIndex) then
        return false
    end

    return true
end

function ComputeAvailableParts(veh)
    local avail = {}
    for _, part in ipairs(Config.VehicleParts) do
        if PartExistsOnVehicle(veh, part) then
            avail[part.name] = true
        end
    end
    return avail
end

function ComputeDamagedParts(veh, avail)
    local damaged = {}
    for _, part in ipairs(Config.VehicleParts) do
        if avail[part.name] then
            -- Broken-off doors/hood/trunk are counted as damaged and are not required to be chopped again.
            if part.doorIndex ~= nil and IsVehicleDoorDamaged(veh, part.doorIndex) then
                damaged[part.name] = true
            -- A fully burst tyre is treated as a pre-damaged wheel for the sale penalty.
            elseif part.wheelIndex ~= nil and IsVehicleTyreBurst(veh, GetEffectiveWheelIndex(veh, part), true) then
                damaged[part.name] = true
            end
        end
    end
    return damaged
end

function IsPartAvailable(veh, partName)
    local a = State.availableParts[veh]
    if not a then return true end -- not computed yet, don't block
    return a[partName] == true
end

function AreDoorsDone(vehicle)
    if IsMotorcycle(vehicle) then return true end
    local cp = State.choppedParts[vehicle] or {}
    for _, part in ipairs(Config.VehicleParts) do
        if part.doorIndex and IsPartAvailable(vehicle, part.name) and not cp[part.name] then
            return false
        end
    end
    return true
end

function AreWheelsDone(vehicle)
    local cp = State.choppedParts[vehicle] or {}
    for _, part in ipairs(Config.VehicleParts) do
        if part.wheelIndex and IsPartAvailable(vehicle, part.name) and not cp[part.name] then
            return false
        end
    end
    return true
end

function CanChopInternal(vehicle, partName)
    local idx
    for i, name in ipairs(INTERNAL_ORDER) do
        if name == partName then idx = i break end
    end
    if not idx then return true end
    for i = 1, idx - 1 do
        local previous = INTERNAL_ORDER[i]
        if IsPartAvailable(vehicle, previous) and (not State.choppedParts[vehicle] or not State.choppedParts[vehicle][previous]) then
            return false, previous
        end
    end
    return true
end

function IsFullyChopped(vehicle)
    local cp = State.choppedParts[vehicle]
    if not cp then return false end
    for _, part in ipairs(Config.VehicleParts) do
        if IsPartAvailable(vehicle, part.name) and not cp[part.name] then
            return false
        end
    end
    return true
end

-- ---------------------------------------------------------
-- Reach: how close the player must be to THIS part (not just to the car)
-- ---------------------------------------------------------
function GetPartReach(part)
    local r = Config.ChopReach or {}
    local v = r[part.name]
    if not v then
        if part.wheelIndex ~= nil then v = r.wheel
        elseif part.internal then v = r.internal end
    end
    return tonumber(v or r.default) or 1.5
end

-- aimCoords (optional) = where the player is looking on the car (ox_target passes it to canInteract)
function IsNearPart(veh, part, aimCoords)
    local boneName = GetEffectivePartBone(veh, part)
    local idx = boneName and GetEntityBoneIndexByName(veh, boneName) or -1
    if idx == -1 then return true end
    local bonePos = GetWorldPositionOfEntityBone(veh, idx)
    local reach = GetPartReach(part)
    if #(GetEntityCoords(PlayerPedId()) - bonePos) > reach then return false end

    local aimRadius = (Config.ChopReach or {}).aimRadius
    if aimCoords and aimRadius and not part.internal then
        local aim = math.max(tonumber(aimRadius) or 1.2, reach * 0.8)
        if #(vector3(aimCoords.x, aimCoords.y, aimCoords.z) - bonePos) > aim then return false end
    end
    return true
end

-- Prop model for a part: sport vehicles use part.propSport when the part defines one.
function GetPartProp(veh, part)
    if part.propSport and veh and DoesEntityExist(veh) then
        local sport = Config.SportClasses
        if sport and sport[GetVehicleClass(veh)] == true then
            return part.propSport
        end
    end
    return part.prop
end
