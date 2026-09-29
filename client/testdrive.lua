local driving = false

RegisterNetEvent('XS-Dealerships:client:testDrive', function(netId, seconds)
    driving = true
    FadeOut()

    local vehicle = VehicleFromNet(netId)
    if vehicle then
        TakeControl(vehicle)
        Fuel.Set(vehicle, 100.0)
        SetVehicleDirtLevel(vehicle, 0.0)
        WarpInto(vehicle)
    end

    DoScreenFadeIn(400)
    UI.Send('testdrive', { seconds = seconds })
    Framework.Notify(('Test drive started. You have %d seconds.'):format(seconds), 'inform')
end)

local REASONS = {
    time = 'Time is up. Hope you liked it.',
    ended = 'Test drive over.',
    lost = 'The test car is gone, so the drive is over.',
}

RegisterNetEvent('XS-Dealerships:client:testDriveEnd', function(reason, origin)
    driving = false
    UI.Send('testdriveEnd')

    if origin then
        DoScreenFadeOut(400)
        Wait(450)
        local ped = cache.ped
        SetEntityCoords(ped, origin.x, origin.y, origin.z, false, false, false, false)
        SetEntityHeading(ped, origin.h or 0.0)
        Wait(250)
        DoScreenFadeIn(400)
    end

    if REASONS[reason] then Framework.Notify(REASONS[reason], 'inform') end
end)

RegisterCommand('endtestdrive', function()
    if not driving then return end
    lib.callback.await('XS-Dealerships:server:endTestDrive', false)
end, false)
