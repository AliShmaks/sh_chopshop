-- helpers.lua

local _cachedNearVeh, _cachedNearVehTime = nil, 0
local blacklistHashes = {}
for _, name in ipairs(Config.BlacklistedVehicles or {}) do
    if type(name) == 'string' then
        blacklistHashes[joaat(name)] = true
        blacklistHashes[joaat(name:lower())] = true
    end
end

-- =========================================================
-- HELPERS
-- =========================================================
function Notify(msg, kind)
    lib.notify({ title = 'Chop Shop', description = msg, type = kind or 'inform' })
end

function IsInChopShopZone()
    return #(GetEntityCoords(PlayerPedId()) - Config.ChopShop.coords) <= Config.ChopShop.radius
end

function IsVehicleBlacklisted(vehicle)
    if blacklistHashes[GetEntityModel(vehicle)] == true then return true end
    local classes = Config.BlacklistedClasses
    return classes ~= nil and classes[GetVehicleClass(vehicle)] == true
end

function GetNearestVehicle(maxDist)
    local now = GetGameTimer()
    if now - _cachedNearVehTime < 400 and _cachedNearVeh and DoesEntityExist(_cachedNearVeh) then
        local d = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(_cachedNearVeh))
        if d <= (maxDist or 6.0) then return _cachedNearVeh end
    end

    local veh = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), maxDist or 6.0, false)
    _cachedNearVeh = veh
    _cachedNearVehTime = now
    return veh
end

function IsPlayerVehicle(veh)
    if not DoesEntityExist(veh) then return false end
    local cached = State._playerVehicleCache[veh]
    if cached and (GetGameTimer() - cached.t) < 15000 then return cached.v end

    local plate = GetVehicleNumberPlateText(veh)
    if not plate or plate == '' then return false end
    plate = plate:gsub('%s+', ''):upper()

    local result = lib.callback.await('sh_chopshop:isPlayerVehicle', false, plate) == true
    State._playerVehicleCache[veh] = { v = result, t = GetGameTimer() }
    return result
end

function EnsureNetworked(veh)
    if State._netIdCache[veh] and State._netIdCache[veh] ~= 0 then return State._netIdCache[veh] end
    if NetworkGetEntityIsNetworked(veh) then
        local n = VehToNet(veh)
        State._netIdCache[veh] = n
        return n
    end
    NetworkRegisterEntityAsNetworked(veh)
    local t = 0
    while not NetworkGetEntityIsNetworked(veh) and t < 40 do
        Wait(50)
        t = t + 1
    end
    local n = NetworkGetEntityIsNetworked(veh) and VehToNet(veh) or 0
    State._netIdCache[veh] = n
    return n
end

function LockVehicle(veh)
    if not DoesEntityExist(veh) then return end
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleUndriveable(veh, true)
    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleHandbrake(veh, true)
    SetVehicleOnGroundProperly(veh)
    SetEntityVelocity(veh, 0.0, 0.0, 0.0)
    SetEntityAngularVelocity(veh, 0.0, 0.0, 0.0)
    FreezeEntityPosition(veh, true)
end
function UnlockVehicle(veh)
    if not DoesEntityExist(veh) then return end
    FreezeEntityPosition(veh, false)
    SetVehicleHandbrake(veh, false)
    SetVehicleUndriveable(veh, false)
    SetVehicleDoorsLocked(veh, 0)
end

function CleanupVehicleDebris(veh)
    if State.vehicleDebris[veh] then
        for _, obj in ipairs(State.vehicleDebris[veh]) do
            if DoesEntityExist(obj) then DeleteEntity(obj) end
        end
        State.vehicleDebris[veh] = nil
    end
    if State.heldProps[veh] then
        for _, obj in ipairs(State.heldProps[veh]) do
            if DoesEntityExist(obj) then DeleteEntity(obj) end
        end
        State.heldProps[veh] = nil
    end
end

function ResetOpenedVehicle(unlock)
    if State.openedVehicle and DoesEntityExist(State.openedVehicle) then
        if unlock then UnlockVehicle(State.openedVehicle) end
        pcall(function() exports.ox_target:removeLocalEntity(State.openedVehicle) end)
    end
    if State.openedVehicle then
        State.availableParts[State.openedVehicle] = nil
        State.damagedParts[State.openedVehicle] = nil
        State.manualClosed[State.openedVehicle] = nil
    end
    State.openedVehicle = nil
    State.openedNetId = 0
    State.vehicleClaimedOnce = false
    State.gearboxDropped = false
    State.wheelsDoneLock = false
    State._menuDirty = true
end
