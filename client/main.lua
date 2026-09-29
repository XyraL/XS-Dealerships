Dealers = {}

local blips = {}

function IsStaff(dealer)
    if not dealer or dealer.mode ~= 'job' or dealer.job == '' then return false end
    local job, onDuty = Framework.GetJob()
    if job ~= dealer.job then return false end
    return onDuty or not Config.Jobs.requireDuty
end

function CanShop(dealer)
    if not dealer then return false end
    if dealer.mode ~= 'job' or dealer.settings.access ~= 'job' then return true end
    return IsStaff(dealer)
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

RegisterNetEvent('XS-Dealerships:client:delivered', function(netId, props, plate)
    local vehicle = 0

    for _ = 1, 100 do
        if NetworkDoesNetworkIdExist(netId) then
            vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then break end
        end
        Wait(50)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    for _ = 1, 40 do
        if NetworkHasControlOfEntity(vehicle) then break end
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end

    if props.color1 then SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3]) end
    if props.color2 then SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3]) end

    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleDirtLevel(vehicle, 0.0)
    Fuel.Set(vehicle, 100.0)
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearBlips()
    for id in pairs(Dealers) do Target.Remove(('xsd:desk:%d'):format(id)) end
end)
