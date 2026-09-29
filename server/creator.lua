local function creatorData()
    local dealers = {}
    for _, dealer in pairs(Store.dealers) do dealers[#dealers + 1] = Store.Full(dealer) end
    table.sort(dealers, function(a, b) return a.id < b.id end)

    local vehicles = {}
    for _, info in pairs(Framework.Vehicles()) do vehicles[#vehicles + 1] = info end
    table.sort(vehicles, function(a, b) return a.name < b.name end)

    local types = {}
    for _, entry in ipairs(Config.Types) do
        types[#types + 1] = { id = entry.id, label = entry.label, blip = entry.blip, categories = entry.categories }
    end

    return {
        dealers = dealers,
        vehicles = vehicles,
        jobs = Framework.JobList(),
        types = types,
        jobStock = Config.Stock.jobDefault,
        commission = Config.Jobs.commission,
    }
end

lib.callback.register('XS-Dealerships:server:creator', function(src)
    if not Framework.IsAdmin(src) then return nil end
    return creatorData()
end)

lib.callback.register('XS-Dealerships:server:saveDealer', function(src, draft)
    if not Framework.IsAdmin(src) then return false, 'You cannot use the creator.' end

    local ok, result = Store.Save(src, draft)
    if not ok then return false, result end

    return true, { id = result, data = creatorData() }
end)

lib.callback.register('XS-Dealerships:server:deleteDealer', function(src, id)
    if not Framework.IsAdmin(src) then return false, 'You cannot use the creator.' end
    if not Store.Delete(id) then return false, 'That dealership was already gone.' end
    return true, creatorData()
end)
