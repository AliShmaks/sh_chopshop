-- state.lua  (load FIRST)
-- Shared mutable state used by more than one file.
State = {
    sellPed = nil,
    openedVehicle = nil,
    openedNetId = 0,
    _menuDirty = true,
    _textUIShown = false,
    choppedParts = {},
    availableParts = {},  -- [veh] = { [partName] = true }  (parts that actually exist on this car)
    damagedParts = {},  -- [veh] = { [partName] = true }  parts already destroyed before chopping began
    isChopping = false,
    vehicleDebris = {},
    heldProps = {},
    heldPart = nil,
    gearboxDropped = false,
    vehicleClaimedOnce = false,
    heldTool = nil,  -- nil | 'drill' | 'grinder'
    heldToolProp = nil,
    wheelsDoneLock = false,
    manualClosed = {},  -- [veh] = { [partName] = true }  doors the player closed on purpose
    remoteTools = {},
    _netIdCache = {},
    _playerVehicleCache = {},
}
