Tablet = {}

function Tablet.CanUse(src, dealer)
    local item = Config.Tablet.item
    if item and item ~= '' then
        if Inventory.Has(src, item) then return true end
        return false, 'You need the dealer tablet on you.'
    end

    if dealer and Purchase.Near(src, dealer) then return true end
    return false, 'Use the office at the sales desk.'
end

local function staffAt(src)
    local out, offDuty = {}, false

    for _, dealer in pairs(Store.dealers) do
        if dealer.mode == 'job' then
            local role = Store.Role(src, dealer)
            if role.staff then
                out[#out + 1] = dealer
            elseif role.offDuty then
                offDuty = true
            end
        end
    end

    table.sort(out, function(a, b) return a.id < b.id end)
    return out, offDuty
end

lib.callback.register('XS-Dealerships:server:tablet', function(src, dealerId)
    local dealers, offDuty = staffAt(src)

    if #dealers == 0 then
        return false, offDuty and 'Go on duty to use the dealer tablet.' or 'You do not work at a dealership.'
    end

    local chosen = dealers[1]
    for _, dealer in ipairs(dealers) do
        if dealer.id == tonumber(dealerId) then chosen = dealer end
    end

    local allowed, why = Tablet.CanUse(src, chosen)
    if not allowed then return false, why end

    local list = {}
    for _, dealer in ipairs(dealers) do
        list[#list + 1] = { id = dealer.id, name = dealer.name, accent = dealer.settings.accent }
    end

    return true, { dealers = list, data = Office.Data(src, chosen) }
end)

lib.callback.register('XS-Dealerships:server:tabletSwap', function(src, dealerId, spotId, model)
    local dealer = Store.Get(dealerId)
    if not dealer or dealer.mode ~= 'job' then return false, 'That dealership no longer exists.' end

    if not Store.Role(src, dealer).staff then return false, 'Only staff can change the display.' end

    local allowed, why = Tablet.CanUse(src, dealer)
    if not allowed then return false, why end

    local ok, err = Showcase.Set(dealer, spotId, model)
    if not ok then return false, err end

    return true, Office.Data(src, dealer)
end)

lib.callback.register('XS-Dealerships:server:moveMoney', function(src, dealerId, direction, amount)
    local dealer = Store.Get(dealerId)
    if not dealer or dealer.mode ~= 'job' then return false, 'That dealership no longer exists.' end

    local role = Store.Role(src, dealer)
    if not role.isBoss then return false, 'Only the boss can move money.' end

    local allowed, why = Tablet.CanUse(src, dealer)
    if not allowed then return false, why end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'Enter an amount.' end

    local name = Framework.GetName(src)

    if direction == 'withdraw' then
        if not Banking.Remove(dealer, amount, 'Withdrawn by the boss', name, 'withdraw') then
            return false, ('The account does not have %s.'):format(Util.Money(amount))
        end
        Framework.AddMoney(src, 'bank', amount, ('Withdrew from %s'):format(dealer.name))
    elseif direction == 'deposit' then
        if not Framework.RemoveMoney(src, 'bank', amount, ('Paid into %s'):format(dealer.name)) then
            return false, ('You need %s in the bank.'):format(Util.Money(amount))
        end
        if not Banking.Add(dealer, amount, 'Paid in by the boss', name, 'deposit') then
            Framework.AddMoney(src, 'bank', amount, 'Dealership refund')
            return false, 'The account would not take it. You have not been charged.'
        end
    else
        return false, 'Deposit or withdraw?'
    end

    return true, Office.Data(src, dealer)
end)

local function target(inventory)
    if type(inventory) == 'table' then return inventory.id end
    return tonumber(inventory)
end

if Config.Tablet.item ~= '' then
    exports('openTablet', function(_, _, inventory)
        local src = target(inventory)
        if src then TriggerClientEvent('XS-Dealerships:client:openTablet', src) end
    end)
end

CreateThread(function()
    Wait(1500)
    Inventory.Usable(Config.Tablet.item, function(src)
        TriggerClientEvent('XS-Dealerships:client:openTablet', src)
    end)
end)
