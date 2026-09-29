Store = { dealers = {}, loaded = false }

local CUSTOMER_ACTIONS = { 'buy', 'swap', 'test' }

local function flag(value, fallback)
    if value == nil then return fallback == true end
    return value == true or value == 1
end

local function number(value, fallback, low, high)
    local n = tonumber(value) or tonumber(fallback) or low
    if n < low then return low end
    if n > high then return high end
    return n
end

local function whole(value, fallback, low, high)
    return math.floor(number(value, fallback, low, high))
end

local function first(...)
    for i = 1, select('#', ...) do
        local value = select(i, ...)
        if value ~= nil then return value end
    end
    return nil
end

local function section(settings, key)
    return type(settings[key]) == 'table' and settings[key] or {}
end

local function word(value, fallback, max)
    local text = tostring(value or ''):gsub('[^%w_%-]', '')
    if text == '' then text = tostring(fallback or '') end
    return text:sub(1, max)
end

local function plateText(value, fallback)
    local text = tostring(value or ''):upper():gsub('[^%w ]', '')
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then text = tostring(fallback or 'FOR SALE') end
    return text:sub(1, 8)
end

local function gradeRates(rates)
    local out = {}
    if type(rates) ~= 'table' then return out end

    for grade, rate in pairs(rates) do
        local level, value = tonumber(grade), tonumber(rate)
        if level and value then out[tostring(math.floor(level))] = Util.Clamp(value, 0, 100) end
    end

    return out
end

local function settingsFor(dealer)
    local settings = type(dealer.settings) == 'table' and dealer.settings or {}
    local typeInfo = Util.TypeInfo(dealer.type)
    local out = {}

    out.accent = type(settings.accent) == 'string' and settings.accent:match('^#%x%x%x%x%x%x$') and settings.accent or '#b3121b'

    local blip = section(settings, 'blip')
    out.blip = {
        show = flag(blip.show, true),
        sprite = whole(blip.sprite, typeInfo.blip or 326, 0, 1000),
        colour = whole(blip.colour, 3, 0, 85),
    }

    local legacyAccess
    if settings.access == 'job' then legacyAccess = false elseif settings.access == 'anyone' then legacyAccess = true end

    local customers = section(settings, 'customers')
    out.customers = {}
    for _, action in ipairs(CUSTOMER_ACTIONS) do
        out.customers[action] = flag(first(customers[action], legacyAccess), true)
    end

    local purchase = Config.Purchase
    local sale = section(settings, 'sale')
    out.sale = {
        cash = flag(sale.cash, purchase.cash),
        bank = flag(sale.bank, purchase.bank),
        deliver = (sale.deliver == 'spawn' or sale.deliver == 'garage') and sale.deliver
            or (purchase.deliver == 'garage' and 'garage' or 'spawn'),
        garage = word(sale.garage, purchase.garage, 64),
        warp = flag(sale.warp, purchase.warpIntoVehicle),
    }

    local drive = Config.TestDrive
    local test = section(settings, 'test')
    out.test = {
        enabled = flag(first(test.enabled, settings.testDrives), drive.enabled),
        seconds = whole(test.seconds, drive.seconds, 10, 1800),
        private = flag(test.private, drive.privateWorld),
        returnToStart = flag(test.returnToStart, drive.returnToStart),
    }

    local legacyFinance
    if type(settings.finance) == 'boolean' then legacyFinance = settings.finance end

    local terms = Config.Finance
    local finance = section(settings, 'finance')
    out.finance = {
        enabled = flag(first(finance.enabled, legacyFinance), terms.enabled),
        downPayment = number(finance.downPayment, terms.downPayment, 0, 100),
        payments = whole(finance.payments, terms.payments, 1, 120),
        interest = number(finance.interest, terms.interest, 0, 1000),
        intervalHours = number(finance.intervalHours, terms.intervalHours, 0.1, 720),
        missedLimit = whole(finance.missedLimit, terms.missedLimit, 1, 50),
        repossess = (finance.repossess == 'remove' or finance.repossess == 'hold') and finance.repossess
            or (terms.repossess == 'hold' and 'hold' or 'remove'),
        holdDays = whole(finance.holdDays, terms.holdDays, 1, 90),
        returnToStock = flag(finance.returnToStock, terms.returnToStock),
    }

    local jobs = Config.Jobs
    local staff = section(settings, 'staff')
    out.staff = {
        commission = number(first(staff.commission, settings.commission), jobs.commission, 0, 100),
        gradeCommission = gradeRates(first(staff.gradeCommission, jobs.gradeCommission)),
        sellGrade = whole(staff.sellGrade, jobs.sellGrade, 0, 100),
        orderGrade = whole(staff.orderGrade, jobs.orderGrade, 0, 100),
        bossGrade = whole(staff.bossGrade, jobs.bossGrade, 0, 100),
        requireDuty = flag(staff.requireDuty, jobs.requireDuty),
    }

    local defaults = Config.Stock
    local stock = section(settings, 'stock')
    out.stock = {
        start = whole(stock.start, defaults.jobDefault, -1, 9999),
        wholesale = number(stock.wholesale, defaults.wholesale, 0, 1000),
        deliveryMinutes = number(stock.deliveryMinutes, defaults.deliveryMinutes, 0, 10080),
        maxPerOrder = whole(stock.maxPerOrder, defaults.maxPerOrder, 1, 999),
        maxPending = whole(stock.maxPending, defaults.maxPendingOrders, 1, 99),
    }

    local showcase = section(settings, 'showcase')
    out.showcase = {
        resetMinutes = number(showcase.resetMinutes, Config.Showcase.resetMinutes, 0, 1440),
        plate = plateText(showcase.plate, Config.Showcase.plate),
    }

    return out
end

local function defaults(dealer)
    dealer.settings = settingsFor(dealer)

    local points = type(dealer.points) == 'table' and dealer.points or {}
    local spots = {}

    for _, spot in ipairs(points.spots or {}) do
        local point = Util.Point(spot)
        if point and type(spot.model) == 'string' and spot.model ~= '' then
            point.id = tostring(spot.id or #spots + 1)
            point.model = spot.model:lower()
            spots[#spots + 1] = point
        end
    end

    dealer.points = {
        desk = Util.Point(points.desk),
        buy = Util.Point(points.buy),
        test = Util.Point(points.test),
        spots = spots,
    }

    return dealer
end

function Store.Load()
    local dealers = {}

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `xs_dealerships`') or {}) do
        local dealer = defaults({
            id = row.id,
            name = row.name,
            type = row.type,
            mode = row.mode == 'job' and 'job' or 'npc',
            job = row.job or '',
            settings = Util.Decode(row.settings),
            points = Util.Decode(row.points),
        })
        dealer.catalogue = {}
        dealers[dealer.id] = dealer
    end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `xs_dealership_stock`') or {}) do
        local dealer = dealers[row.dealership_id]
        if dealer then
            dealer.catalogue[row.model] = { price = math.floor(row.price), stock = math.floor(row.stock) }
        end
    end

    Store.dealers = dealers
    Store.loaded = true
end

function Store.Get(id)
    return Store.dealers[tonumber(id) or -1]
end

function Store.Public(dealer)
    return {
        id = dealer.id,
        name = dealer.name,
        type = dealer.type,
        mode = dealer.mode,
        job = dealer.job,
        settings = dealer.settings,
        points = dealer.points,
        showcase = Showcase.State(dealer),
    }
end

function Store.PublicAll()
    local out = {}
    for _, dealer in pairs(Store.dealers) do out[#out + 1] = Store.Public(dealer) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Store.Broadcast(target)
    TriggerClientEvent('XS-Dealerships:client:dealers', target or -1, Store.PublicAll())
end

function Store.DefaultSettings()
    return settingsFor({ type = Config.Types[1] and Config.Types[1].id or 'cars', mode = 'npc' })
end

local function commissionFor(dealer, grade)
    local staff = dealer.settings.staff
    return Util.Clamp(staff.gradeCommission[tostring(grade)] or staff.commission, 0, 100)
end

function Store.Role(src, dealer)
    local role = { staff = false, grade = 0, canSell = false, canOrder = false, isBoss = false, commission = 0 }
    if dealer.mode ~= 'job' or dealer.job == '' then return role end

    local job, onDuty, grade, isBoss = Framework.GetJob(src)
    if job ~= dealer.job then return role end

    local staff = dealer.settings.staff
    if staff.requireDuty and not onDuty then
        role.offDuty = true
        return role
    end

    role.staff = true
    role.grade = grade
    role.canSell = grade >= staff.sellGrade
    role.canOrder = grade >= staff.orderGrade
    role.isBoss = isBoss or grade >= staff.bossGrade
    role.commission = commissionFor(dealer, grade)
    return role
end

function Store.Can(src, dealer, action)
    if dealer.mode ~= 'job' or dealer.job == '' then return true end
    if dealer.settings.customers[action] then return true end
    return Store.Role(src, dealer).staff
end

function Store.Entry(dealer, model)
    return dealer and dealer.catalogue[tostring(model or ''):lower()] or nil
end

function Store.CatalogueFor(dealer)
    local vehicles = Framework.Vehicles()
    local out = {}

    for model, entry in pairs(dealer.catalogue) do
        local info = vehicles[model] or {}
        out[#out + 1] = {
            model = model,
            name = info.name or model,
            brand = info.brand or '',
            category = info.category or 'other',
            price = entry.price,
            stock = entry.stock,
            onOrder = Orders.Pending(dealer.id, model),
        }
    end

    table.sort(out, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        return a.price < b.price
    end)

    return out
end

function Store.Reserve(dealer, model)
    local entry = Store.Entry(dealer, model)
    if not entry then return false end
    if entry.stock < 0 then return true end

    local changed = MySQL.update.await([[
        UPDATE `xs_dealership_stock` SET `stock` = `stock` - 1
        WHERE `dealership_id` = ? AND `model` = ? AND `stock` > 0
    ]], { dealer.id, model })

    if (tonumber(changed) or 0) < 1 then
        entry.stock = 0
        return false
    end

    entry.stock = entry.stock - 1
    return true
end

function Store.AddStock(dealer, model, amount)
    local entry = Store.Entry(dealer, model)
    if not entry or entry.stock < 0 then return end

    MySQL.update.await([[
        UPDATE `xs_dealership_stock` SET `stock` = `stock` + ?
        WHERE `dealership_id` = ? AND `model` = ? AND `stock` >= 0
    ]], { amount, dealer.id, model })

    entry.stock = entry.stock + amount
end

local function clean(text, max)
    text = tostring(text or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return text:sub(1, max)
end

function Store.Save(src, draft)
    if type(draft) ~= 'table' then return false, 'Nothing to save.' end

    local name = clean(draft.name, 64)
    if name == '' then return false, 'Give the dealership a name.' end

    local mode = draft.mode == 'job' and 'job' or 'npc'
    local job = mode == 'job' and clean(draft.job, 64) or ''
    if mode == 'job' and not Framework.JobExists(job) then
        return false, ('There is no job called "%s".'):format(job)
    end

    local dealer = defaults({
        id = tonumber(draft.id),
        name = name,
        type = Util.TypeInfo(draft.type).id,
        mode = mode,
        job = job,
        settings = draft.settings,
        points = draft.points,
    })

    local vehicles = Framework.Vehicles()
    local catalogue = {}

    for _, item in ipairs(type(draft.catalogue) == 'table' and draft.catalogue or {}) do
        local model = tostring(item.model or ''):lower()
        if model ~= '' and not catalogue[model] then
            local info = vehicles[model]
            local price = math.floor(tonumber(item.price) or (info and info.price) or 0)
            local stock = math.floor(tonumber(item.stock) or -1)
            if stock < -1 then stock = -1 end
            if price >= 0 then catalogue[model] = { price = price, stock = stock } end
        end
    end

    for _, spot in ipairs(dealer.points.spots) do
        if not catalogue[spot.model] then
            return false, ('A showcase spot shows "%s", which this dealership does not sell.'):format(spot.model)
        end
    end

    local settings = json.encode(dealer.settings)
    local points = json.encode(dealer.points)

    if dealer.id and Store.dealers[dealer.id] then
        MySQL.update.await([[
            UPDATE `xs_dealerships` SET `name` = ?, `type` = ?, `mode` = ?, `job` = ?, `settings` = ?, `points` = ?
            WHERE `id` = ?
        ]], { dealer.name, dealer.type, dealer.mode, dealer.job, settings, points, dealer.id })
    else
        dealer.id = MySQL.insert.await([[
            INSERT INTO `xs_dealerships` (`name`, `type`, `mode`, `job`, `settings`, `points`, `created_by`)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], { dealer.name, dealer.type, dealer.mode, dealer.job, settings, points, Framework.GetCitizenId(src) or '' })
        if not dealer.id then return false, 'The database would not take it.' end
    end

    MySQL.update.await('DELETE FROM `xs_dealership_stock` WHERE `dealership_id` = ?', { dealer.id })

    local rows = {}
    for model, entry in pairs(catalogue) do
        rows[#rows + 1] = { dealer.id, model, entry.price, entry.stock }
    end
    if #rows > 0 then
        MySQL.prepare.await('INSERT INTO `xs_dealership_stock` (`dealership_id`, `model`, `price`, `stock`) VALUES (?, ?, ?, ?)', rows)
    end

    dealer.catalogue = catalogue
    Store.dealers[dealer.id] = dealer
    Showcase.Reset(dealer)
    Store.Broadcast()

    return true, dealer.id
end

function Store.Delete(id)
    local dealer = Store.Get(id)
    if not dealer then return false end

    MySQL.update.await('DELETE FROM `xs_dealerships` WHERE `id` = ?', { dealer.id })
    MySQL.update.await('DELETE FROM `xs_dealership_stock` WHERE `dealership_id` = ?', { dealer.id })
    MySQL.update.await('DELETE FROM `xs_dealership_orders` WHERE `dealership_id` = ? AND `delivered` = 0', { dealer.id })

    Store.dealers[dealer.id] = nil
    Showcase.Forget(dealer.id)
    Store.Broadcast()
    return true
end

function Store.Full(dealer)
    local data = Store.Public(dealer)
    data.catalogue = {}
    for model, entry in pairs(dealer.catalogue) do
        data.catalogue[#data.catalogue + 1] = { model = model, price = entry.price, stock = entry.stock }
    end
    table.sort(data.catalogue, function(a, b) return a.model < b.model end)
    return data
end
