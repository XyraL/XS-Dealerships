TestDrive = {}

local drives = {}

local function finish(src, reason)
    local drive = drives[src]
    if not drive then return end
    drives[src] = nil

    Vehicles.Delete(drive.vehicle)

    if not GetPlayerName(src) then return end

    if drive.bucket then SetPlayerRoutingBucket(src, 0) end
    TriggerClientEvent('XS-Dealerships:client:testDriveEnd', src, reason,
        Config.TestDrive.returnToStart and drive.origin or nil)
end

function TestDrive.Active(src)
    return drives[src] ~= nil
end

lib.callback.register('XS-Dealerships:server:testDrive', function(src, dealerId, model, typeHint)
    local dealer = Store.Get(dealerId)
    if not dealer then return false, 'That dealership no longer exists.' end

    if not Config.TestDrive.enabled or not dealer.settings.testDrives then
        return false, 'This dealership does not do test drives.'
    end
    if not dealer.points.test then return false, 'This dealership has nowhere to start a test drive yet.' end
    if not Store.CanShop(src, dealer) then return false, 'Ask one of the salespeople for a test drive.' end
    if not Purchase.Near(src, dealer) then return false, 'You are too far from the dealership.' end
    if drives[src] then return false, 'You are already on a test drive.' end

    model = tostring(model or ''):lower()
    if not Store.Entry(dealer, model) then return false, 'This dealership does not sell that car.' end
    if Vehicles.Blocked(dealer.points.test) then return false, 'Something is parked where test drives start.' end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local plate = ('%s%02d'):format(Config.TestDrive.plate:sub(1, 6), math.random(0, 99))

    local vehicle = Vehicles.Spawn(model, dealer.points.test, plate, Vehicles.TypeOf(model, typeHint))
    if not vehicle then return false, 'The car could not be brought round. Try again.' end

    local bucket
    if Config.TestDrive.privateWorld then
        bucket = 7000 + src
        SetPlayerRoutingBucket(src, bucket)
        SetEntityRoutingBucket(vehicle, bucket)
    end

    SetPedIntoVehicle(ped, vehicle, -1)
    Keys.Give(src, vehicle, plate)

    drives[src] = {
        vehicle = vehicle,
        dealer = dealer.id,
        ends = os.time() + Config.TestDrive.seconds,
        origin = { x = coords.x, y = coords.y, z = coords.z, h = GetEntityHeading(ped) },
        bucket = bucket,
    }

    TriggerClientEvent('XS-Dealerships:client:testDrive', src, NetworkGetNetworkIdFromEntity(vehicle), Config.TestDrive.seconds)
    return true
end)

lib.callback.register('XS-Dealerships:server:endTestDrive', function(src)
    finish(src, 'ended')
    return true
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()

        for src, drive in pairs(drives) do
            if not DoesEntityExist(drive.vehicle) then
                finish(src, 'lost')
            elseif now >= drive.ends then
                finish(src, 'time')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    finish(source, 'left')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(drives) do finish(src, 'stopped') end
end)
