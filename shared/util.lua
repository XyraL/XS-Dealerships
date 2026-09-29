Util = {}

function Util.Decode(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return nil end

    local ok, decoded = pcall(json.decode, value)
    if ok then return decoded end
    return nil
end

function Util.Truthy(value)
    return value == true or value == 1 or value == '1'
end

function Util.Clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

function Util.Money(amount)
    local n = math.floor(tonumber(amount) or 0)
    local text = tostring(math.abs(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (n < 0 and '-' or '') .. (Config.Currency or '$') .. text
end

function Util.TrimPlate(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Util.Hex(hex)
    if type(hex) ~= 'string' then return nil end
    local r, g, b = hex:match('^#?(%x%x)(%x%x)(%x%x)$')
    if not r then return nil end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

function Util.Point(point)
    if type(point) ~= 'table' then return nil end

    local x, y, z = tonumber(point.x), tonumber(point.y), tonumber(point.z)
    if not x or not y or not z then return nil end

    return { x = x, y = y, z = z, h = tonumber(point.h) or 0.0 }
end

function Util.Distance(a, b)
    if not a or not b then return math.huge end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Util.FinanceTerms(price, terms)
    price = math.floor(tonumber(price) or 0)
    terms = terms or Config.Finance

    local payments = math.max(1, math.floor(tonumber(terms.payments) or 1))
    local down = math.ceil(price * Util.Clamp(terms.downPayment, 0, 100) / 100)
    local financed = math.max(0, price - down)
    local total = financed + math.ceil(financed * Util.Clamp(terms.interest, 0, 1000) / 100)
    local payment = math.ceil(total / payments)

    return {
        price = price,
        down = down,
        financed = financed,
        total = total,
        payment = payment,
        payments = payments,
        intervalHours = tonumber(terms.intervalHours) or 24,
        interest = tonumber(terms.interest) or 0,
        downPayment = tonumber(terms.downPayment) or 0,
    }
end

function Util.TypeInfo(id)
    for _, entry in ipairs(Config.Types) do
        if entry.id == id then return entry end
    end
    return Config.Types[1]
end
