Vehicles = {}

local LETTERS = 'ABCDEFGHJKLMNPRSTUVWXYZ'
local VALID_TYPES = {
    automobile = true, bike = true, boat = true, heli = true, plane = true,
    submarine = true, trailer = true, train = true,
}

local function fromPattern(pattern)
    local out = {}
    for char in tostring(pattern):gmatch('.') do
        if char == 'A' then
            local i = math.random(#LETTERS)
            out[#out + 1] = LETTERS:sub(i, i)
        elseif char == '1' then
            out[#out + 1] = tostring(math.random(0, 9))
        else
            out[#out + 1] = char
        end
    end
    return table.concat(out):sub(1, 8)
end

function Vehicles.NewPlate()
    for _ = 1, 50 do
        local plate = Util.TrimPlate(fromPattern(Config.Purchase.platePattern))
        if plate ~= '' and not Framework.PlateTaken(plate) and not Vehicles.FindByPlate(plate) then
            return plate
        end
    end
    return nil
end

function Vehicles.TypeOf(model, hint)
    local info = Framework.Vehicle(model)
    local known = info and info.type or ''
    if VALID_TYPES[known] then return known end
    if VALID_TYPES[hint] then return hint end
    return 'automobile'
end

function Vehicles.Spawn(model, point, plate, vehicleType)
    local hash = joaat(model)
    local vehicle

    if type(CreateVehicleServerSetter) == 'function' then
        local ok, result = pcall(CreateVehicleServerSetter, hash, vehicleType or 'automobile',
            point.x, point.y, point.z, point.h or 0.0)
        if ok and result and result ~= 0 then vehicle = result end
    end

    if not vehicle then
        local ok, result = pcall(CreateVehicle, hash, point.x, point.y, point.z, point.h or 0.0, true, true)
        if ok and result and result ~= 0 then vehicle = result end
    end

    if not vehicle then return nil end

    local tries = 0
    while not DoesEntityExist(vehicle) and tries < 100 do
        Wait(20)
        tries = tries + 1
    end

    if not DoesEntityExist(vehicle) then return nil end

    if plate then SetVehicleNumberPlateText(vehicle, plate) end
    return vehicle
end

function Vehicles.Blocked(point, radius)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if Util.Distance(GetEntityCoords(vehicle), point) < (radius or 3.0) then return true end
    end
    return false
end

function Vehicles.FindByPlate(plate)
    plate = Util.TrimPlate(plate):upper()
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and Util.TrimPlate(GetVehicleNumberPlateText(vehicle)):upper() == plate then
            return vehicle
        end
    end
    return nil
end

function Vehicles.Occupied(vehicle)
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 then return true end
    end
    return false
end

function Vehicles.Delete(vehicle)
    if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
end

function Vehicles.Paint(paint)
    paint = type(paint) == 'table' and paint or {}
    local out = {}

    local r, g, b = Util.Hex(paint.primary)
    if r then out.color1 = { r, g, b } end

    if Config.Paint.secondary then
        r, g, b = Util.Hex(paint.secondary)
        if r then out.color2 = { r, g, b } end
    end

    return out
end
