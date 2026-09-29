Purchase = {}

local busy = {}
local offers = {}

local function near(src, dealer)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local max = Config.Purchase.maxDistance

    if dealer.points.desk and Util.Distance(coords, dealer.points.desk) <= max then return true end
    for _, spot in ipairs(dealer.points.spots) do
        if Util.Distance(coords, spot) <= max then return true end
    end

    return false
end

function Purchase.Near(src, dealer)
    return near(src, dealer)
end

local function methodAllowed(dealer, method)
    if method == 'cash' then return Config.Purchase.cash end
    if method == 'bank' then return Config.Purchase.bank end
    if method == 'finance' then return Config.Finance.enabled and dealer.settings.finance end
    return false
end

function Purchase.Methods(dealer)
    return {
        cash = methodAllowed(dealer, 'cash') and true or false,
        bank = methodAllowed(dealer, 'bank') and true or false,
        finance = methodAllowed(dealer, 'finance') and true or false,
    }
end

local function logSale(dealer, model, price, method, plate, buyer, seller, commission)
    MySQL.insert.await([[
        INSERT INTO `xs_dealership_sales`
            (`dealership_id`, `model`, `price`, `method`, `plate`, `buyer`, `buyer_name`, `seller`, `seller_name`, `commission`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        dealer.id, model, price, method, plate,
        Framework.GetCitizenId(buyer) or '', Framework.GetName(buyer),
        seller and Framework.GetCitizenId(seller) or nil, seller and Framework.GetName(seller) or nil,
        commission or 0,
    })
end

local function settle(dealer, model, price, received, buyer, seller)
    if dealer.mode ~= 'job' then return 0 end

    local commission = 0
    local role = seller and Store.Role(seller, dealer)

    if role and role.canSell and role.commission > 0 then
        commission = math.min(received, math.floor(price * role.commission / 100))
    end

    local label = Framework.Vehicle(model)
    local note = ('Sold %s'):format(label and label.name or model)

    Banking.Add(dealer, received - commission, note, seller and Framework.GetName(seller) or Framework.GetName(buyer), 'sale')

    if commission > 0 then
        Framework.AddMoney(seller, 'bank', commission, 'Dealership commission')
        Framework.Notify(seller, ('You earned %s commission.'):format(Util.Money(commission)), 'success')
    end

    return commission
end

function Purchase.Process(buyer, dealer, model, method, paint, typeHint, seller)
    if busy[buyer] then return false, 'Already working on it.' end
    busy[buyer] = true

    local ok, result, extra = pcall(function()
        local entry = Store.Entry(dealer, model)
        if not entry then return false, 'This dealership does not sell that car.' end
        if entry.stock == 0 then return false, 'That car is sold out.' end

        local price = entry.price
        local account = method
        local due = price
        local terms

        if method == 'finance' then
            local citizenid = Framework.GetCitizenId(buyer)
            local open = Finance.OpenCount(citizenid)
            if open >= Config.Finance.maxActive then
                return false, ('You already have %d cars on finance.'):format(open)
            end
            terms = Util.FinanceTerms(price)
            account = 'bank'
            due = terms.down
        end

        if Framework.GetMoney(buyer, account) < due then
            return false, ('You need %s in your %s.'):format(Util.Money(due), account == 'cash' and 'pocket' or 'bank')
        end

        if not Store.Reserve(dealer, model) then return false, 'That car just sold out.' end

        local plate = Vehicles.NewPlate()
        if not plate then
            Store.AddStock(dealer, model, 1)
            return false, 'Could not find a free plate. Try again.'
        end

        local name = (Framework.Vehicle(model) or {}).name or model

        if due > 0 and not Framework.RemoveMoney(buyer, account, due, ('Bought a %s'):format(name)) then
            Store.AddStock(dealer, model, 1)
            return false, 'The payment did not go through.'
        end

        local deliver = Config.Purchase.deliver
        if deliver == 'spawn' and (not dealer.points.buy or Vehicles.Blocked(dealer.points.buy)) then
            deliver = 'garage'
        end

        local props = Vehicles.Paint(paint)
        props.fuelLevel = 100.0

        local given, why = Framework.GiveVehicle(buyer, model, plate, props, deliver == 'garage', Config.Purchase.garage)
        if not given then
            if due > 0 then Framework.AddMoney(buyer, account, due, 'Dealership refund') end
            Store.AddStock(dealer, model, 1)
            print(('^1[XS-Dealerships]^0 could not register %s for %s: %s'):format(plate, GetPlayerName(buyer) or buyer, why))
            return false, 'The car could not be registered to you. You have not been charged.'
        end

        if terms then Finance.Open(buyer, dealer, model, plate, terms) end

        local commission = settle(dealer, model, price, due, buyer, seller)
        logSale(dealer, model, price, method, plate, buyer, seller, commission)

        if deliver == 'spawn' then
            local vehicle = Vehicles.Spawn(model, dealer.points.buy, plate, Vehicles.TypeOf(model, typeHint))

            if vehicle then
                if Config.Purchase.warpIntoVehicle then
                    SetPedIntoVehicle(GetPlayerPed(buyer), vehicle, -1)
                end
                Keys.Give(buyer, vehicle, plate)
                TriggerClientEvent('XS-Dealerships:client:delivered', buyer, NetworkGetNetworkIdFromEntity(vehicle), props, plate)
            else
                MySQL.update.await('UPDATE `player_vehicles` SET `state` = 1, `garage` = ? WHERE `plate` = ?',
                    { Config.Purchase.garage, plate })
                deliver = 'garage'
            end
        end

        return true, { plate = plate, model = model, name = name, method = method, garage = deliver == 'garage' }
    end)

    busy[buyer] = nil

    if not ok then
        print(('^1[XS-Dealerships]^0 purchase failed: %s'):format(tostring(result)))
        return false, 'Something went wrong. You have not been charged.'
    end

    return result, extra
end

lib.callback.register('XS-Dealerships:server:buy', function(src, dealerId, model, method, paint, typeHint)
    local dealer = Store.Get(dealerId)
    if not dealer then return false, 'That dealership no longer exists.' end
    if not Store.CanShop(src, dealer) then return false, 'Buy through one of the salespeople here.' end
    if not near(src, dealer) then return false, 'You are too far from the dealership.' end
    if not methodAllowed(dealer, method) then return false, 'That way of paying is not taken here.' end

    return Purchase.Process(src, dealer, tostring(model or ''):lower(), method, paint, typeHint)
end)

lib.callback.register('XS-Dealerships:server:nearby', function(src, dealerId)
    local dealer = Store.Get(dealerId)
    if not dealer or not Store.Role(src, dealer).canSell then return {} end

    local mine = GetEntityCoords(GetPlayerPed(src))
    local out = {}

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target ~= src and Util.Distance(GetEntityCoords(GetPlayerPed(target)), mine) <= Config.Jobs.sellDistance then
            out[#out + 1] = { id = target, name = Framework.GetName(target) }
        end
    end

    return out
end)

lib.callback.register('XS-Dealerships:server:offer', function(src, dealerId, model, target)
    local dealer = Store.Get(dealerId)
    if not dealer then return false, 'That dealership no longer exists.' end

    local role = Store.Role(src, dealer)
    if not role.canSell then return false, 'You cannot sell here.' end

    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return false, 'Pick a customer.' end

    if Util.Distance(GetEntityCoords(GetPlayerPed(target)), GetEntityCoords(GetPlayerPed(src))) > Config.Jobs.sellDistance then
        return false, 'They need to be standing with you.'
    end

    model = tostring(model or ''):lower()
    local entry = Store.Entry(dealer, model)
    if not entry then return false, 'This dealership does not sell that car.' end
    if entry.stock == 0 then return false, 'That car is sold out.' end

    local info = Framework.Vehicle(model) or {}
    local expires = os.time() + Config.Jobs.offerSeconds

    offers[target] = { seller = src, dealer = dealer.id, model = model, expires = expires }

    TriggerClientEvent('XS-Dealerships:client:offer', target, {
        dealer = { id = dealer.id, name = dealer.name, accent = dealer.settings.accent },
        model = model,
        name = info.name or model,
        brand = info.brand or '',
        category = info.category or '',
        price = entry.price,
        seller = Framework.GetName(src),
        methods = Purchase.Methods(dealer),
        terms = Util.FinanceTerms(entry.price),
        seconds = Config.Jobs.offerSeconds,
    })

    return true
end)

lib.callback.register('XS-Dealerships:server:answer', function(src, accept, method, paint, typeHint)
    local offer = offers[src]
    offers[src] = nil

    if not offer or offer.expires < os.time() then return false, 'That offer has run out.' end

    local dealer = Store.Get(offer.dealer)
    local seller = offer.seller
    if not dealer then return false, 'That dealership no longer exists.' end

    if not accept then
        if GetPlayerName(seller) then
            Framework.Notify(seller, ('%s turned the offer down.'):format(Framework.GetName(src)), 'inform')
        end
        return true
    end

    if not GetPlayerName(seller) or not Store.Role(seller, dealer).canSell then
        return false, 'The salesperson is not available any more.'
    end
    if not methodAllowed(dealer, method) then return false, 'That way of paying is not taken here.' end

    local ok, result = Purchase.Process(src, dealer, offer.model, method, paint, typeHint, seller)

    if ok then
        Framework.Notify(seller, ('%s bought the %s.'):format(Framework.GetName(src), result.name), 'success')
    else
        Framework.Notify(seller, ('The sale did not go through: %s'):format(result), 'error')
    end

    return ok, result
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
    offers[source] = nil
end)
