Inventory = { name = nil }

if not IsDuplicityVersion() then return end

do
    local forced = Config.Bridges.inventory
    if forced ~= 'auto' then
        Inventory.name = forced ~= 'none' and forced or nil
    else
        for _, name in ipairs({ 'ox_inventory', 'qs-inventory', 'ps-inventory', 'codem-inventory', 'core_inventory', 'qb-inventory' }) do
            if GetResourceState(name) == 'started' then
                Inventory.name = name
                break
            end
        end
    end
end

function Inventory.Count(src, item)
    if not item or item == '' then return 0 end

    local ok, count = pcall(function()
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:GetItemCount(src, item)
        elseif Inventory.name == 'qs-inventory' then
            return exports['qs-inventory']:GetItemTotalAmount(src, item)
        elseif Inventory.name == 'core_inventory' then
            return exports.core_inventory:getItemCount(src, item)
        end

        local player = Framework.GetPlayer(src)
        local found = player and player.Functions.GetItemByName(item)
        return found and found.amount or 0
    end)

    return ok and (tonumber(count) or 0) or 0
end

function Inventory.Has(src, item)
    return Inventory.Count(src, item) > 0
end

function Inventory.Usable(item, handler)
    if not item or item == '' or Inventory.name == 'ox_inventory' then return end

    local ok, err = pcall(function()
        if Framework.name == 'qbox' then
            exports.qbx_core:CreateUseableItem(item, function(src) handler(src) end)
        elseif Framework.core then
            Framework.core.Functions.CreateUseableItem(item, function(src) handler(src) end)
        end
    end)

    if not ok then
        print(('^1[XS-Dealerships]^0 could not make %s usable: %s'):format(item, tostring(err)))
    end
end
