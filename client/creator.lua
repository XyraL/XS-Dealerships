local function open()
    local data = lib.callback.await('XS-Dealerships:server:creator', false)
    if not data then
        Framework.Notify('You cannot use the dealership creator.', 'error')
        return
    end

    data.config = {
        images = Config.Images,
        currency = Config.Currency,
        resource = GetCurrentResourceName(),
    }

    UI.open = true
    SetNuiFocus(true, true)
    UI.Send('creator', data)
end

RegisterNetEvent('XS-Dealerships:client:creator', open)

RegisterNUICallback('saveDealer', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:saveDealer', false, data.draft)
    cb({ ok = ok, error = not ok and result or nil, id = ok and result.id or nil, data = ok and result.data or nil })
end)

RegisterNUICallback('deleteDealer', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:deleteDealer', false, data.id)
    cb({ ok = ok, error = not ok and result or nil, data = ok and result or nil })
end)

RegisterNUICallback('place', function(data, cb)
    SetNuiFocus(false, false)
    UI.Send('hide')

    local dealerId = tonumber(data.dealer)
    if dealerId then Showcase.Hide(dealerId, true) end

    local point = Placement.Start({
        label = data.label,
        preview = data.preview,
        origin = data.origin,
        others = data.others,
    })

    if dealerId then Showcase.Hide(dealerId, false) end

    SetNuiFocus(true, true)
    UI.Send('unhide')
    cb(point or false)
end)

RegisterNUICallback('teleport', function(data, cb)
    local point = data and data.point
    if point and point.x then
        SetEntityCoords(cache.ped, point.x + 0.0, point.y + 0.0, point.z + 0.5, false, false, false, false)
    end
    cb(true)
end)
