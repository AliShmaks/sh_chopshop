-- ui.lua

local zoneActive = false
-- =========================================================
-- PROGRESS BAR
-- =========================================================
local BAR = {
    width = 0.16, height = 0.012, y = 0.86,
    bg = { 0, 0, 0, 200 }, line = { 10, 30, 90, 255 },
    textCol = { 255, 255, 255, 255 }, textScale = 0.32, font = 4,
}

local function drawBar(progress, label)
    local w, h = BAR.width, BAR.height
    local x = (1.0 - w) * 0.5
    local y = BAR.y
    DrawRect(x + w * 0.5, y + h * 0.5, w, h, BAR.bg[1], BAR.bg[2], BAR.bg[3], BAR.bg[4])
    if progress > 0 then
        local fillW = w * math.min(progress, 1.0)
        DrawRect(x + fillW * 0.5, y + h * 0.5, fillW, h, BAR.line[1], BAR.line[2], BAR.line[3], BAR.line[4])
    end
    if label and label ~= '' then
        SetTextFont(BAR.font)
        SetTextScale(BAR.textScale, BAR.textScale)
        SetTextColour(BAR.textCol[1], BAR.textCol[2], BAR.textCol[3], BAR.textCol[4])
        SetTextCentre(true)
        SetTextOutline()
        SetTextEntry('STRING')
        AddTextComponentString(label)
        DrawText(x + w * 0.5, y - 0.022)
    end
end

function WorkBar(seconds, label)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return true end
    local start = GetGameTimer()
    local duration = math.floor(seconds * 1000)
    while true do
        local progress = (GetGameTimer() - start) / duration
        if progress >= 1.0 then
            drawBar(1.0, label)
            return true
        end
        drawBar(progress, label)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 73, true)
        if IsDisabledControlJustPressed(0, 73) then return false end
        Wait(0)
    end
end

-- =========================================================
-- ZONE PROMPT
-- =========================================================
CreateThread(function()
    while true do
        local inZone = IsInChopShopZone()
        if inZone ~= zoneActive then
            zoneActive = inZone
            if zoneActive then Notify(Config.Notify.enterZone, 'inform') end
        end

        local shouldShow = false
        if zoneActive then
            local ped = PlayerPedId()
            local veh
            if IsPedInAnyVehicle(ped, false) then
                veh = GetVehiclePedIsIn(ped, false)
            else
                veh = GetNearestVehicle(6.0)
            end
            if veh and veh ~= 0 and DoesEntityExist(veh) and not IsVehicleBlacklisted(veh) and not State.vehicleClaimedOnce then
                shouldShow = true
            end
        end

        if shouldShow and not State._textUIShown then
            lib.showTextUI('[E] Open parts', { position = 'top-center' })
            State._textUIShown = true
        elseif not shouldShow and State._textUIShown then
            lib.hideTextUI()
            State._textUIShown = false
        end

        Wait(zoneActive and 400 or 1000)
    end
end)
