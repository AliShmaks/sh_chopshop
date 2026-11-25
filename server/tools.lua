-- tools.lua

local dropIdCounterServer = 0
local MAIN_TOOL_RESPAWN_MS = 15000
local MAX_DROPPED_TOOLS = 8
-- =========================================================
-- TOOLS (impact driver + angle grinder) — shared floor pickups
-- =========================================================
lib.callback.register('sh_chopshop:getMainToolsState', function()
    local out = { drill = {}, grinder = {} }
    for kind, list in pairs(TOOL_LISTS) do
        for i = 1, #list do
            out[kind][i] = { index = i, taken = State.mainToolState[kind][i] == true }
        end
    end
    return out
end)

lib.callback.register('sh_chopshop:getSharedDroppedTools', function()
    local list = {}
    for id, data in pairs(State.droppedToolsServer) do
        list[#list + 1] = { id = id, kind = data.kind, x = data.coords.x, y = data.coords.y, z = data.coords.z }
    end
    return list
end)

lib.callback.register('sh_chopshop:takeMainTool', function(source, kind, index)
    if not IsValidToolKind(kind) then return false end
    index = tonumber(index)
    local list = TOOL_LISTS[kind]
    if not index or not list[index] then return false end
    if not IsNearChopShop(source, Config.ChopShop.radius + 20.0) then return false end
    if State.playerTool[source] then return false end
    if State.mainToolState[kind][index] then return false end

    local spot = list[index]
    if not IsNearCoords(source, vector3(spot.coords.x, spot.coords.y, spot.coords.z), 4.0) then
        return false
    end

    State.mainToolState[kind][index] = true
    State.playerTool[source] = kind
    State.playerToolSlot[source] = { kind = kind, index = index }
    TriggerNearby('sh_chopshop:client:removeMainTool', Config.ChopShop.coords, BROADCAST_RANGE, kind, index)

    -- Respawn timer with a token: if the slot is freed early (player leaves holding the tool),
    -- the token changes and this timer does nothing, so the tool is never spawned twice.
    local key = kind .. ':' .. index
    local token = (State.mainToolToken[key] or 0) + 1
    State.mainToolToken[key] = token
    SetTimeout(MAIN_TOOL_RESPAWN_MS, function()
        if State.mainToolToken[key] ~= token then return end
        State.mainToolState[kind][index] = false
        TriggerNearby('sh_chopshop:client:spawnMainToolNetworked', Config.ChopShop.coords, BROADCAST_RANGE, kind, index)
    end)

    return true
end)

lib.callback.register('sh_chopshop:dropTool', function(source, coords)
    local kind = State.playerTool[source]
    if not kind then return false end
    if type(coords) ~= 'table' or not coords.x then return false end
    if not IsNearChopShop(source, Config.ChopShop.radius + 20.0) then return false end
    if (State.lastDrop[source] or 0) + 800 > GetGameTimer() then return false end

    -- 🆕 validate drop coords against player's real position
    local ped = GetPlayerPed(source)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    local dropCoords = vector3(coords.x, coords.y, coords.z)
    if #(GetEntityCoords(ped) - dropCoords) > 3.0 then return false end

    if CountDroppedTools() >= MAX_DROPPED_TOOLS then
        Notify(source, 'Too many tools on the floor. Pick one up first.', 'error')
        return false
    end

    State.lastDrop[source] = GetGameTimer()
    State.playerTool[source] = nil
    State.playerToolSlot[source] = nil
    dropIdCounterServer = dropIdCounterServer + 1
    local id = dropIdCounterServer
    local pos = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    State.droppedToolsServer[id] = { coords = pos, kind = kind, t = GetGameTimer() }
    TriggerNearby('sh_chopshop:client:spawnSharedTool', pos, BROADCAST_RANGE, id, pos, kind)
    return true, id
end)

lib.callback.register('sh_chopshop:consumeDroppedTool', function(source, dropId)
    dropId = tonumber(dropId)
    if not dropId then return false end
    if State.playerTool[source] then return false end
    if not IsNearChopShop(source, Config.ChopShop.radius + 20.0) then return false end

    local data = State.droppedToolsServer[dropId]
    if not data then return false end

    local dropPos = vector3(data.coords.x, data.coords.y, data.coords.z)
    if not IsNearCoords(source, dropPos, 5.0) then return false end

    State.droppedToolsServer[dropId] = nil
    State.playerTool[source] = data.kind
    State.playerToolSlot[source] = nil   -- picked up from the floor drop, not from a main spot
    TriggerNearby('sh_chopshop:client:removeSharedTool', dropPos, BROADCAST_RANGE, dropId)
    return true, data.kind
end)

-- Dropped tools stay on the floor (for anyone to pick up) for DROPPED_TOOL_TTL_MS, then are removed.
local DROPPED_TOOL_TTL_MS = 120000
CreateThread(function()
    while true do
        Wait(10000)
        local now = GetGameTimer()
        for dropId, data in pairs(State.droppedToolsServer) do
            if (now - (data.t or 0)) >= DROPPED_TOOL_TTL_MS then
                State.droppedToolsServer[dropId] = nil
                TriggerNearby('sh_chopshop:client:removeSharedTool', data.coords, BROADCAST_RANGE, dropId)
            end
        end
    end
end)

-- =========================================================
-- REMOTE TOOL VISIBILITY — broadcast held tool to nearby players
-- =========================================================
RegisterNetEvent('sh_chopshop:server:startHoldingTool', function(kind)
    local src = source
    kind = tostring(kind or '')
    if not IsValidToolKind(kind) then return end
    if State.playerTool[src] ~= kind then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    TriggerNearby('sh_chopshop:client:showHeldTool', GetEntityCoords(ped), BROADCAST_RANGE, tonumber(src), kind)
end)

RegisterNetEvent('sh_chopshop:server:stopHoldingTool', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    TriggerNearby('sh_chopshop:client:hideHeldTool', GetEntityCoords(ped), BROADCAST_RANGE, tonumber(src))
end)
-- 🆕 return held tool to floor immediately (called when player leaves zone)
RegisterNetEvent('sh_chopshop:server:returnHeldTool', function()
    local src = source
    local kind = State.playerTool[src]
    if not kind then return end
    State.playerTool[src] = nil
    local slot = State.playerToolSlot[src]
    State.playerToolSlot[src] = nil

    -- Only free the exact floor spot this player took, and only if it has not respawned yet.
    -- (If it already respawned, the tool in hand was an extra one and simply disappears.)
    if slot and slot.kind == kind and State.mainToolState[kind][slot.index] then
        local key = kind .. ':' .. slot.index
        State.mainToolToken[key] = (State.mainToolToken[key] or 0) + 1   -- cancels the pending respawn timer
        State.mainToolState[kind][slot.index] = false
        TriggerNearby('sh_chopshop:client:spawnMainToolNetworked', Config.ChopShop.coords, BROADCAST_RANGE, kind, slot.index)
    end
end)
