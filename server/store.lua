Store = { dealers = {}, loaded = false }

local ACCESS = { anyone = true, job = true }

local function defaults(dealer)
    local settings = type(dealer.settings) == 'table' and dealer.settings or {}
    local typeInfo = Util.TypeInfo(dealer.type)

    settings.access = ACCESS[settings.access] and settings.access or 'anyone'
    settings.testDrives = settings.testDrives ~= false
    settings.finance = settings.finance ~= false
    settings.commission = tonumber(settings.commission)
    settings.accent = type(settings.accent) == 'string' and settings.accent:match('^#%x%x%x%x%x%x$') and settings.accent or '#b3121b'

    local blip = type(settings.blip) == 'table' and settings.blip or {}
    settings.blip = {
        show = blip.show ~= false,
        sprite = math.floor(tonumber(blip.sprite) or typeInfo.blip or 326),
        colour = math.floor(tonumber(blip.colour) or 3),
    }

    dealer.settings = settings

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

local function commissionFor(dealer, grade)
    local byGrade = Config.Jobs.gradeCommission or {}
    local rate = byGrade[grade] or byGrade[tostring(grade)] or dealer.settings.commission or Config.Jobs.commission
    return Util.Clamp(rate, 0, 100)
end

function Store.Role(src, dealer)
    local role = { staff = false, grade = 0, canSell = false, canOrder = false, isBoss = false, commission = 0 }
    if dealer.mode ~= 'job' or dealer.job == '' then return role end

    local job, onDuty, grade, isBoss = Framework.GetJob(src)
    if job ~= dealer.job then return role end
    if Config.Jobs.requireDuty and not onDuty then
        role.offDuty = true
        return role
    end

    role.staff = true
    role.grade = grade
    role.canSell = grade >= Config.Jobs.sellGrade
    role.canOrder = grade >= Config.Jobs.orderGrade
    role.isBoss = isBoss or grade >= Config.Jobs.bossGrade
    role.commission = commissionFor(dealer, grade)
    return role
end

function Store.CanShop(src, dealer)
    if dealer.mode ~= 'job' or dealer.settings.access ~= 'job' then return true end
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
