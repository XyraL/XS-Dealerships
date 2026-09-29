if not IsDuplicityVersion() and type(RegisterNUICallback) == 'function' then
    local _registerNUI = RegisterNUICallback

    RegisterNUICallback = function(name, handler)
        return _registerNUI(name, function(data, cb)
            CreateThread(function()
                handler(data, function(payload, ...)
                    if payload == nil then payload = false end
                    cb(payload, ...)
                end)
            end)
        end)
    end
end

Framework = { name = nil, core = nil }

local function detect()
    local forced = Config.Bridges.framework
    if forced == 'qbox' or forced == 'qbcore' then return forced end
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    return nil
end

Framework.name = detect()

if Framework.name == 'qbcore' then
    Framework.core = exports['qb-core']:GetCoreObject()
elseif not Framework.name then
    print('^1[XS-Dealerships]^0 No supported framework found. Start qbx_core or qb-core before XS-Dealerships.')
end

local function fullName(data)
    local info = data and data.charinfo
    if not info then return nil end
    return (('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function gradeOf(job)
    if not job or not job.grade then return 0 end
    if type(job.grade) == 'table' then return tonumber(job.grade.level) or 0 end
    return tonumber(job.grade) or 0
end

if IsDuplicityVersion() then
    function Framework.GetPlayer(src)
        if Framework.name == 'qbox' then return exports.qbx_core:GetPlayer(src) end
        if Framework.name == 'qbcore' then return Framework.core.Functions.GetPlayer(src) end
        return nil
    end

    function Framework.GetCitizenId(src)
        local player = Framework.GetPlayer(src)
        return player and player.PlayerData and player.PlayerData.citizenid or nil
    end

    function Framework.GetJob(src)
        local player = Framework.GetPlayer(src)
        local job = player and player.PlayerData and player.PlayerData.job
        if not job then return nil, false, 0, false end
        return job.name, job.onduty and true or false, gradeOf(job), job.isboss and true or false
    end

    function Framework.GetName(src)
        local player = Framework.GetPlayer(src)
        return fullName(player and player.PlayerData) or GetPlayerName(src) or 'Unknown'
    end

    function Framework.GetMoney(src, account)
        local player = Framework.GetPlayer(src)
        local money = player and player.PlayerData and player.PlayerData.money
        return math.floor(tonumber(money and money[account or 'cash']) or 0)
    end

    function Framework.AddMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(account or 'bank', math.floor(amount), reason or 'XS-Dealerships') ~= false
    end

    function Framework.RemoveMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        if Framework.GetMoney(src, account) < math.floor(amount) then return false end
        return player.Functions.RemoveMoney(account or 'bank', math.floor(amount), reason or 'XS-Dealerships') ~= false
    end

    function Framework.Players()
        if Framework.name == 'qbox' then return exports.qbx_core:GetQBPlayers() or {} end
        if Framework.core then return Framework.core.Functions.GetQBPlayers() or {} end
        return {}
    end

    function Framework.SourceByCitizenId(citizenid)
        for _, player in pairs(Framework.Players()) do
            local data = player.PlayerData
            if data and data.citizenid == citizenid then return data.source end
        end
        return nil
    end

    function Framework.OnDutyCount(jobName, requireDuty)
        if requireDuty == nil then requireDuty = Config.Jobs.requireDuty end

        local count = 0
        for _, player in pairs(Framework.Players()) do
            local job = player.PlayerData and player.PlayerData.job
            if job and job.name == jobName and (job.onduty or not requireDuty) then
                count = count + 1
            end
        end
        return count
    end

    function Framework.JobPlayers(jobName)
        local out = {}
        for _, player in pairs(Framework.Players()) do
            local data = player.PlayerData
            local job = data and data.job
            if job and job.name == jobName then
                out[#out + 1] = {
                    source = data.source,
                    citizenid = data.citizenid,
                    name = fullName(data) or '',
                    grade = gradeOf(job),
                    onDuty = job.onduty and true or false,
                }
            end
        end
        return out
    end

    local function gradesOf(job)
        local out = {}

        for key, grade in pairs(type(job) == 'table' and type(job.grades) == 'table' and job.grades or {}) do
            local level = tonumber(key)
            if level then
                out[#out + 1] = {
                    level = math.floor(level),
                    name = type(grade) == 'table' and tostring(grade.name or grade.label or level) or tostring(level),
                    boss = type(grade) == 'table' and (grade.isboss == true or grade.isBoss == true) or false,
                }
            end
        end

        table.sort(out, function(a, b) return a.level < b.level end)
        return out
    end

    function Framework.JobList()
        local out = {}

        pcall(function()
            local jobs = Framework.name == 'qbox' and exports.qbx_core:GetJobs()
                or (Framework.core and Framework.core.Shared and Framework.core.Shared.Jobs)

            for name, job in pairs(jobs or {}) do
                out[#out + 1] = {
                    name = name,
                    label = type(job) == 'table' and (job.label or job.name) or name,
                    grades = gradesOf(job),
                }
            end
        end)

        table.sort(out, function(a, b) return (a.label or '') < (b.label or '') end)
        return out
    end

    function Framework.JobExists(jobName)
        if not jobName or jobName == '' then return false end

        local ok, found = pcall(function()
            if Framework.name == 'qbox' then return exports.qbx_core:GetJob(jobName) ~= nil end
            return Framework.core and Framework.core.Shared and Framework.core.Shared.Jobs
                and Framework.core.Shared.Jobs[jobName] ~= nil
        end)

        return ok and found == true
    end

    function Framework.IsAdmin(src)
        local admin = Config.Admin

        if admin.acePermission and admin.acePermission ~= '' and IsPlayerAceAllowed(src, admin.acePermission) then
            return true
        end

        for _, group in ipairs(admin.groups or {}) do
            local ok, allowed = pcall(function()
                if Framework.name == 'qbox' then return exports.qbx_core:HasPermission(src, group) end
                return Framework.core and Framework.core.Functions.HasPermission(src, group)
            end)
            if ok and allowed then return true end
        end

        if #(admin.licenses or {}) > 0 then
            for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
                local license = identifier:match('^license2?:(.+)$')
                if license then
                    for _, allowed in ipairs(admin.licenses) do
                        if license == allowed then return true end
                    end
                end
            end
        end

        return false
    end

    local vehicleCache

    function Framework.Vehicles(refresh)
        if vehicleCache and not refresh then return vehicleCache end

        local list = {}

        pcall(function()
            local source = Framework.name == 'qbox' and exports.qbx_core:GetVehiclesByName()
                or (Framework.core and Framework.core.Shared and Framework.core.Shared.Vehicles)

            for model, data in pairs(source or {}) do
                if type(data) == 'table' then
                    local name = tostring(data.model or model):lower()
                    list[name] = {
                        model = name,
                        name = tostring(data.name or name),
                        brand = tostring(data.brand or ''),
                        price = math.floor(tonumber(data.price) or 0),
                        category = tostring(data.category or 'other'):lower(),
                        type = tostring(data.type or ''),
                    }
                end
            end
        end)

        vehicleCache = list
        return list
    end

    function Framework.Vehicle(model)
        return Framework.Vehicles()[tostring(model or ''):lower()]
    end

    local columns

    local function vehicleColumns()
        if columns then return columns end
        columns = {}

        local rows = MySQL.query.await([[
            SELECT COLUMN_NAME AS name FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_vehicles'
        ]]) or {}

        for _, row in ipairs(rows) do columns[row.name] = true end
        return columns
    end

    function Framework.PlateTaken(plate)
        local found = MySQL.scalar.await('SELECT 1 FROM `player_vehicles` WHERE `plate` = ? LIMIT 1', { plate })
        return found ~= nil
    end

    local function license(src)
        local found
        for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
            if identifier:find('^license:') then return identifier end
            if identifier:find('^license2:') then found = found or identifier end
        end
        return found or ''
    end

    function Framework.GiveVehicle(src, model, plate, props, parked, garage)
        local citizenid = Framework.GetCitizenId(src)
        if not citizenid then return false, 'no character' end

        props = props or {}
        props.plate = plate
        props.model = props.model or joaat(model)

        local ok, err = pcall(function()
            if Framework.name == 'qbox' and GetResourceState('qbx_vehicles') == 'started' then
                local id, failure = exports.qbx_vehicles:CreatePlayerVehicle({
                    model = model,
                    citizenid = citizenid,
                    props = props,
                    garage = parked and garage or nil,
                })
                if not id then error(failure and (failure.message or failure.code) or 'qbx_vehicles refused the vehicle') end
                return
            end

            MySQL.insert.await([[
                INSERT INTO `player_vehicles` (`license`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `garage`, `state`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                license(src), citizenid, model, tostring(joaat(model)), json.encode(props), plate,
                garage or Config.Purchase.garage, parked and 1 or 0,
            })
        end)

        if not ok then return false, tostring(err) end

        local cols = vehicleColumns()
        if cols.in_garage then
            MySQL.update.await('UPDATE `player_vehicles` SET `in_garage` = ? WHERE `plate` = ?', { parked and 1 or 0, plate })
        end
        if parked and cols.garage_id then
            MySQL.update.await('UPDATE `player_vehicles` SET `garage_id` = ? WHERE `plate` = ?', { garage, plate })
        end

        return true
    end

    function Framework.ParkOwnedVehicle(plate, garage)
        local cols = vehicleColumns()
        local sets, values = {}, {}

        local function put(column, value)
            if not cols[column] then return end
            sets[#sets + 1] = ('`%s` = ?'):format(column)
            values[#values + 1] = value
        end

        put('state', 1)
        put('garage', garage)
        put('in_garage', 1)
        put('garage_id', garage)

        if #sets == 0 then return false end

        values[#values + 1] = plate
        MySQL.update.await(('UPDATE `player_vehicles` SET %s WHERE `plate` = ?'):format(table.concat(sets, ', ')), values)
        return true
    end

    function Framework.OwnedVehicleRow(plate, citizenid)
        return MySQL.single.await('SELECT * FROM `player_vehicles` WHERE `plate` = ? AND `citizenid` = ? LIMIT 1',
            { plate, citizenid })
    end

    function Framework.RemoveOwnedVehicle(plate, citizenid)
        local changed = MySQL.update.await('DELETE FROM `player_vehicles` WHERE `plate` = ? AND `citizenid` = ?',
            { plate, citizenid })
        return (tonumber(changed) or 0) > 0
    end

    local RESTORE = {
        'license', 'citizenid', 'vehicle', 'hash', 'mods', 'plate', 'fakeplate', 'fuel', 'engine',
        'body', 'drivingdistance', 'status', 'glovebox', 'trunk', 'nickname', 'mileage',
    }

    function Framework.RestoreOwnedVehicle(row, garage)
        if type(row) ~= 'table' or not row.plate then return false end

        local cols = vehicleColumns()
        local names, marks, values = {}, {}, {}

        local function put(key, value)
            if not cols[key] or value == nil then return end
            names[#names + 1] = ('`%s`'):format(key)
            marks[#marks + 1] = '?'
            values[#values + 1] = value
        end

        for _, key in ipairs(RESTORE) do put(key, row[key]) end
        put('garage', garage)
        put('state', 1)
        put('in_garage', 1)
        put('garage_id', garage)

        local ok = pcall(function()
            MySQL.insert.await(('INSERT INTO `player_vehicles` (%s) VALUES (%s)'):format(
                table.concat(names, ', '), table.concat(marks, ', ')), values)
        end)

        return ok
    end

    function Framework.Notify(src, message, kind)
        if Config.Notify.style == 'framework' then
            if Framework.name == 'qbox' then
                exports.qbx_core:Notify(src, message, kind or 'inform')
            elseif Framework.core then
                TriggerClientEvent('QBCore:Notify', src, message, kind == 'error' and 'error' or 'success')
            end
            return
        end

        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Dealership',
            description = message,
            type = kind or 'inform',
            position = Config.Notify.position,
        })
    end
else
    function Framework.GetPlayerData()
        if Framework.name == 'qbox' then return exports.qbx_core:GetPlayerData() end
        if Framework.name == 'qbcore' then return Framework.core.Functions.GetPlayerData() end
        return nil
    end

    function Framework.GetJob()
        local data = Framework.GetPlayerData()
        local job = data and data.job
        if not job then return nil, false, 0 end
        return job.name, job.onduty and true or false, gradeOf(job)
    end

    function Framework.GetCitizenId()
        local data = Framework.GetPlayerData()
        return data and data.citizenid or nil
    end

    function Framework.Notify(message, kind)
        if Config.Notify.style == 'framework' then
            if Framework.name == 'qbox' then
                exports.qbx_core:Notify(message, kind or 'inform')
                return
            end
            TriggerEvent('QBCore:Notify', message, kind == 'error' and 'error' or 'success')
            return
        end

        lib.notify({
            title = 'Dealership',
            description = message,
            type = kind or 'inform',
            position = Config.Notify.position,
        })
    end
end
