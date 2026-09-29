local function start()
    if not DB.Install() then
        print('^1[XS-Dealerships]^0 The database tables could not be set up, so no dealership will load.')
        return
    end

    Store.Load()
    Orders.Load()
    Store.Broadcast()

    local count = 0
    for _ in pairs(Store.dealers) do count = count + 1 end

    print(('[XS-Dealerships] %d dealership%s · framework %s · banking %s · keys %s · %d vehicles in the framework list'):format(
        count, count == 1 and '' or 's', Framework.name or 'NONE', Banking.name or 'own ledger', Keys.name or 'none',
        (function() local n = 0 for _ in pairs(Framework.Vehicles(true)) do n = n + 1 end return n end)()))
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()

        Wait(1500)
        start()
    end)
end)

RegisterNetEvent('XS-Dealerships:server:ready', function()
    local src = source
    if Store.loaded then Store.Broadcast(src) end
end)

RegisterCommand(Config.Admin.command, function(src)
    if src == 0 then
        print('[XS-Dealerships] The creator opens in game.')
        return
    end

    if not Framework.IsAdmin(src) then
        Framework.Notify(src, ('You need the %s ace (or an admin group in Config.Admin) to use the creator.')
            :format(Config.Admin.acePermission), 'error')
        return
    end

    TriggerClientEvent('XS-Dealerships:client:creator', src)
end, false)

RegisterCommand('dealerdiag', function(src)
    local lines = {
        ('framework: %s'):format(Framework.name or 'NONE FOUND'),
        ('banking: %s'):format(Banking.name or 'own ledger'),
        ('keys (server): %s'):format(Keys.name or 'none'),
        ('inventory: %s · tablet item: %s'):format(Inventory.name or 'none', Config.Tablet.item ~= '' and Config.Tablet.item or 'none, office at the desk'),
        ('dealerships loaded: %s'):format(Store.loaded and 'yes' or 'NO'),
    }

    if src ~= 0 then
        local job, onDuty, grade = Framework.GetJob(src)
        lines[#lines + 1] = ('your job: %s, grade %s, %s'):format(job or 'none', grade, onDuty and 'on duty' or 'off duty')
        lines[#lines + 1] = ('creator access: %s'):format(Framework.IsAdmin(src) and 'yes' or 'no')
        if Config.Tablet.item ~= '' then
            lines[#lines + 1] = ('carrying the dealer tablet: %s'):format(Inventory.Has(src, Config.Tablet.item) and 'yes' or 'no')
        end

        local coords = GetEntityCoords(GetPlayerPed(src))
        for _, dealer in pairs(Store.dealers) do
            local role = Store.Role(src, dealer)
            local at = dealer.points.desk and ('%.0fm from the desk'):format(Util.Distance(coords, dealer.points.desk)) or 'no desk placed'
            lines[#lines + 1] = ('#%d %s (%s%s): %s, %d cars, %d spots%s'):format(
                dealer.id, dealer.name, dealer.mode, dealer.job ~= '' and (' · ' .. dealer.job) or '', at,
                (function() local n = 0 for _ in pairs(dealer.catalogue) do n = n + 1 end return n end)(),
                #dealer.points.spots, role.staff and ' · you are staff' or '')
        end

        TriggerClientEvent('XS-Dealerships:client:diag', src, lines)
        return
    end

    for _, line in ipairs(lines) do print('[XS-Dealerships] ' .. line) end
end, false)
