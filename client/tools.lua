-- tools.lua

local sharedTools = {}        -- [dropId] = { obj, kind }
local mainTools = { drill = {}, grinder = {} }   -- [kind][index] = { obj }
local dropToolBusy = false
-- =========================================================
-- TOOLS: impact driver (wheels) + angle grinder (doors/hood/trunk)
-- pick up from the floor -> hold in hand -> X to drop -> shared with everyone
-- =========================================================
local holdAnim, holdAnimTried = nil, false

local function ToolCfg(kind)
    return Config.Tools and Config.Tools[kind]
end

function LoadFirstAnim(list)
    for _, a in ipairs(list or {}) do
        RequestAnimDict(a.dict)
        local t = GetGameTimer() + 1500
        while not HasAnimDictLoaded(a.dict) and GetGameTimer() < t do Wait(0) end
        if HasAnimDictLoaded(a.dict) then return a end
    end
    return nil
end

local function GetHoldAnim()
    if holdAnim then return holdAnim end
    if holdAnimTried then return nil end
    holdAnimTried = true
    holdAnim = LoadFirstAnim(Config.ToolHold and Config.ToolHold.anims)
    return holdAnim
end

-- Keeps the "holding a power tool" pose on the upper body while you walk around.
function ApplyHoldAnim()
    if not State.heldTool or State.heldPart or State.isChopping then return end
    if State.heldTool == 'drill' then return end   -- drill = normal hand hold (old behavior), only grinder gets the pose
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, true) or IsEntityDead(ped) or IsPedRagdoll(ped) then return end
    local a = GetHoldAnim()
    if not a then return end
    if not HasAnimDictLoaded(a.dict) then
        RequestAnimDict(a.dict)
        local t = GetGameTimer() + 800
        while not HasAnimDictLoaded(a.dict) and GetGameTimer() < t do Wait(0) end
        if not HasAnimDictLoaded(a.dict) then return end
    end
    if not IsEntityPlayingAnim(ped, a.dict, a.clip, 3) then
        TaskPlayAnim(ped, a.dict, a.clip, 4.0, -4.0, -1, 49, 0.0, false, false, false)
    end
end     

local function StopHoldAnim()
    if holdAnim then
        StopAnimTask(PlayerPedId(), holdAnim.dict, holdAnim.clip, 2.0)
    end
end

function AttachToolToHand(kind, ped)
    if State.heldToolProp and DoesEntityExist(State.heldToolProp) then return end
    local cfg = ToolCfg(kind)
    if not cfg then return end
    local model = joaat(cfg.prop)
    RequestModel(model)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) then return end

    State.heldToolProp = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    AttachEntityToEntity(
        State.heldToolProp, ped, GetPedBoneIndex(ped, cfg.bone or 28422),
        cfg.offset.x, cfg.offset.y, cfg.offset.z,
        cfg.rot.x, cfg.rot.y, cfg.rot.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
end

local function RemoveToolFromHand()
    if State.heldToolProp and DoesEntityExist(State.heldToolProp) then
        DetachEntity(State.heldToolProp, true, true)
        DeleteEntity(State.heldToolProp)
    end
    State.heldToolProp = nil
end

local function PickupToolWithAnim(kind, sourceObj)
    local ped = PlayerPedId()
    if sourceObj and DoesEntityExist(sourceObj) then
        FreezeEntityPosition(sourceObj, true)
    end

    local dict, clip = 'pickup_object', 'pickup_low'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 1600, 0, 0.0, false, false, false)
        Wait(900)
    else
        Wait(600)
    end
    State.heldTool = kind
    AttachToolToHand(kind, ped)
    TriggerServerEvent('sh_chopshop:server:startHoldingTool', kind)   -- 👈 ADD
    PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    ClearPedTasks(ped)
    ApplyHoldAnim()
    State._menuDirty = true

    if sourceObj and DoesEntityExist(sourceObj) then
        pcall(function() exports.ox_target:removeLocalEntity(sourceObj) end)
        DeleteEntity(sourceObj)
    end
end

local function TryTakeMainTool(kind, index, obj)
    if State.heldTool then
        local cfg = ToolCfg(State.heldTool)
        Notify(('Drop your %s first (X).'):format(cfg and cfg.label or 'tool'), 'error')
        return
    end
    if not obj or not DoesEntityExist(obj) then return end
    local granted = lib.callback.await('sh_chopshop:takeMainTool', false, kind, index)
    if not granted then
        Notify('That tool is already taken.', 'error')
        return
    end
    PickupToolWithAnim(kind, obj)
    mainTools[kind][index] = nil
    if kind == 'grinder' then
        Notify('Grinder picked up — you can now chop doors, hood and trunk!', 'success')
    else
        Notify('Impact driver picked up — you can now remove wheels!', 'success')
    end
end

local function SpawnMainTool(kind, index)
    mainTools[kind] = mainTools[kind] or {}
    local existing = mainTools[kind][index]
    if existing and DoesEntityExist(existing.obj) then return end

    local list = (kind == 'grinder') and Config.GrinderPickups or Config.ToolPickups
    local spot = list and list[index]
    if not spot then return end

    local propHash = joaat(spot.prop)
    RequestModel(propHash)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(propHash) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(propHash) then return end

    local obj = CreateObject(propHash, spot.coords.x, spot.coords.y, spot.coords.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    SetEntityRotation(obj, 0.0, 0.0, 45.0, 2, true)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(propHash)

    mainTools[kind][index] = { obj = obj }

    exports.ox_target:addLocalEntity(obj, {
        {
            name = ('chopshop_pickup_main_%s_%d'):format(kind, index),
            icon = spot.icon or 'fas fa-screwdriver-wrench',
            label = spot.label or 'Pick up Tool',
            distance = Config.PickupDistance or 1.5,
            canInteract = function()
                if not DoesEntityExist(obj) then return false end
                if not State.openedVehicle or not DoesEntityExist(State.openedVehicle) then return false end
                if kind == 'drill' then
                    -- wheels come after all body panels are off
                    if State.heldTool == 'drill' or State.wheelsDoneLock then return false end
                    return AreDoorsDone(State.openedVehicle)
                else
                    if State.heldTool == 'grinder' then return false end
                    return not AreDoorsDone(State.openedVehicle)
                end
            end,
            onSelect = function()
                if kind == 'drill' and State.wheelsDoneLock then return end
                TryTakeMainTool(kind, index, obj)
            end
        }
    })
end

RegisterNetEvent('sh_chopshop:client:removeMainTool', function(kind, index)
    local data = mainTools[kind] and mainTools[kind][index]
    if not data then return end
    if data.obj and DoesEntityExist(data.obj) then
        pcall(function() exports.ox_target:removeLocalEntity(data.obj) end)
        DeleteEntity(data.obj)
    end
    mainTools[kind][index] = nil
end)

RegisterNetEvent('sh_chopshop:client:spawnMainToolNetworked', function(kind, index)
    SpawnMainTool(kind, index)
end)

local function SpawnSharedToolInner(dropId, coords, kind)
    if not coords then return end
    kind = (kind == 'grinder') and 'grinder' or 'drill'
    if type(coords) == 'table' and coords.x then
        coords = vector3(coords.x, coords.y, coords.z)
    end
    local old = sharedTools[dropId]
    if old and DoesEntityExist(old.obj) then return end

    local cfg = ToolCfg(kind)
    if not cfg then return end
    local hash = joaat(cfg.prop)
    RequestModel(hash)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(hash) then return end

    local obj = CreateObject(hash, coords.x, coords.y, coords.z + 0.5, false, false, false)
    if not DoesEntityExist(obj) then return end

    CreateThread(function()
        Wait(200)
        if not DoesEntityExist(obj) then return end
        PlaceObjectOnGroundProperly(obj)
        Wait(100)
        if not DoesEntityExist(obj) then return end
        PlaceObjectOnGroundProperly(obj)
        SetEntityRotation(obj, 0.0, 0.0, 45.0, 2, true)
        FreezeEntityPosition(obj, true)
    end)

    SetModelAsNoLongerNeeded(hash)
    sharedTools[dropId] = { obj = obj, kind = kind }

    exports.ox_target:addSphereZone({
        name = 'chopshop_shared_zone_' .. dropId,
        coords = vector3(coords.x, coords.y, coords.z),
        radius = 1.4,
        debug = false,
        drawSprite = false,
        options = {
            {
                name = 'chopshop_shared_opt_' .. dropId,
                icon = (kind == 'grinder') and 'fas fa-bolt' or 'fas fa-screwdriver-wrench',
                label = (kind == 'grinder') and 'Pick up Grinder' or 'Pick up Drill',
                distance = Config.PickupDistance or 1.5,
                canInteract = function()
                    if State.heldTool then return false end
                    local e = sharedTools[dropId]
                    return e and DoesEntityExist(e.obj)
                end,
                onSelect = function()
                    if State.heldTool then return end
                    local e = sharedTools[dropId]
                    if not e or not DoesEntityExist(e.obj) then return end
                    local granted, gotKind = lib.callback.await('sh_chopshop:consumeDroppedTool', false, dropId)
                    if not granted then
                        Notify('Someone else grabbed that tool.', 'error')
                        return
                    end
                    PickupToolWithAnim(gotKind or e.kind, e.obj)
                    sharedTools[dropId] = nil
                    Notify('Tool picked up.', 'success')
                end
            }
        }
    })
end

-- Guard: a broadcast and the periodic sync can ask for the same drop at the same moment.
local sharedSpawning = {}
RegisterNetEvent('sh_chopshop:client:spawnSharedTool', function(dropId, coords, kind)
    if sharedSpawning[dropId] then return end
    sharedSpawning[dropId] = true
    pcall(SpawnSharedToolInner, dropId, coords, kind)
    sharedSpawning[dropId] = nil
end)

RegisterNetEvent('sh_chopshop:client:removeSharedTool', function(dropId)
    local e = sharedTools[dropId]
    if e and e.obj and DoesEntityExist(e.obj) then DeleteEntity(e.obj) end
    sharedTools[dropId] = nil
    pcall(function()
        exports.ox_target:removeZone('chopshop_shared_zone_' .. dropId)
    end)
end)

local function DropToolInstant()
    if dropToolBusy or not State.heldTool then return end
    dropToolBusy = true

    local kind = State.heldTool
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local dropPos = vector3(pedCoords.x + fwd.x * 0.45, pedCoords.y + fwd.y * 0.45, pedCoords.z + 0.05)

    RemoveToolFromHand()
    State.heldTool = nil
    StopHoldAnim()
    Wait(0)

    local ok = lib.callback.await('sh_chopshop:dropTool', false, { x = dropPos.x, y = dropPos.y, z = dropPos.z })
     if not ok then
        State.heldTool = kind
        AttachToolToHand(kind, PlayerPedId())
        Notify('Could not drop the tool here.', 'error')
    else
        TriggerServerEvent('sh_chopshop:server:stopHoldingTool')   -- 👈 ADD
        local cfg = ToolCfg(kind)
        Notify(((cfg and cfg.label) or 'Tool') .. ' dropped.', 'inform')
        State._menuDirty = true
    end

    SetTimeout(200, function() dropToolBusy = false end)
end

function CleanupAllTools()
    for _, list in pairs(mainTools) do
        for _, data in pairs(list) do
            if data.obj and DoesEntityExist(data.obj) then
                pcall(function() exports.ox_target:removeLocalEntity(data.obj) end)
                DeleteEntity(data.obj)
            end
        end
    end
    mainTools = { drill = {}, grinder = {} }
    for dropId, e in pairs(sharedTools) do
        if e.obj and DoesEntityExist(e.obj) then DeleteEntity(e.obj) end
        pcall(function() exports.ox_target:removeZone('chopshop_shared_zone_' .. dropId) end)
    end
    sharedTools = {}
    RemoveToolFromHand()
    State.heldTool = nil
end

CreateThread(function()
    Wait(2500)
    local state = lib.callback.await('sh_chopshop:getMainToolsState', false)
    for _, kind in ipairs({ 'drill', 'grinder' }) do
        local list = (kind == 'grinder') and Config.GrinderPickups or Config.ToolPickups
        local kindState = state and state[kind]
        if kindState and #kindState > 0 then
            for _, item in ipairs(kindState) do
                if not item.taken then SpawnMainTool(kind, item.index) end
            end
        elseif list then
            for i = 1, #list do SpawnMainTool(kind, i) end
        end
    end
end)

CreateThread(function()
    Wait(3000)
    local list = lib.callback.await('sh_chopshop:getSharedDroppedTools', false)
    if not list then return end
    for _, item in ipairs(list) do
        TriggerEvent('sh_chopshop:client:spawnSharedTool', item.id, vector3(item.x, item.y, item.z), item.kind)
    end
end)

-- Keep dropped tools in sync with the server while inside the chop zone.
-- Covers players who were out of broadcast range when a tool was dropped or picked up,
-- so every player in the shop can always see (and pick up) tools dropped by others.
CreateThread(function()
    Wait(5000)
    while true do
        if IsInChopShopZone() then
            local list = lib.callback.await('sh_chopshop:getSharedDroppedTools', false)
            if list then
                local present = {}
                for _, item in ipairs(list) do
                    present[item.id] = true
                    local e = sharedTools[item.id]
                    if not e or not DoesEntityExist(e.obj) then
                        TriggerEvent('sh_chopshop:client:spawnSharedTool', item.id, vector3(item.x, item.y, item.z), item.kind)
                    end
                end
                local stale = {}
                for dropId in pairs(sharedTools) do
                    if not present[dropId] then stale[#stale + 1] = dropId end
                end
                for _, dropId in ipairs(stale) do
                    TriggerEvent('sh_chopshop:client:removeSharedTool', dropId)
                end
            end
            Wait(5000)
        else
            Wait(3000)
        end
    end
end)

-- X = drop the tool (not while a chop is running, X cancels the chop then)
CreateThread(function()
    while true do
        if State.heldTool then
            DisableControlAction(0, 73, true)
            if IsDisabledControlJustPressed(0, 73) and not State.isChopping then DropToolInstant() end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- 🆕 Auto-return tool if player leaves the chop zone (disappear from hand)
CreateThread(function()
    while true do
        Wait(1000)
        if State.heldTool and not IsInChopShopZone() then
            RemoveToolFromHand()
            State.heldTool = nil
            StopHoldAnim()
            TriggerServerEvent('sh_chopshop:server:returnHeldTool')       -- 👈 NEW LINE
            TriggerServerEvent('sh_chopshop:server:stopHoldingTool')
            SendNUIMessage({ action = 'stopAll' })
            Notify('You left the chop shop — your tool was returned.', 'inform')
        end
    end
end)

-- =========================================================
-- REMOTE TOOL VISIBILITY — see other players holding tools
-- =========================================================

local function AttachRemoteTool(serverId, kind)
    local cfg = ToolCfg(kind)
    if not cfg then return end
    local playerId = GetPlayerFromServerId(serverId)
    if playerId == -1 then return end
    local ped = GetPlayerPed(playerId)
    if ped == 0 or not DoesEntityExist(ped) then return end

    if State.remoteTools[serverId] and DoesEntityExist(State.remoteTools[serverId].obj) then
        DeleteEntity(State.remoteTools[serverId].obj)
    end

    local model = joaat(cfg.prop)
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) then return end

    local obj = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    if not DoesEntityExist(obj) then return end

    AttachEntityToEntity(
        obj, ped, GetPedBoneIndex(ped, cfg.bone or 28422),
        cfg.offset.x, cfg.offset.y, cfg.offset.z,
        cfg.rot.x, cfg.rot.y, cfg.rot.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
    State.remoteTools[serverId] = { obj = obj, kind = kind }
end

RegisterNetEvent('sh_chopshop:client:showHeldTool', function(serverId, kind)
    if not serverId or not kind then return end
    if serverId == GetPlayerServerId(PlayerId()) then return end
    Wait(100)
    AttachRemoteTool(serverId, kind)
end)

RegisterNetEvent('sh_chopshop:client:hideHeldTool', function(serverId)
    if not serverId then return end
    local entry = State.remoteTools[serverId]
    if entry and entry.obj and DoesEntityExist(entry.obj) then
        DeleteEntity(entry.obj)
    end
    State.remoteTools[serverId] = nil
end)
