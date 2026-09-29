Finance = {}

local GRACE = 300
local firstSeen = {}
local awaitingEmpty = {}

local function rules(row)
    local dealer = Store.Get(row.dealership_id)
    local base = dealer and dealer.settings.finance or Config.Finance
    local saved = Util.Decode(row.terms)
    if type(saved) ~= 'table' then saved = {} end

    local repossess = saved.repossess or base.repossess

    return {
        intervalHours = tonumber(saved.intervalHours) or tonumber(base.intervalHours) or 24,
        missedLimit = math.max(1, math.floor(tonumber(saved.missedLimit) or tonumber(base.missedLimit) or 3)),
        repossess = repossess == 'hold' and 'hold' or 'remove',
        holdDays = math.max(1, math.floor(tonumber(saved.holdDays) or tonumber(base.holdDays) or 7)),
        returnToStock = base.returnToStock ~= false,
        garage = dealer and dealer.settings.sale.garage or Config.Purchase.garage,
    }
end

local function interval(terms)
    return math.max(60, math.floor((tonumber(terms.intervalHours) or 24) * 3600))
end

local function carName(model)
    local info = Framework.Vehicle(model)
    return info and info.name or model
end

function Finance.OpenCount(citizenid)
    if not citizenid then return 0 end
    local count = MySQL.scalar.await([[
        SELECT COUNT(*) FROM `xs_dealership_finance` WHERE `citizenid` = ? AND `status` IN ('active', 'held')
    ]], { citizenid })
    return math.floor(tonumber(count) or 0)
end

function Finance.Open(src, dealer, model, plate, terms)
    local settings = dealer.settings.finance
    local signed = {
        intervalHours = settings.intervalHours,
        missedLimit = settings.missedLimit,
        repossess = settings.repossess,
        holdDays = settings.holdDays,
    }

    MySQL.insert.await([[
        INSERT INTO `xs_dealership_finance`
            (`dealership_id`, `citizenid`, `plate`, `model`, `price`, `balance`, `payment`, `payments_left`, `next_due`, `status`, `terms`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?)
    ]], {
        dealer.id, Framework.GetCitizenId(src), plate, model, terms.price, terms.total, terms.payment,
        terms.payments, os.time() + interval(signed), json.encode(signed),
    })
end

local function deposit(row, amount, byName)
    local dealer = Store.Get(row.dealership_id)
    if dealer and dealer.mode == 'job' and amount > 0 then
        Banking.Add(dealer, amount, ('Finance payment on %s'):format(row.plate), byName, 'finance')
    end
end

local function takeBack(row, src)
    local vehicleRow = Framework.OwnedVehicleRow(row.plate, row.citizenid)
    Framework.RemoveOwnedVehicle(row.plate, row.citizenid)

    local entity = Vehicles.FindByPlate(row.plate)
    if entity then
        if Vehicles.Occupied(entity) then
            awaitingEmpty[row.plate] = true
        else
            Vehicles.Delete(entity)
        end
    end

    local name = carName(row.model)
    local terms = rules(row)

    if terms.repossess == 'hold' and vehicleRow then
        local days = terms.holdDays
        MySQL.update.await([[
            UPDATE `xs_dealership_finance` SET `status` = 'held', `vehicle` = ?, `held_until` = ? WHERE `id` = ?
        ]], { json.encode(vehicleRow), os.time() + days * 86400, row.id })

        if src then
            Framework.Notify(src, ('The dealership has taken your %s back. Pay %s at their desk within %d days to get it back.')
                :format(name, Util.Money(row.balance), days), 'error')
        end
        return
    end

    MySQL.update.await("UPDATE `xs_dealership_finance` SET `status` = 'repossessed' WHERE `id` = ?", { row.id })

    local dealer = Store.Get(row.dealership_id)
    if dealer and terms.returnToStock then Store.AddStock(dealer, row.model, 1) end

    if src then
        Framework.Notify(src, ('The dealership has taken your %s back after missed payments.'):format(name), 'error')
    end
end

local function charge(src, row)
    local amount = math.min(row.payment, row.balance)
    local name = carName(row.model)
    local terms = rules(row)

    if Framework.RemoveMoney(src, 'bank', amount, ('Finance payment: %s'):format(name)) then
        local balance = row.balance - amount
        local status = balance <= 0 and 'paid' or 'active'

        MySQL.update.await([[
            UPDATE `xs_dealership_finance`
            SET `balance` = ?, `payments_left` = GREATEST(`payments_left` - 1, 0), `next_due` = `next_due` + ?, `missed` = 0, `status` = ?
            WHERE `id` = ?
        ]], { math.max(0, balance), interval(terms), status, row.id })

        deposit(row, amount, Framework.GetName(src))

        if status == 'paid' then
            Framework.Notify(src, ('Your %s is paid off. It is all yours.'):format(name), 'success')
        else
            Framework.Notify(src, ('%s paid towards your %s. %s left.'):format(Util.Money(amount), name, Util.Money(balance)), 'inform')
        end
        return
    end

    local missed = row.missed + 1

    if missed >= terms.missedLimit then
        MySQL.update.await('UPDATE `xs_dealership_finance` SET `missed` = ? WHERE `id` = ?', { missed, row.id })
        row.missed = missed
        takeBack(row, src)
        return
    end

    MySQL.update.await('UPDATE `xs_dealership_finance` SET `missed` = ?, `next_due` = `next_due` + ? WHERE `id` = ?',
        { missed, interval(terms), row.id })

    local left = terms.missedLimit - missed
    Framework.Notify(src, ('Your %s payment on the %s did not go through. %d more missed and it gets taken back.')
        :format(Util.Money(amount), name, left), 'error')
end

CreateThread(function()
    while true do
        Wait(60000)

        if DB.ready then
            local now = os.time()
            local online = {}

            for _, player in pairs(Framework.Players()) do
                local data = player.PlayerData
                if data and data.citizenid then online[data.citizenid] = data.source end
            end

            for citizenid in pairs(firstSeen) do
                if not online[citizenid] then firstSeen[citizenid] = nil end
            end

            local due = MySQL.query.await([[
                SELECT * FROM `xs_dealership_finance` WHERE `status` = 'active' AND `next_due` <= ?
            ]], { now }) or {}

            local warned = {}

            for _, row in ipairs(due) do
                local src = online[row.citizenid]
                if src then
                    if not firstSeen[row.citizenid] then
                        firstSeen[row.citizenid] = now
                    end

                    if now - firstSeen[row.citizenid] >= GRACE then
                        charge(src, row)
                    elseif not warned[row.citizenid] then
                        warned[row.citizenid] = true
                        Framework.Notify(src, 'A car finance payment is due. It comes out of your bank in a few minutes.', 'inform')
                    end
                end
            end

            for _, row in ipairs(MySQL.query.await([[
                SELECT * FROM `xs_dealership_finance` WHERE `status` = 'held' AND `held_until` <= ?
            ]], { now }) or {}) do
                MySQL.update.await("UPDATE `xs_dealership_finance` SET `status` = 'repossessed', `vehicle` = NULL WHERE `id` = ?", { row.id })
                local dealer = Store.Get(row.dealership_id)
                if dealer and rules(row).returnToStock then Store.AddStock(dealer, row.model, 1) end
            end

            for plate in pairs(awaitingEmpty) do
                local entity = Vehicles.FindByPlate(plate)
                if not entity then
                    awaitingEmpty[plate] = nil
                elseif not Vehicles.Occupied(entity) then
                    Vehicles.Delete(entity)
                    awaitingEmpty[plate] = nil
                end
            end
        end
    end
end)

local function listFor(citizenid)
    local rows = MySQL.query.await([[
        SELECT * FROM `xs_dealership_finance`
        WHERE `citizenid` = ? AND `status` IN ('active', 'held')
        ORDER BY `id` DESC
    ]], { citizenid }) or {}

    local now = os.time()
    local out = {}

    for _, row in ipairs(rows) do
        local dealer = Store.Get(row.dealership_id)
        local info = Framework.Vehicle(row.model) or {}

        out[#out + 1] = {
            id = row.id,
            dealer = dealer and dealer.name or 'Closed dealership',
            model = row.model,
            name = info.name or row.model,
            brand = info.brand or '',
            plate = row.plate,
            price = row.price,
            balance = row.balance,
            payment = math.min(row.payment, row.balance),
            paymentsLeft = row.payments_left,
            dueIn = row.next_due - now,
            missed = row.missed,
            missedLimit = rules(row).missedLimit,
            status = row.status,
            heldFor = row.held_until and (row.held_until - now) or nil,
        }
    end

    return out
end

function Finance.List(src)
    local citizenid = Framework.GetCitizenId(src)
    return citizenid and listFor(citizenid) or {}
end

local function nearAnyDesk(src)
    for _, dealer in pairs(Store.dealers) do
        if Purchase.Near(src, dealer) then return true end
    end
    return false
end

local function ownRow(src, id)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return nil end
    return MySQL.single.await('SELECT * FROM `xs_dealership_finance` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid })
end

lib.callback.register('XS-Dealerships:server:pay', function(src, id, everything)
    if not nearAnyDesk(src) then return false, 'Pay at a dealership desk.' end

    local row = ownRow(src, id)
    if not row or row.status ~= 'active' then return false, 'That agreement is not open.' end

    local amount = everything and row.balance or math.min(row.payment, row.balance)
    if not Framework.RemoveMoney(src, 'bank', amount, ('Finance payment: %s'):format(carName(row.model))) then
        return false, ('You need %s in the bank.'):format(Util.Money(amount))
    end

    local balance = row.balance - amount
    local status = balance <= 0 and 'paid' or 'active'

    if everything then
        MySQL.update.await("UPDATE `xs_dealership_finance` SET `balance` = 0, `payments_left` = 0, `missed` = 0, `status` = 'paid' WHERE `id` = ?", { row.id })
    else
        MySQL.update.await([[
            UPDATE `xs_dealership_finance`
            SET `balance` = ?, `payments_left` = GREATEST(`payments_left` - 1, 0), `next_due` = `next_due` + ?, `missed` = 0, `status` = ?
            WHERE `id` = ?
        ]], { math.max(0, balance), interval(rules(row)), status, row.id })
    end

    deposit(row, amount, Framework.GetName(src))
    return true, Finance.List(src)
end)

lib.callback.register('XS-Dealerships:server:recover', function(src, id)
    if not nearAnyDesk(src) then return false, 'Pay at a dealership desk.' end

    local row = ownRow(src, id)
    if not row or row.status ~= 'held' then return false, 'That car is not being held.' end
    if (row.held_until or 0) < os.time() then return false, 'Too late. The car has gone back into stock.' end

    local snapshot = Util.Decode(row.vehicle)
    if not snapshot then return false, 'The dealership has no record of the car.' end

    if not Framework.RemoveMoney(src, 'bank', row.balance, ('Recovered %s'):format(carName(row.model))) then
        return false, ('You need %s in the bank.'):format(Util.Money(row.balance))
    end

    if not Framework.RestoreOwnedVehicle(snapshot, rules(row).garage) then
        Framework.AddMoney(src, 'bank', row.balance, 'Dealership refund')
        return false, 'The car could not be put back in your garage. You have not been charged.'
    end

    MySQL.update.await("UPDATE `xs_dealership_finance` SET `balance` = 0, `status` = 'paid', `vehicle` = NULL WHERE `id` = ?", { row.id })
    deposit(row, row.balance, Framework.GetName(src))

    return true, Finance.List(src)
end)
