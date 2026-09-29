UI = { open = false }

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

function UI.Send(action, data)
    send(action, data)
end

function UI.Close()
    UI.open = false
    SetNuiFocus(false, false)
    send('close')

    local hook = UI.closeHook
    UI.closeHook = nil
    if hook then hook() end
end

local function focus()
    UI.open = true
    SetNuiFocus(true, true)
end

function UI.ModelType(model)
    local hash = joaat(model or '')
    if IsThisModelABoat(hash) or IsThisModelAJetski(hash) then return 'boat' end
    if IsThisModelAHeli(hash) then return 'heli' end
    if IsThisModelAPlane(hash) then return 'plane' end
    if IsThisModelABike(hash) or IsThisModelABicycle(hash) then return 'bike' end
    return 'automobile'
end

local function specs(models)
    local out = {}

    for _, model in ipairs(models) do
        local hash = joaat(model)

        if IsModelInCdimage(hash) and IsModelAVehicle(hash) then
            local speed = GetVehicleModelEstimatedMaxSpeed(hash)
            local class = GetVehicleClassFromName(hash)

            out[model] = {
                speed = math.floor(speed * (Config.SpeedUnit == 'kmh' and 3.6 or 2.236936) + 0.5),
                acceleration = GetVehicleModelAcceleration(hash),
                braking = GetVehicleModelMaxBraking(hash),
                traction = GetVehicleModelMaxTraction(hash),
                seats = GetVehicleModelNumberOfSeats(hash),
                class = GetLabelText(('VEH_CLASS_%d'):format(class)),
                type = UI.ModelType(model),
            }
        else
            out[model] = { missing = true }
        end
    end

    return out
end

local function uiConfig()
    return {
        paint = Config.Paint,
        speedUnit = Config.SpeedUnit,
        currency = Config.Currency,
        images = Config.Images,
        resource = GetCurrentResourceName(),
    }
end

function UI.OpenShowroom(dealerId, context)
    if Placement.active then return end

    local dealer = Dealers[dealerId]
    if not dealer then return end

    local data = lib.callback.await('XS-Dealerships:server:catalogue', false, dealerId)
    if not data then
        Framework.Notify('This dealership is not open right now.', 'error')
        return
    end

    local models = {}
    for _, car in ipairs(data.cars) do models[#models + 1] = car.model end

    data.specs = specs(models)
    data.context = context or {}
    data.config = uiConfig()

    focus()
    send('showroom', data)
end

function UI.Delivered(result)
    if result.garage then
        Framework.Notify(('Your new %s is waiting in your garage.'):format(result.name), 'success')
    elseif result.warp then
        Framework.Notify(('Your new %s is all yours. Plate %s.'):format(result.name, result.plate), 'success')
    else
        Framework.Notify(('Your new %s is out front. Plate %s.'):format(result.name, result.plate), 'success')
    end
end

function UI.TestDrive(dealerId, model)
    if not model then return end
    local ok, err = lib.callback.await('XS-Dealerships:server:testDrive', false, dealerId, model, UI.ModelType(model))
    if not ok then Framework.Notify(err or 'No test drive right now.', 'error') end
    return ok, err
end

RegisterNUICallback('close', function(_, cb)
    UI.Close()
    cb(true)
end)

RegisterNUICallback('buy', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:buy', false,
        data.dealer, data.model, data.method, data.paint, UI.ModelType(data.model))

    if not ok then
        cb({ ok = false, error = result })
        return
    end

    cb({ ok = true })
    UI.Close()
    UI.Delivered(result)
end)

RegisterNUICallback('testDrive', function(data, cb)
    local ok, err = lib.callback.await('XS-Dealerships:server:testDrive', false,
        data.dealer, data.model, UI.ModelType(data.model))
    cb({ ok = ok, error = err })
    if ok then UI.Close() end
end)

RegisterNUICallback('swap', function(data, cb)
    local ok, err = lib.callback.await('XS-Dealerships:server:swap', false, data.dealer, data.spot, data.model)
    cb({ ok = ok, error = err })
end)

RegisterNUICallback('pay', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:pay', false, data.id, data.everything == true)
    cb({ ok = ok, error = not ok and result or nil, finance = ok and result or nil })
end)

RegisterNUICallback('recover', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:recover', false, data.id)
    cb({ ok = ok, error = not ok and result or nil, finance = ok and result or nil })
end)

RegisterNUICallback('order', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:order', false, data.dealer, data.model, data.quantity)
    cb({ ok = ok, error = not ok and result or nil, office = ok and result or nil })
end)

RegisterNUICallback('nearby', function(data, cb)
    cb(lib.callback.await('XS-Dealerships:server:nearby', false, data.dealer) or {})
end)

RegisterNUICallback('offer', function(data, cb)
    local ok, err = lib.callback.await('XS-Dealerships:server:offer', false, data.dealer, data.model, data.target)
    cb({ ok = ok, error = err })
end)

RegisterNetEvent('XS-Dealerships:client:offer', function(offer)
    if Placement.active then return end
    offer.specs = specs({ offer.model })[offer.model]
    offer.config = uiConfig()
    focus()
    send('offer', offer)
end)

RegisterNUICallback('answer', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:answer', false,
        data.accept == true, data.method, data.paint, UI.ModelType(data.model))

    if not ok then
        cb({ ok = false, error = result })
        return
    end

    cb({ ok = true })
    UI.Close()

    if data.accept and type(result) == 'table' then UI.Delivered(result) end
end)
