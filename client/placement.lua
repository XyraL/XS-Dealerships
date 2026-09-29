Placement = { active = false }

local CONTROLS = {
    confirm = 191, cancel = 194,
    forward = 32, back = 33, left = 34, right = 35,
    up = 22, down = 36, fast = 21, slow = 19,
    turnLeft = 96, turnRight = 97,
    floor = 73,
}

local SPEED = { normal = 6.0, fast = 18.0, slow = 1.5 }
local RANGE = 60.0

local function forward(cam)
    local rot = GetCamRot(cam, 2)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local cosX = math.abs(math.cos(x))
    return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

local function didHit(hit)
    return hit == true or hit == 1
end

local function aim(cam, ignore)
    local from = GetCamCoord(cam)
    local to = from + forward(cam) * RANGE

    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, ignore or 0, 4)
    local _, hit, coords = GetShapeTestResult(ray)

    local point = didHit(hit) and coords or to

    local wet, water = GetWaterHeightNoWaves(point.x, point.y, point.z + 50.0)
    if wet and water > point.z then point = vector3(point.x, point.y, water) end

    return point
end

local function floorUnder(point)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(point.x, point.y, point.z + 1.0, point.x, point.y, point.z - 8.0, 1 + 16, 0, 4)
    local _, hit, coords = GetShapeTestResult(ray)
    return didHit(hit) and coords.z or nil
end

local function makeGhost(model)
    if not model then return nil end

    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end

    local ok = pcall(lib.requestModel, hash, 10000)
    if not ok then return nil end

    local ghost = CreateVehicle(hash, 0.0, 0.0, 0.0, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityInvincible(ghost, true)
    SetVehicleDoorsLocked(ghost, 2)
    return ghost
end

function Placement.Start(options)
    if Placement.active then return nil end
    options = options or {}

    local ped = cache.ped
    local origin = options.origin
    local start = origin and vector3(origin.x, origin.y, origin.z) or GetEntityCoords(ped)
    local heading = origin and origin.h or GetEntityHeading(ped)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, start.x, start.y, start.z + 3.0)
    SetCamRot(cam, -25.0, 0.0, GetEntityHeading(ped), 2)
    SetCamFov(cam, 60.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 300, true, true)
    FreezeEntityPosition(ped, true)

    local ghost = makeGhost(options.preview)
    Placement.active = true

    lib.showTextUI(([[
**%s**
[Enter] Put it here
[WASD] Fly  ·  [Shift] fast  ·  [Alt] slow
[Space] / [Ctrl] Up and down
[Scroll] Turn
[X] Drop to the floor
[Backspace] Cancel]]):format(options.label or 'Placing a point'), { position = 'left-center' })

    local result
    local point = start
    local pinned = false

    while Placement.active do
        Wait(0)

        DisableAllControlActions(0)
        EnableControlAction(0, CONTROLS.confirm, true)
        EnableControlAction(0, CONTROLS.cancel, true)

        local pos = GetCamCoord(cam)
        local rot = GetCamRot(cam, 2)
        SetCamRot(cam, math.max(-89.0, math.min(89.0, rot.x - GetDisabledControlNormal(0, 2) * 6.0)), 0.0,
            rot.z - GetDisabledControlNormal(0, 1) * 6.0, 2)

        local speed = SPEED.normal
        if IsDisabledControlPressed(0, CONTROLS.fast) then speed = SPEED.fast end
        if IsDisabledControlPressed(0, CONTROLS.slow) then speed = SPEED.slow end
        speed = speed * GetFrameTime()

        local fwd = forward(cam)

        local right = vector3(fwd.y, -fwd.x, 0.0)
        local move = vector3(0.0, 0.0, 0.0)

        if IsDisabledControlPressed(0, CONTROLS.forward) then move = move + fwd end
        if IsDisabledControlPressed(0, CONTROLS.back) then move = move - fwd end
        if IsDisabledControlPressed(0, CONTROLS.right) then move = move + right end
        if IsDisabledControlPressed(0, CONTROLS.left) then move = move - right end
        if IsDisabledControlPressed(0, CONTROLS.up) then move = move + vector3(0.0, 0.0, 1.0) end
        if IsDisabledControlPressed(0, CONTROLS.down) then move = move - vector3(0.0, 0.0, 1.0) end

        if #move > 0.0 then
            pos = pos + move * speed
            SetCamCoord(cam, pos.x, pos.y, pos.z)
            pinned = false
        end

        SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)

        if not pinned then point = aim(cam, ghost) end

        if IsDisabledControlJustPressed(0, CONTROLS.floor) then
            local floor = floorUnder(point)
            if floor then
                point = vector3(point.x, point.y, floor)
                pinned = true
            end
        end

        if IsDisabledControlPressed(0, CONTROLS.turnLeft) then heading = (heading + 2.0) % 360 end
        if IsDisabledControlPressed(0, CONTROLS.turnRight) then heading = (heading - 2.0) % 360 end

        if ghost and DoesEntityExist(ghost) then
            SetEntityCoordsNoOffset(ghost, point.x, point.y, point.z + 0.05, false, false, false)
            SetEntityHeading(ghost, heading)
        else
            DrawMarker(1, point.x, point.y, point.z - 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.8, 0.8, 0.6, 255, 196, 0, 120, false, false, 2, false)
            local dir = vector3(-math.sin(math.rad(heading)), math.cos(math.rad(heading)), 0.0)
            DrawLine(point.x, point.y, point.z + 0.1, point.x + dir.x, point.y + dir.y, point.z + 0.1, 255, 196, 0, 220)
        end

        if IsDisabledControlJustPressed(0, CONTROLS.confirm) then
            result = { x = point.x, y = point.y, z = point.z, h = heading }
            break
        end

        if IsDisabledControlJustPressed(0, CONTROLS.cancel) then break end
    end

    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    RenderScriptCams(false, true, 300, true, true)
    SetCamActive(cam, false)
    DestroyCam(cam, true)
    ClearFocus()
    FreezeEntityPosition(ped, false)
    lib.hideTextUI()
    Placement.active = false

    return result
end

function Placement.Abort()
    Placement.active = false
end
