Banking = { name = nil }

if not IsDuplicityVersion() then return end

local SUPPORTED = {
    'Renewed-Banking', 'qb-banking', 'okokBanking', 'tgg-banking', 'wasabi_banking', 'fd_banking', 'qb-management',
}

local function detect()
    local forced = Config.Bridges.banking
    if forced == 'none' then return nil end
    if forced ~= 'auto' then return forced end

    for _, resource in ipairs(SUPPORTED) do
        if GetResourceState(resource) == 'started' then return resource end
    end

    return nil
end

Banking.name = detect()

function Banking.LedgerOnly()
    return Banking.name == nil
end

local function account(dealer)
    return dealer.job ~= '' and dealer.job or ('xsdealer_' .. dealer.id)
end

local function ensureAccount(dealer, name)
    if Banking.name == 'Renewed-Banking' then
        if exports['Renewed-Banking']:getAccountMoney(name) == false then
            exports['Renewed-Banking']:CreateJobAccount({ name = name, label = dealer.name or name }, 0)
        end
    elseif Banking.name == 'qb-banking' then
        if not exports['qb-banking']:GetAccount(name) then
            exports['qb-banking']:CreateJobAccount(name, 0)
        end
    elseif Banking.name == 'tgg-banking' then
        if exports['tgg-banking']:GetSocietyAccountMoney(name) == nil then
            exports['tgg-banking']:CreateBusinessAccount(name, 0, dealer.name or name)
        end
    end
end

local function number(value)
    if type(value) == 'table' then
        value = value.balance or value.amount or value.money or value.account_balance
    end
    return math.floor(tonumber(value) or 0)
end

local function ledger(dealer, amount, kind, note, byName)
    MySQL.insert.await([[
        INSERT INTO `xs_dealership_ledger` (`dealership_id`, `amount`, `kind`, `note`, `by_name`)
        VALUES (?, ?, ?, ?, ?)
    ]], { dealer.id, math.floor(amount), kind or 'other', note or '', byName or '' })
end

function Banking.Balance(dealer)
    if Banking.LedgerOnly() then
        local total = MySQL.scalar.await(
            'SELECT COALESCE(SUM(`amount`), 0) FROM `xs_dealership_ledger` WHERE `dealership_id` = ?', { dealer.id })
        return math.floor(tonumber(total) or 0)
    end

    local name = account(dealer)
    local balance = 0

    pcall(function()
        if Banking.name == 'Renewed-Banking' then
            balance = exports['Renewed-Banking']:getAccountMoney(name)
        elseif Banking.name == 'qb-banking' then
            balance = exports['qb-banking']:GetAccountBalance(name)
        elseif Banking.name == 'okokBanking' then
            balance = exports.okokBanking:GetAccount(name)
        elseif Banking.name == 'tgg-banking' then
            balance = exports['tgg-banking']:GetSocietyAccountMoney(name)
        elseif Banking.name == 'wasabi_banking' then
            balance = exports.wasabi_banking:GetAccountBalance(name, 'society')
        elseif Banking.name == 'fd_banking' then
            balance = exports.fd_banking:GetAccount(name)
        elseif Banking.name == 'qb-management' then
            balance = exports['qb-management']:GetAccount(name)
        end
    end)

    return number(balance)
end

local ANSWERS = {
    ['Renewed-Banking'] = true, ['qb-banking'] = true, ['tgg-banking'] = true, ['wasabi_banking'] = true,
}

local function moved(ok, result)
    if not ok then return false end
    if ANSWERS[Banking.name] then return result ~= false and result ~= nil end
    return true
end

function Banking.Add(dealer, amount, note, byName, kind)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    if Banking.LedgerOnly() then
        ledger(dealer, amount, kind or 'income', note, byName)
        return true
    end

    local name = account(dealer)
    local ok = moved(pcall(function()
        ensureAccount(dealer, name)

        if Banking.name == 'Renewed-Banking' then
            return exports['Renewed-Banking']:addAccountMoney(name, amount)
        elseif Banking.name == 'qb-banking' then
            return exports['qb-banking']:AddMoney(name, amount, note)
        elseif Banking.name == 'okokBanking' then
            return exports.okokBanking:AddMoney(name, amount)
        elseif Banking.name == 'tgg-banking' then
            return exports['tgg-banking']:AddSocietyMoney(name, amount)
        elseif Banking.name == 'wasabi_banking' then
            return exports.wasabi_banking:AddMoney('society', name, amount)
        elseif Banking.name == 'fd_banking' then
            return exports.fd_banking:AddMoney(name, amount)
        elseif Banking.name == 'qb-management' then
            return exports['qb-management']:AddMoney(name, amount)
        end
    end))

    if not ok then
        print(('^1[XS-Dealerships]^0 %s refused %s into account "%s" (%s).'):format(
            Banking.name, Util.Money(amount), name, note or kind or 'deposit'))
        return false
    end

    ledger(dealer, amount, kind or 'income', note, byName)
    return true
end

function Banking.Remove(dealer, amount, note, byName, kind)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if Banking.Balance(dealer) < amount then return false end

    if Banking.LedgerOnly() then
        ledger(dealer, -amount, kind or 'expense', note, byName)
        return true
    end

    local name = account(dealer)
    local ok = moved(pcall(function()
        if Banking.name == 'Renewed-Banking' then
            return exports['Renewed-Banking']:removeAccountMoney(name, amount)
        elseif Banking.name == 'qb-banking' then
            return exports['qb-banking']:RemoveMoney(name, amount, note)
        elseif Banking.name == 'okokBanking' then
            return exports.okokBanking:RemoveMoney(name, amount)
        elseif Banking.name == 'tgg-banking' then
            return exports['tgg-banking']:RemoveSocietyMoney(name, amount)
        elseif Banking.name == 'wasabi_banking' then
            return exports.wasabi_banking:RemoveMoney('society', name, amount)
        elseif Banking.name == 'fd_banking' then
            return exports.fd_banking:RemoveMoney(name, amount)
        elseif Banking.name == 'qb-management' then
            return exports['qb-management']:RemoveMoney(name, amount)
        end
    end))

    if not ok then return false end

    ledger(dealer, -amount, kind or 'expense', note, byName)
    return true
end
