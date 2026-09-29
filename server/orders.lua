Orders = {}

local pending = {}
local nextArrival = math.huge

local function bump(dealerId, model, quantity)
    pending[dealerId] = pending[dealerId] or {}
    local now = (pending[dealerId][model] or 0) + quantity
    pending[dealerId][model] = now > 0 and now or nil
end

local function findNextArrival()
    local soonest = MySQL.scalar.await('SELECT MIN(`arrives_at`) FROM `xs_dealership_orders` WHERE `delivered` = 0')
    nextArrival = tonumber(soonest) or math.huge
end

function Orders.Pending(dealerId, model)
    return pending[dealerId] and pending[dealerId][model] or 0
end

function Orders.Load()
    pending = {}
    for _, row in ipairs(MySQL.query.await('SELECT `dealership_id`, `model`, `quantity` FROM `xs_dealership_orders` WHERE `delivered` = 0') or {}) do
        bump(row.dealership_id, row.model, row.quantity)
    end
    findNextArrival()
end

function Orders.Open(dealer)
    local rows = MySQL.query.await([[
        SELECT `id`, `model`, `quantity`, `cost`, `ordered_name`, `arrives_at` FROM `xs_dealership_orders`
        WHERE `dealership_id` = ? AND `delivered` = 0 ORDER BY `arrives_at`
    ]], { dealer.id }) or {}

    local now = os.time()
    local out = {}

    for _, row in ipairs(rows) do
        local info = Framework.Vehicle(row.model) or {}
        out[#out + 1] = {
            id = row.id,
            model = row.model,
            name = info.name or row.model,
            quantity = row.quantity,
            cost = row.cost,
            by = row.ordered_name,
            arrivesIn = math.max(0, row.arrives_at - now),
        }
    end

    return out
end

function Orders.UnitCost(dealer, entry)
    return math.floor(entry.price * Util.Clamp(dealer.settings.stock.wholesale, 0, 1000) / 100)
end

lib.callback.register('XS-Dealerships:server:order', function(src, dealerId, model, quantity)
    local dealer = Store.Get(dealerId)
    if not dealer or dealer.mode ~= 'job' then return false, 'Only job-run dealerships order stock.' end

    local role = Store.Role(src, dealer)
    if not role.canOrder then return false, 'Your grade cannot order stock.' end

    local allowed, why = Tablet.CanUse(src, dealer)
    if not allowed then return false, why end

    model = tostring(model or ''):lower()
    local entry = Store.Entry(dealer, model)
    if not entry then return false, 'This dealership does not sell that car.' end
    if entry.stock < 0 then return false, 'That car is never out of stock here.' end

    local stock = dealer.settings.stock
    quantity = math.floor(Util.Clamp(quantity, 1, stock.maxPerOrder))

    local open = MySQL.scalar.await('SELECT COUNT(*) FROM `xs_dealership_orders` WHERE `dealership_id` = ? AND `delivered` = 0', { dealer.id })
    if (tonumber(open) or 0) >= stock.maxPending then
        return false, ('Wait for one of the %d orders already on the way.'):format(open)
    end

    local cost = Orders.UnitCost(dealer, entry) * quantity
    local info = Framework.Vehicle(model) or {}
    local name = Framework.GetName(src)

    if not Banking.Remove(dealer, cost, ('Ordered %dx %s'):format(quantity, info.name or model), name, 'order') then
        return false, ('The business account cannot cover %s.'):format(Util.Money(cost))
    end

    local arrives = os.time() + math.floor(math.max(0, stock.deliveryMinutes) * 60)

    MySQL.insert.await([[
        INSERT INTO `xs_dealership_orders` (`dealership_id`, `model`, `quantity`, `cost`, `ordered_by`, `ordered_name`, `arrives_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { dealer.id, model, quantity, cost, Framework.GetCitizenId(src) or '', name, arrives })

    bump(dealer.id, model, quantity)
    nextArrival = math.min(nextArrival, arrives)
    return true, Office.Data(src, dealer)
end)

local function notifyStaff(dealer, message)
    for _, member in ipairs(Framework.JobPlayers(dealer.job)) do
        if member.onDuty or not dealer.settings.staff.requireDuty then
            Framework.Notify(member.source, message, 'success')
        end
    end
end

local function deliverDue()
    local due = MySQL.query.await('SELECT * FROM `xs_dealership_orders` WHERE `delivered` = 0 AND `arrives_at` <= ?',
        { os.time() }) or {}

    for _, row in ipairs(due) do
        local changed = MySQL.update.await('UPDATE `xs_dealership_orders` SET `delivered` = 1 WHERE `id` = ? AND `delivered` = 0', { row.id })

        if (tonumber(changed) or 0) > 0 then
            bump(row.dealership_id, row.model, -row.quantity)

            local dealer = Store.Get(row.dealership_id)
            if dealer then
                Store.AddStock(dealer, row.model, row.quantity)
                local info = Framework.Vehicle(row.model) or {}
                notifyStaff(dealer, ('Delivery in at %s: %dx %s.'):format(dealer.name, row.quantity, info.name or row.model))
            end
        end
    end

    findNextArrival()
end

CreateThread(function()
    while true do
        Wait(5000)

        if DB.ready and os.time() >= nextArrival then
            local ok, err = pcall(deliverDue)
            if not ok then
                print(('^1[XS-Dealerships]^0 order delivery failed: %s'):format(tostring(err)))
                nextArrival = os.time() + 60
            end
        end
    end
end)
