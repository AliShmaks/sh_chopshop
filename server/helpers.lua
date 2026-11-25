-- helpers.lua

local _plateCache = {}
local PLATE_CACHE_MS = 30000
local PLATE_CACHE_MAX = 500
local _plateCacheCount = 0
local JOB_AREA_RANGE = 80.0
function IsValidToolKind(kind)
    return kind == 'drill' or kind == 'grinder'
end

function CountDroppedTools()
    local n = 0
    for _ in pairs(State.droppedToolsServer) do n = n + 1 end
    return n
end

-- =========================================================
-- HELPERS
-- =========================================================
function Notify(src, description, kind, duration)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Chop Shop',
        description = description,
        type = kind or 'error',
        duration = duration or 5000
    })
end

function TouchClaim(netId)
    local claim = State.claimedVehicles[netId]
    if claim then claim.last = GetGameTimer() end
end

function GetVehicleForNetId(netId)
    if not netId or netId == 0 then return 0 end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return 0 end
    return veh
end

function ForEachNearby(coords, range, fn)
    coords = coords or Config.ChopShop.coords
    range = range or BROADCAST_RANGE
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 then
            if #(GetEntityCoords(ped) - coords) <= range then
                fn(tonumber(id))
            end
        end
    end
end

function TriggerNearby(eventName, coords, range, ...)
    local payload = { ... }
    ForEachNearby(coords, range, function(playerId)
        TriggerClientEvent(eventName, playerId, table.unpack(payload))
    end)
end

function IsNearCoords(src, target, maxDistance)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    return #(GetEntityCoords(ped) - target) <= maxDistance
end

function IsNearChopShop(src, maxDistance)
    return IsNearCoords(src, Config.ChopShop.coords, maxDistance or (Config.ChopShop.radius + 4.0))
end

-- 🆕 vehicle-distance helper
function IsNearVehicle(src, veh, maxDistance)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    return IsNearCoords(src, GetEntityCoords(veh), maxDistance or 6.0)
end

function IsNearSaleNPC(src, maxDistance)
    local npc = vector3(Config.SellNPC.coords.x, Config.SellNPC.coords.y, Config.SellNPC.coords.z)
    return IsNearCoords(src, npc, maxDistance or 7.0)
end

function IsInJobArea(src)
    if IsNearChopShop(src, JOB_AREA_RANGE) then return true end
    return IsNearSaleNPC(src, 25.0)
end

local function NormalizePlate(plate)
    if not plate or plate == '' then return nil end
    return tostring(plate):gsub('%s+', ''):upper()
end

function LookupPlayerPlate(plate)
    plate = NormalizePlate(plate)
    if not plate then return false end

    local cached = _plateCache[plate]
    if cached and (GetGameTimer() - cached.t) < PLATE_CACHE_MS then
        return cached.v
    end

    -- keep the cache bounded: drop expired entries first, wipe it if it is still too big
    if _plateCacheCount >= PLATE_CACHE_MAX then
        local now = GetGameTimer()
        for k, v in pairs(_plateCache) do
            if (now - v.t) >= PLATE_CACHE_MS then
                _plateCache[k] = nil
                _plateCacheCount = _plateCacheCount - 1
            end
        end
        if _plateCacheCount >= PLATE_CACHE_MAX then
            _plateCache = {}
            _plateCacheCount = 0
        end
    end

    local row = MySQL.scalar.await(
        'SELECT 1 FROM player_vehicles WHERE UPPER(REPLACE(plate, " ", "")) = ? LIMIT 1',
        { plate }
    )
    local val = row ~= nil
    if not _plateCache[plate] then _plateCacheCount = _plateCacheCount + 1 end
    _plateCache[plate] = { v = val, t = GetGameTimer() }
    return val
end

-- =========================================================
-- CHOP COOLDOWN (per player, survives reconnects, resets on resource/server restart)
-- =========================================================
function GetCooldownKey(src)
    local player = QBCore.Functions.GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.citizenid then
        return 'cid:' .. player.PlayerData.citizenid
    end
    local license = GetPlayerIdentifierByType(src, 'license')
    return license and ('lic:' .. license) or ('src:' .. tostring(src))
end

function GetChopCooldownRemaining(src)
    local cfg = Config.ChopCooldown
    if not cfg or not cfg.enabled then return 0 end
    if cfg.bypassAce and IsPlayerAceAllowed(src, cfg.bypassAce) then return 0 end
    local untilAt = State.chopCooldown[GetCooldownKey(src)]
    if not untilAt then return 0 end
    return math.max(0, untilAt - os.time())
end

function StartChopCooldown(src)
    local cfg = Config.ChopCooldown
    if not cfg or not cfg.enabled then return end
    if cfg.bypassAce and IsPlayerAceAllowed(src, cfg.bypassAce) then return end
    State.chopCooldown[GetCooldownKey(src)] = os.time() + math.floor((tonumber(cfg.minutes) or 30) * 60)
end

function FormatCooldown(seconds)
    if seconds <= 60 then
        return ('%d second%s'):format(seconds, seconds == 1 and '' or 's')
    end
    local minutes = math.ceil(seconds / 60)
    return ('%d minutes'):format(minutes)
end

function IsPlayerOwnedVehicle(veh)
    return LookupPlayerPlate(GetVehicleNumberPlateText(veh))
end

local blacklistHashes = {}
for _, name in ipairs(Config.BlacklistedVehicles or {}) do
    if type(name) == 'string' then
        blacklistHashes[joaat(name)] = true
        blacklistHashes[joaat(name:lower())] = true
    end
end

function IsBlacklistedVehicle(veh)
    return blacklistHashes[GetEntityModel(veh)] == true
end

-- The server has no native for the vehicle class, so the client reports it.
-- The model blacklist above stays the authoritative check.
function IsBlacklistedClass(vehClass)
    vehClass = tonumber(vehClass)
    return vehClass ~= nil and Config.BlacklistedClasses ~= nil and Config.BlacklistedClasses[vehClass] == true
end
