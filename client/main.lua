Dealers = {}

local blips = {}

function IsStaff(dealer)
    if not dealer or dealer.mode ~= 'job' or dealer.job == '' then return false end
    local job, onDuty = Framework.GetJob()
    if job ~= dealer.job then return false end
    return onDuty or not dealer.settings.staff.requireDuty
end

function Can(dealer, action)
    if not dealer then return false end
    if dealer.mode ~= 'job' or dealer.job == '' then return true end
    if dealer.settings.customers[action] then return true end
    return IsStaff(dealer)
end

function VehicleFromNet(netId, timeout)
    local deadline = GetGameTimer() + (timeout or 10000)

    repeat
        if NetworkDoesNetworkIdExist(netId) then
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then return vehicle end
        end
        Wait(50)
    until GetGameTimer() > deadline

    return nil
end

function TakeControl(vehicle)
    for _ = 1, 40 do
        if NetworkHasControlOfEntity(vehicle) then return true end
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end
    return NetworkHasControlOfEntity(vehicle)
end

function FadeOut()
    DoScreenFadeOut(250)
    local deadline = GetGameTimer() + 600
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(0) end
end

function WarpInto(vehicle)
    local deadline = GetGameTimer() + 5000

    repeat
        local ped = cache.ped
        if GetVehiclePedIsIn(ped, false) == vehicle then return true end
        SetPedIntoVehicle(ped, vehicle, -1)
        Wait(100)
    until GetGameTimer() > deadline

    return GetVehiclePedIsIn(cache.ped, false) == vehicle
end

local function clearBlips()
    for _, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end

local function makeBlip(dealer)
    local blip = dealer.settings.blip
    local at = dealer.points.desk or dealer.points.spots[1]
    if not blip.show or not at then return end

    local handle = AddBlipForCoord(at.x, at.y, at.z)
    SetBlipSprite(handle, blip.sprite)
    SetBlipColour(handle, blip.colour)
    SetBlipScale(handle, 0.8)
    SetBlipAsShortRange(handle, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(dealer.name)
    EndTextCommandSetBlipName(handle)
    blips[dealer.id] = handle
end

local function deskOptions(dealer)
    local options = {
        {
            id = 'browse', label = 'Browse cars', icon = 'fas fa-car',
            action = function() UI.OpenShowroom(dealer.id) end,
        },
        {
            id = 'finance', label = 'My finance', icon = 'fas fa-file-invoice-dollar',
            action = function() UI.OpenShowroom(dealer.id, { tab = 'finance' }) end,
        },
    }

    if Config.Tablet.item == '' then
        options[#options + 1] = {
            id = 'office', label = 'Dealership office', icon = 'fas fa-briefcase',
            canInteract = function() return IsStaff(Dealers[dealer.id]) end,
            action = function() Tablet.Open(dealer.id) end,
        }
    end

    return options
end

local function rebuild(list)
    clearBlips()

    for id in pairs(Dealers) do Target.Remove(('xsd:desk:%d'):format(id)) end
    Dealers = {}

    for _, dealer in ipairs(list or {}) do
        Dealers[dealer.id] = dealer
        makeBlip(dealer)

        local desk = dealer.points.desk
        if desk then
            Target.AddSphere(('xsd:desk:%d'):format(dealer.id), desk, Config.Desk.radius, deskOptions(dealer))
        end
    end

    Showcase.Refresh()
end

RegisterNetEvent('XS-Dealerships:client:dealers', function(list)
    rebuild(list)
end)

RegisterNetEvent('XS-Dealerships:client:spot', function(dealerId, spotId, model)
    local dealer = Dealers[dealerId]
    if not dealer then return end
    dealer.showcase = dealer.showcase or {}
    dealer.showcase[spotId] = model
end)

RegisterNetEvent('XS-Dealerships:client:delivered', function(netId, props, plate, warp)
    if warp then FadeOut() end

    local vehicle = VehicleFromNet(netId)

    if vehicle then
        TakeControl(vehicle)

        if props.color1 then SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3]) end
        if props.color2 then SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3]) end

        SetVehicleNumberPlateText(vehicle, plate)
        SetVehicleDirtLevel(vehicle, 0.0)
        Fuel.Set(vehicle, 100.0)

        if warp then WarpInto(vehicle) end
    end

    if warp then DoScreenFadeIn(400) end
end)

RegisterNetEvent('XS-Dealerships:client:diag', function(lines)
    lines[#lines + 1] = ('target: %s · keys (client): %s · fuel: %s'):format(
        Target.name or 'NONE FOUND', Keys.name or 'none', Fuel.name or 'game only')

    for _, line in ipairs(lines) do print('[XS-Dealerships] ' .. line) end
    Framework.Notify('Dealership diagnostics printed to your F8 console.', 'inform')
end)

local function ready()
    TriggerServerEvent('XS-Dealerships:server:ready')
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then ready() end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', ready)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if UI.open then UI.Close() end
    Placement.Abort()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearBlips()
    for id in pairs(Dealers) do Target.Remove(('xsd:desk:%d'):format(id)) end
end)
