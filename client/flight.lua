local config <const> = require 'config'

local settings <const> = config.spawnCam

---@class MulticharFlightOptions
---@field ms integer?
---@field onArrive fun()?

local Flight <const> = {}

---@type integer?
local cam
local flightId = 0

---@type { pos: vector3, look: vector3, fov: number }
local view = { pos = vector3(0.0, 0.0, 0.0), look = vector3(0.0, 0.0, 0.0), fov = 50.0 }

---@param t number
---@return number
local function easeInOutCubic(t)
    if t < 0.5 then return 4.0 * t * t * t end

    local f <const> = -2.0 * t + 2.0
    return 1.0 - f * f * f / 2.0
end

---@param a vector3
---@param b vector3
---@param c vector3
---@param t number
---@return vector3
local function bezier(a, b, c, t)
    local u <const> = 1.0 - t
    return a * (u * u) + b * (2.0 * u * t) + c * (t * t)
end

---@param pos vector3
---@param look vector3
---@param fov number
local function place(pos, look, fov)
    if not cam then return end

    SetCamCoord(cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    SetCamFov(cam, fov)
    view = { pos = pos, look = look, fov = fov }
end

---@param from vector3
---@param to vector3
---@return vector3 control
---@return number distance
local function arcControl(from, to)
    local distance <const> = #(to.xy - from.xy)
    local mid <const> = (from + to) / 2.0
    local top <const> = math.max(from.z, to.z)

    if distance < settings.arcDistance then
        return vector3(mid.x, mid.y, top + distance * settings.nearRise), distance
    end

    return vector3(mid.x, mid.y, top + math.min(distance * settings.arcRise, settings.arcMax)), distance
end

---@param distance number
---@return integer
local function durationFor(distance)
    local ms <const> = settings.minMs + distance / 1000.0 * settings.msPerKm
    return math.floor(math.min(settings.maxMs, math.max(settings.minMs, ms)))
end

---@param pos vector3
---@param look vector3
---@param fov number
function Flight.start(pos, look, fov)
    Flight.stop()

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    place(pos, look, fov)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetFocusPosAndVel(look.x, look.y, look.z, 0.0, 0.0, 0.0)
end

---@param pos vector3
---@param look vector3
---@param fov number
---@param options MulticharFlightOptions?
function Flight.to(pos, look, fov, options)
    if not cam then return end

    flightId += 1

    local id <const> = flightId
    local fromPos <const>, fromLook <const>, fromFov <const> = view.pos, view.look, view.fov
    local control <const>, distance <const> = arcControl(fromPos, pos)
    local duration <const> = options?.ms or durationFor(distance)
    local onArrive <const> = options?.onArrive

    SetCamUseShallowDofMode(cam, false)
    SetFocusPosAndVel(look.x, look.y, look.z, 0.0, 0.0, 0.0)

    CreateThread(function()
        local started <const> = GetGameTimer()

        while cam and flightId == id do
            local t <const> = math.min(1.0, (GetGameTimer() - started) / duration)
            local e <const> = easeInOutCubic(t)

            place(bezier(fromPos, control, pos, e), fromLook + (look - fromLook) * e, fromFov + (fov - fromFov) * e)

            if t >= 1.0 then break end

            Wait(0)
        end

        if flightId == id and onArrive then onArrive() end
    end)
end

---@return integer?
function Flight.handle()
    return cam
end

function Flight.stop()
    flightId += 1

    if not cam then return end

    if DoesCamExist(cam) then DestroyCam(cam, false) end

    cam = nil
end

return Flight
