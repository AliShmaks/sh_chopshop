-- state.lua  (load FIRST)
-- Shared mutable state used by more than one file.
State = {
    claimedVehicles = {},  -- [netId] = { src, last }
    requiredPartsByVehicle = {},  -- [netId] = { [partName] = true }  parts that exist on this car
    damagedPartsByVehicle = {},  -- [netId] = { [partName] = true }  pre-damaged parts for sale penalties
    motorcycleByVehicle = {},  -- [netId] = true for motorcycle chop order
    choppedPartsByVehicle = {},
    rewardedPartsByVehicle = {},
    sellingVehicles = {},
    choppingNow = {},  -- [netId] = { src, part, started }
    droppedToolsServer = {},  -- [dropId] = { coords, kind }
    mainToolState = { drill = {}, grinder = {} },  -- [kind][index] = taken?
    playerTool = {},  -- [src] = 'drill' | 'grinder'
    playerToolSlot = {},  -- [src] = { kind, index } floor spot the held tool was taken from (nil if picked up from a drop)
    mainToolToken = {},   -- ['kind:index'] = counter, invalidates a pending respawn timer
    lastDrop = {},
    activeWheelSounds = {},
    activeGrinderSounds = {},
    chopCooldown = {},        -- [identifier] = os.time() when the player may chop again
    plateCallbackLast = {},   -- [src] = GetGameTimer() of last isPlayerVehicle callback
}

-- Shared constants / lookups (globals)
QBCore = exports['qb-core']:GetCoreObject()
Inventory = _G.Inventory or {}
VALID_PARTS = {}
BROADCAST_RANGE = 90.0
