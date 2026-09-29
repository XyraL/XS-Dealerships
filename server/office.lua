Office = {}

local function salesLog(dealer)
    local rows = MySQL.query.await([[
        SELECT `model`, `price`, `method`, `plate`, `buyer_name`, `seller_name`, `commission`, UNIX_TIMESTAMP(`created_at`) AS `at`
        FROM `xs_dealership_sales` WHERE `dealership_id` = ? ORDER BY `id` DESC LIMIT 60
    ]], { dealer.id }) or {}

    local out = {}
    for _, row in ipairs(rows) do
        local info = Framework.Vehicle(row.model) or {}
        out[#out + 1] = {
            name = info.name or row.model,
            price = row.price,
            method = row.method,
            plate = row.plate,
            buyer = row.buyer_name,
            seller = row.seller_name,
            commission = row.commission,
            at = row.at,
        }
    end
    return out
end

local function team(dealer)
    local stats = {}
    for _, row in ipairs(MySQL.query.await([[
        SELECT `seller`, `seller_name`, COUNT(*) AS `sales`, COALESCE(SUM(`commission`), 0) AS `commission`
        FROM `xs_dealership_sales`
        WHERE `dealership_id` = ? AND `seller` IS NOT NULL AND `created_at` >= (NOW() - INTERVAL 7 DAY)
        GROUP BY `seller`, `seller_name`
    ]], { dealer.id }) or {}) do
        stats[row.seller] = row
    end

    local out = {}
    local seen = {}

    for _, member in ipairs(Framework.JobPlayers(dealer.job)) do
        local s = stats[member.citizenid]
        seen[member.citizenid] = true
        out[#out + 1] = {
            name = member.name, grade = member.grade, online = true, onDuty = member.onDuty,
            sales = s and s.sales or 0, commission = s and s.commission or 0,
        }
    end

    for citizenid, s in pairs(stats) do
        if not seen[citizenid] then
            out[#out + 1] = { name = s.seller_name or citizenid, online = false, onDuty = false, sales = s.sales, commission = s.commission }
        end
    end

    table.sort(out, function(a, b)
        if a.sales ~= b.sales then return a.sales > b.sales end
        return (a.name or '') < (b.name or '')
    end)

    return out
end

local function ledger(dealer)
    local rows = MySQL.query.await([[
        SELECT `amount`, `kind`, `note`, `by_name`, UNIX_TIMESTAMP(`created_at`) AS `at`
        FROM `xs_dealership_ledger` WHERE `dealership_id` = ? ORDER BY `id` DESC LIMIT 40
    ]], { dealer.id }) or {}

    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = { amount = row.amount, kind = row.kind, note = row.note, by = row.by_name, at = row.at }
    end
    return out
end

function Office.Data(src, dealer)
    local role = Store.Role(src, dealer)
    if not role.staff then return nil end

    local stock = {}
    for _, car in ipairs(Store.CatalogueFor(dealer)) do
        local entry = Store.Entry(dealer, car.model)
        car.unitCost = Orders.UnitCost(entry)
        stock[#stock + 1] = car
    end

    local data = {
        dealer = { id = dealer.id, name = dealer.name, type = dealer.type, accent = dealer.settings.accent },
        role = role,
        stock = stock,
        orders = Orders.Open(dealer),
        team = team(dealer),
        onDuty = Framework.OnDutyCount(dealer.job),
        order = {
            maxPerOrder = Config.Stock.maxPerOrder,
            maxPending = Config.Stock.maxPendingOrders,
            deliveryMinutes = Config.Stock.deliveryMinutes,
            wholesale = Config.Stock.wholesale,
        },
    }

    if role.isBoss then
        data.sales = salesLog(dealer)
        data.balance = Banking.Balance(dealer)
        data.bank = Banking.name or 'ledger'
        data.ledger = ledger(dealer)
    end

    return data
end

lib.callback.register('XS-Dealerships:server:catalogue', function(src, dealerId)
    local dealer = Store.Get(dealerId)
    if not dealer then return nil end

    local role = Store.Role(src, dealer)
    local methods = Purchase.Methods(dealer)
    local cars = Store.CatalogueFor(dealer)

    if methods.finance then
        for _, car in ipairs(cars) do car.terms = Util.FinanceTerms(car.price) end
    end

    return {
        dealer = Store.Public(dealer),
        cars = cars,
        role = role,
        canShop = Store.CanShop(src, dealer),
        methods = methods,
        testDrives = Config.TestDrive.enabled and dealer.settings.testDrives and dealer.points.test ~= nil,
        testSeconds = Config.TestDrive.seconds,
        staffOnDuty = dealer.mode == 'job' and Framework.OnDutyCount(dealer.job) or 0,
        finance = Finance.List(src),
        money = { cash = Framework.GetMoney(src, 'cash'), bank = Framework.GetMoney(src, 'bank') },
    }
end)
