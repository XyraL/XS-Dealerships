Tablet = { holding = false }

local DICT = 'amb@world_human_tourist_map@male@base'
local CLIP = 'base'
local MODEL = 'prop_cs_tablet'
local BONE = 18905

local prop

local function dropProp()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
end

local function stopPose()
    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then return end
    StopAnimTask(ped, DICT, CLIP, 4.0)
    ClearPedSecondaryTask(ped)
end

local function stopHolding()
    Tablet.holding = false
    dropProp()
    stopPose()

    CreateThread(function()
        for _ = 1, 8 do
            Wait(250)
            if Tablet.holding then return end
            if IsEntityPlayingAnim(cache.ped, DICT, CLIP, 3) then stopPose() end
        end
    end)
end

local function startHolding()
    if not Config.Tablet.animation or Tablet.holding then return end
    Tablet.holding = true

    CreateThread(function()
        local ped = cache.ped
        local ok = pcall(function()
            lib.requestAnimDict(DICT, 3000)
            lib.requestModel(MODEL, 3000)
        end)

        if not ok or not Tablet.holding then
            if not Tablet.holding then dropProp() end
            return
        end

        TaskPlayAnim(ped, DICT, CLIP, 3.0, -1.0, -1, 49, 0, false, false, false)
        prop = CreateObject(joaat(MODEL), 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, BONE), 0.05, 0.02, -0.02, 10.0, 160.0, 0.0,
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(joaat(MODEL))

        while Tablet.holding do
            Wait(500)
            if not DoesEntityExist(ped) then break end
            if not IsEntityPlayingAnim(ped, DICT, CLIP, 3) then
                TaskPlayAnim(ped, DICT, CLIP, 3.0, -1.0, -1, 49, 0, false, false, false)
            end
        end

        dropProp()
    end)
end

function Tablet.Open(dealerId)
    if Placement.active or UI.open then return end

    local ok, result = lib.callback.await('XS-Dealerships:server:tablet', false, dealerId)
    if not ok then
        Framework.Notify(result or 'The tablet will not open.', 'error')
        return
    end

    result.config = { currency = Config.Currency, images = Config.Images, resource = GetCurrentResourceName() }

    UI.open = true
    UI.closeHook = stopHolding
    SetNuiFocus(true, true)
    UI.Send('tablet', result)
    startHolding()
end

RegisterNetEvent('XS-Dealerships:client:openTablet', function()
    Tablet.Open()
end)

if Config.Tablet.item ~= '' then
    exports('openTablet', function()
        Tablet.Open()
    end)
end

RegisterNUICallback('tablet', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:tablet', false, data.dealer)
    cb({ ok = ok, error = not ok and result or nil, data = ok and result or nil })
end)

RegisterNUICallback('moveMoney', function(data, cb)
    local ok, result = lib.callback.await('XS-Dealerships:server:moveMoney', false, data.dealer, data.direction, data.amount)
    cb({ ok = ok, error = not ok and result or nil, office = ok and result or nil })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and Tablet.holding then stopHolding() end
end)
