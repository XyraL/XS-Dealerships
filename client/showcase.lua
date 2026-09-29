Showcase = {}

local cars = {}
local props = {}

local function spotOptions(dealerId, spotId)
    local function dealer() return Dealers[dealerId] end
    local function current()
        local d = dealer()
        return d and d.showcase and d.showcase[spotId]
    end

    return {
        {
            id = 'view', label = 'Look at this car', icon = 'fas fa-eye',
            action = function() UI.OpenShowroom(dealerId, { spot = spotId, focus = current() }) end,
        },
        {
            id = 'buy', label = 'Buy this car', icon = 'fas fa-tag',
            canInteract = function() return CanShop(dealer()) end,
            action = function() UI.OpenShowroom(dealerId, { spot = spotId, focus = current(), step = 'buy' }) end,
        },
        {
            id = 'swap', label = 'Show a different car', icon = 'fas fa-right-left',
            canInteract = function() return CanShop(dealer()) end,
            action = function() UI.OpenShowroom(dealerId, { spot = spotId, swap = true }) end,
        },
        {
            id = 'test', label = 'Test drive', icon = 'fas fa-road',
            canInteract = function()
                local d = dealer()
                return CanShop(d) and Config.TestDrive.enabled and d.settings.testDrives and d.points.test ~= nil
            end,
            action = function() UI.TestDrive(dealerId, current()) end,
        },
        {
            id = 'sell', label = 'Sell to a customer', icon = 'fas fa-handshake',
            canInteract = function() return IsStaff(dealer()) end,
            action = function() UI.OpenShowroom(dealerId, { spot = spotId, focus = current(), step = 'sell' }) end,
        },
    }
end

local function despawnCar(key)
    local entry = cars[key]
    if not entry then return end
    cars[key] = nil
    Target.Remove('xsd:spot:' .. key)
    if DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
end

local function load(hash, timeout)
    local ok = pcall(lib.requestModel, hash, timeout)
    return ok and HasModelLoaded(hash)
end

local function spawnCar(key, dealer, spot, model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        if Config.Debug then print(('[XS-Dealerships] showcase model "%s" is not a vehicle this server streams'):format(model)) end
        if cars[key] then cars[key].loading = false end
        return
    end

    if not load(hash, 15000) then
        cars[key] = nil
        return
    end

    local entry = cars[key]
    if not entry or entry.model ~= model then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local vehicle = CreateVehicle(hash, spot.x, spot.y, spot.z + 0.2, spot.h or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    FreezeEntityPosition(vehicle, true)
    SetEntityInvincible(vehicle, true)
    SetEntityCanBeDamaged(vehicle, false)
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleNumberPlateText(vehicle, Config.Showcase.plate)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleRadioEnabled(vehicle, false)

    entry.entity = vehicle
    entry.loading = false
    entry.at = { x = spot.x, y = spot.y, z = spot.z, h = spot.h }
    Target.AddEntity('xsd:spot:' .. key, vehicle, spotOptions(dealer.id, spot.id))
end

local function despawnProp(dealerId)
    local entity = props[dealerId]
    props[dealerId] = nil
    if entity and entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function spawnProp(dealer)
    local desk = dealer.points.desk
    local hash = joaat(Config.Desk.prop)

    if GetClosestObjectOfType(desk.x, desk.y, desk.z, 1.0, hash, false, false, false) ~= 0 then return end
    if not load(hash, 10000) then return end
    if props[dealer.id] ~= 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local object = CreateObject(hash, desk.x, desk.y, desk.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(object, desk.h or 0.0)
    FreezeEntityPosition(object, true)
    SetEntityCollision(object, false, false)
    props[dealer.id] = object
end

function Showcase.Refresh()
    for key, entry in pairs(cars) do
        local dealerId, spotId = key:match('^(%d+):(.+)$')
        local dealer = Dealers[tonumber(dealerId)]
        local keep = false

        if dealer then
            for _, spot in ipairs(dealer.points.spots) do
                if spot.id == spotId then
                    local at = entry.at
                    keep = not at or (Util.Distance(at, spot) < 0.05 and math.abs((at.h or 0) - (spot.h or 0)) < 0.5)
                    break
                end
            end
        end

        if not keep and not entry.loading then despawnCar(key) end
    end

    for dealerId in pairs(props) do despawnProp(dealerId) end
end

CreateThread(function()
    while true do
        local here = GetEntityCoords(cache.ped)
        local range = Config.Showcase.streamDistance

        for _, dealer in pairs(Dealers) do
            for _, spot in ipairs(dealer.points.spots) do
                local key = ('%d:%s'):format(dealer.id, spot.id)
                local model = dealer.showcase and dealer.showcase[spot.id] or spot.model
                local entry = cars[key]
                local near = Util.Distance(here, spot) < range

                if near then
                    local moved = entry and entry.at
                        and (Util.Distance(entry.at, spot) > 0.05 or math.abs((entry.at.h or 0) - (spot.h or 0)) > 0.5)
                    if entry and (entry.model ~= model or moved) and not entry.loading then
                        despawnCar(key)
                        entry = nil
                    end
                    if not entry then
                        cars[key] = { entity = 0, model = model, loading = true }
                        CreateThread(function() spawnCar(key, dealer, spot, model) end)
                    end
                elseif entry and not entry.loading then
                    despawnCar(key)
                end
            end

            if Config.Desk.prop and dealer.points.desk then
                local near = Util.Distance(here, dealer.points.desk) < range
                if near and props[dealer.id] == nil then
                    props[dealer.id] = 0
                    CreateThread(function() spawnProp(dealer) end)
                elseif not near and props[dealer.id] ~= nil then
                    despawnProp(dealer.id)
                end
            end
        end

        Wait(750)
    end
end)

function Showcase.Entity(dealerId, spotId)
    local entry = cars[('%d:%s'):format(dealerId, spotId)]
    return entry and entry.entity or 0
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for key in pairs(cars) do despawnCar(key) end
    for dealerId in pairs(props) do despawnProp(dealerId) end
end)
