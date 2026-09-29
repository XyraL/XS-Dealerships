Showcase = {}

local swapped = {}

function Showcase.State(dealer)
    local out = {}
    local mine = swapped[dealer.id] or {}

    for _, spot in ipairs(dealer.points.spots) do
        local swap = mine[spot.id]
        out[spot.id] = swap and swap.model or spot.model
    end

    return out
end

function Showcase.Reset(dealer)
    swapped[dealer.id] = nil
end

function Showcase.Forget(dealerId)
    swapped[dealerId] = nil
end

local function findSpot(dealer, spotId)
    for _, spot in ipairs(dealer.points.spots) do
        if spot.id == tostring(spotId) then return spot end
    end
    return nil
end

function Showcase.Spot(dealer, spotId)
    return findSpot(dealer, spotId)
end

function Showcase.Current(dealer, spotId)
    local spot = findSpot(dealer, spotId)
    if not spot then return nil end
    local swap = swapped[dealer.id] and swapped[dealer.id][spot.id]
    return swap and swap.model or spot.model
end

local function announce(dealer, spotId, model)
    TriggerClientEvent('XS-Dealerships:client:spot', -1, dealer.id, spotId, model)
end

local function setSpot(dealer, spot, model)
    swapped[dealer.id] = swapped[dealer.id] or {}

    if model == spot.model then
        swapped[dealer.id][spot.id] = nil
    else
        swapped[dealer.id][spot.id] = { model = model, since = os.time() }
    end

    announce(dealer, spot.id, model)
end

function Showcase.Set(dealer, spotId, model)
    local spot = findSpot(dealer, spotId)
    if not spot then return false, 'That spot is gone.' end

    model = tostring(model or ''):lower()
    if not Store.Entry(dealer, model) then return false, 'This dealership does not sell that car.' end

    setSpot(dealer, spot, model)
    return true
end

function Showcase.Floor(dealer)
    local out = {}

    for index, spot in ipairs(dealer.points.spots) do
        local model = Showcase.Current(dealer, spot.id)
        local entry = Store.Entry(dealer, model)
        local info = Framework.Vehicle(model) or {}
        local own = Framework.Vehicle(spot.model) or {}

        out[#out + 1] = {
            id = spot.id,
            number = index,
            model = model,
            own = spot.model,
            ownName = own.name or spot.model,
            name = info.name or model,
            brand = info.brand or '',
            price = entry and entry.price or 0,
            stock = entry and entry.stock or 0,
        }
    end

    return out
end

lib.callback.register('XS-Dealerships:server:swap', function(src, dealerId, spotId, model)
    local dealer = Store.Get(dealerId)
    if not dealer then return false, 'That dealership no longer exists.' end

    local spot = findSpot(dealer, spotId)
    if not spot then return false, 'That spot is gone.' end

    model = tostring(model or ''):lower()
    if not Store.Entry(dealer, model) then return false, 'This dealership does not sell that car.' end

    if not Store.Can(src, dealer, 'swap') then return false, 'Only staff can change the display here.' end

    local ped = GetPlayerPed(src)
    if Util.Distance(GetEntityCoords(ped), spot) > Config.Purchase.maxDistance then
        return false, 'Walk up to the car first.'
    end

    setSpot(dealer, spot, model)
    return true
end)

CreateThread(function()
    while true do
        Wait(30000)

        local now = os.time()

        for dealerId, spots in pairs(swapped) do
            local dealer = Store.Get(dealerId)
            local limit = dealer and (tonumber(dealer.settings.showcase.resetMinutes) or 0) * 60 or 0

            for spotId, swap in pairs(spots) do
                if not dealer then
                    spots[spotId] = nil
                elseif limit > 0 and now - swap.since >= limit then
                    spots[spotId] = nil
                    local spot = findSpot(dealer, spotId)
                    if spot then announce(dealer, spotId, spot.model) end
                end
            end
        end
    end
end)
