-- cleanup.lua
-- =========================================================
-- CLEANUP / BLIPS
-- =========================================================
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if State._textUIShown then lib.hideTextUI() end
    SendNUIMessage({ action = 'stopAll' })
    -- 🆕 cleanup remote tool props
    for _, entry in pairs(State.remoteTools) do
        if entry.obj and DoesEntityExist(entry.obj) then DeleteEntity(entry.obj) end
    end
    State.remoteTools = {}
    if DoesEntityExist(State.sellPed) then DeleteEntity(State.sellPed) end
    if State.openedVehicle then
        ReleaseClaim(State.openedVehicle)
        UnlockVehicle(State.openedVehicle)
    end
    for veh in pairs(State.vehicleDebris) do CleanupVehicleDebris(veh) end
    if State.heldPart and DoesEntityExist(State.heldPart.obj) then DeleteEntity(State.heldPart.obj) end
    CleanupAllTools()
end)

CreateThread(function()
    local chopBlip = AddBlipForCoord(Config.ChopShop.coords.x, Config.ChopShop.coords.y, Config.ChopShop.coords.z)
    SetBlipSprite(chopBlip, 446)
    SetBlipColour(chopBlip, 1)
    SetBlipScale(chopBlip, 0.9)
    SetBlipAsShortRange(chopBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Chop Shop')
    EndTextCommandSetBlipName(chopBlip)

    local sellBlip = AddBlipForCoord(Config.SellNPC.coords.x, Config.SellNPC.coords.y, Config.SellNPC.coords.z)
    SetBlipSprite(sellBlip, 500)
    SetBlipColour(sellBlip, 2)
    SetBlipScale(sellBlip, 0.9)
    SetBlipAsShortRange(sellBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Chop Shop Buyer')
    EndTextCommandSetBlipName(sellBlip)
end)
