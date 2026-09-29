Fuel = { name = nil }

if IsDuplicityVersion() then return end

do
    local forced = Config.Bridges.fuel
    if forced ~= 'auto' then
        Fuel.name = forced ~= 'none' and forced or nil
    else
        for _, resource in ipairs({ 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel' }) do
            if GetResourceState(resource) == 'started' then
                Fuel.name = resource
                break
            end
        end
    end
end

function Fuel.Set(vehicle, level)
    if not DoesEntityExist(vehicle) then return end
    level = level + 0.0

    SetVehicleFuelLevel(vehicle, level)
    if DecorIsRegisteredAsType('_Fuel_Level', 1) then DecorSetFloat(vehicle, '_Fuel_Level', level) end

    pcall(function()
        if Fuel.name == 'ox_fuel' then
            Entity(vehicle).state:set('fuel', level, true)
        elseif Fuel.name == 'LegacyFuel' or Fuel.name == 'cdn-fuel' or Fuel.name == 'ps-fuel' then
            exports[Fuel.name]:SetFuel(vehicle, level)
        end
    end)
end
