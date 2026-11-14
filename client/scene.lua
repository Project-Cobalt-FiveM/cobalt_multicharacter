local config <const> = require 'config'
local Flight <const> = require 'client.flight'
local geometry <const> = require 'client.geometry'

local CharScene <const> = {}

local active = false
---@type number?
local groundZ
---@type integer?
local previewPed
---@type string?
local shownKey
---@type string?
local wantedKey
---@type MulticharCharacter?
local wantedChar
local workerRunning = false

---@type table<string, table | false>
local skinCache <const> = {}

local scene <const> = config.scene

local REM_PER_HEIGHT <const> = 0.0148
local REM_MIN <const> = 12.0
local REM_MAX <const> = 22.0
local MODEL_TIMEOUT <const> = 5000

---@param ped integer?
local function deletePed(ped)
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
    end
end

---@return vector3
local function pedPosition()
    local c <const> = scene.pedCoords
    return vector3(c.x, c.y, groundZ or c.z)
end

---@return number
local function gapOffset()
    local w <const>, h <const> = GetActiveScreenResolution()
    local rem <const> = math.min(REM_MAX, math.max(REM_MIN, h * REM_PER_HEIGHT))
    local left <const> = scene.cam.gap.left * rem
    local right <const> = w - scene.cam.gap.right * rem
    return ((left + right) - w) / h
end

---@param distance number
---@param height number
---@return vector3 camPos
---@return vector3 aim
local function cameraPose(distance, height)
    local pos <const> = pedPosition()
    local camPos <const> = pos + geometry.forwardOf(scene.pedCoords.w) * distance + vector3(0.0, 0.0, height)
    local target <const> = pos + vector3(0.0, 0.0, scene.cam.lookHeight)
    local dir <const> = target - camPos
    local len <const> = math.sqrt(dir.x * dir.x + dir.y * dir.y)
    local right <const> = vector3(dir.y / len, -dir.x / len, 0.0)
    local shift <const> = gapOffset() * math.tan(math.rad(scene.cam.fov / 2)) * distance
    return camPos, target - right * shift
end

---@return vector3 camPos
---@return vector3 aim
local function pedCamPose()
    return cameraPose(scene.cam.distance, scene.cam.height)
end

---@param handle integer
local function setPedDof(handle)
    SetCamUseShallowDofMode(handle, true)
    SetCamNearDof(handle, scene.cam.distance - 1.0)
    SetCamFarDof(handle, scene.cam.distance + 8.0)
    SetCamDofStrength(handle, 0.6)
end

local function focusDof()
    local handle <const> = Flight.handle()
    if handle then setPedDof(handle) end
end

---@param citizenid string
---@return table | false
local function fetchSkin(citizenid)
    if skinCache[citizenid] ~= nil then return skinCache[citizenid] end
    local skin <const> = lib.callback.await('cobalt_multicharacter:server:getSkin', false, citizenid)
    skinCache[citizenid] = type(skin) == 'table' and skin or false
    return skinCache[citizenid]
end

---@param skin table | false
---@param charinfo table?
---@return integer
local function resolveModel(skin, charinfo)
    local model <const> = skin and skin.model
    if math.type(model) == 'integer' then return model --[[@as integer]] end
    if type(model) == 'string' then return math.tointeger(tonumber(model)) or joaat(model) end
    return (charinfo and tonumber(charinfo.gender) == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
end

---@param ped integer
---@param skin table
local function applyComponentsAndProps(ped, skin)
    for _, c in pairs(skin.components or {}) do
        SetPedComponentVariation(ped, c.component_id, c.drawable, c.texture, 0)
    end
    for _, p in pairs(skin.props or {}) do
        if p.drawable == -1 then
            ClearPedProp(ped, p.prop_id)
        else
            SetPedPropIndex(ped, p.prop_id, p.drawable, p.texture, false)
        end
    end
end

---@param ped integer
---@param skin table | false
local function applySkin(ped, skin)
    if not skin then
        SetPedDefaultComponentVariation(ped)
        return
    end
    local ok <const> = GetResourceState('illenium-appearance') == 'started' and pcall(function()
        exports['illenium-appearance']:setPedAppearance(ped, skin)
    end)
    if not ok then applyComponentsAndProps(ped, skin) end
end

local function playConfetti()
    local fx <const> = scene.confetti
    local timeout <const> = GetGameTimer() + 1000
    while not HasNamedPtfxAssetLoaded(fx.asset) do
        if not active or GetGameTimer() > timeout then return end
        Wait(0)
    end
    local pos <const> = pedPosition()
    UseParticleFxAsset(fx.asset)
    StartParticleFxNonLoopedAtCoord(fx.effect, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, fx.scale, false, false, false)
end

---@param ped integer
local function playIdle(ped)
    local idle <const> = scene.idleAnim
    if idle and HasAnimDictLoaded(idle.dict) then
        TaskPlayAnim(ped, idle.dict, idle.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

---@param ped integer
---@param to integer
---@param key string?
---@return boolean finished
local function fade(ped, to, key)
    local step <const> = 255 / math.max(1, scene.fadeSteps)
    local alpha = GetEntityAlpha(ped)
    while alpha ~= to do
        if not active or not DoesEntityExist(ped) then return false end
        if key and wantedKey ~= key then return false end
        alpha = to > alpha and math.min(to, alpha + step) or math.max(to, alpha - step)
        SetEntityAlpha(ped, math.floor(alpha), false)
        Wait(scene.fadeStepMs)
    end
    return true
end

---@param key string
---@param char MulticharCharacter
local function spawnPreview(key, char)
    local skin <const> = fetchSkin(char.citizenid)
    if not active or wantedKey ~= key then return end

    local model <const> = resolveModel(skin, char.charinfo)
    if not IsModelInCdimage(model) or not pcall(lib.requestModel, model, MODEL_TIMEOUT) then
        SetModelAsNoLongerNeeded(model)
        lib.print.warn(('preview model %s failed to load'):format(model))
        if wantedKey == key then shownKey = key end
        return
    end
    if not active or wantedKey ~= key then
        SetModelAsNoLongerNeeded(model)
        return
    end

    local pos <const> = pedPosition()
    local ped <const> = CreatePed(4, model, pos.x, pos.y, pos.z, scene.pedCoords.w, false, true)
    SetModelAsNoLongerNeeded(model)
    previewPed = ped
    shownKey = key

    SetEntityAlpha(ped, 0, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    applySkin(ped, skin)

    playConfetti()
    playIdle(ped)
    if fade(ped, 255, key) then ResetEntityAlpha(ped) end
end

local function runWorker()
    if workerRunning then return end
    workerRunning = true
    CreateThread(function()
        while active and shownKey ~= wantedKey do
            if previewPed then
                fade(previewPed, 0)
                deletePed(previewPed)
                previewPed = nil
            end
            shownKey = nil
            if active and wantedKey and wantedChar then
                spawnPreview(wantedKey, wantedChar)
            end
        end
        workerRunning = false
    end)
end

---@param char MulticharCharacter?
function CharScene.preview(char)
    if not active then return end
    wantedChar = char
    wantedKey = char?.citizenid
    runWorker()
end

---@param pos vector3
---@param lookAt vector3
function CharScene.flyTo(pos, lookAt)
    if not active then return end
    Flight.to(pos, lookAt, config.spawnCam.fov)
end

function CharScene.focusPed()
    if not active then return end
    local pos <const>, aim <const> = pedCamPose()
    Flight.to(pos, aim, scene.cam.fov, { onArrive = focusDof })
end

---@param delta number
function CharScene.rotate(delta)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    SetEntityHeading(previewPed, (GetEntityHeading(previewPed) + delta) % 360.0)
end

---@param citizenid string
function CharScene.forgetSkin(citizenid)
    skinCache[citizenid] = nil
end

---@param citizenid string
---@return table | false | nil
function CharScene.skinOf(citizenid)
    return skinCache[citizenid]
end

function CharScene.start()
    if active then return end
    local c <const> = scene.pedCoords
    local playerPed <const> = cache.ped

    exports.cobalt_weather:SetSync(false)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypeOverTime(scene.weather, 1.0)
    SetWeatherTypeNow(scene.weather)
    SetWeatherTypePersist(scene.weather)
    SetWeatherTypeNowPersist(scene.weather)
    NetworkOverrideClockTime(scene.time.hours, scene.time.minutes, 0)
    PauseClock(true)

    RequestNamedPtfxAsset(scene.confetti.asset)
    if scene.idleAnim then RequestAnimDict(scene.idleAnim.dict) end

    local hidden <const> = vector3(c.x, c.y, c.z) + geometry.forwardOf(c.w) * (scene.cam.distance + 3.0)
    SetEntityCoords(playerPed, hidden.x, hidden.y, hidden.z, false, false, false, false)
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityCollision(playerPed, false, false)
    SetEntityInvincible(playerPed, true)

    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
    local timeout <const> = GetGameTimer() + 3000
    local found, z = false, nil
    while GetGameTimer() < timeout do
        found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
        if found then break end
        Wait(50)
    end
    groundZ = found and z or c.z

    local camCfg <const> = scene.cam
    local introDistance <const> = camCfg.distance + camCfg.introPullback
    local startPos <const>, startAim <const> = cameraPose(introDistance, camCfg.height + camCfg.introRise)
    local endPos <const>, endAim <const> = pedCamPose()

    Flight.start(startPos, startAim, camCfg.fov)
    Flight.to(endPos, endAim, camCfg.fov, {
        ms = camCfg.introMs,
        onArrive = focusDof,
    })
    active = true

    CreateThread(function()
        while active do
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            SetUseHiDof()
            Wait(0)
        end
    end)

    DoScreenFadeIn(1000)
end

function CharScene.stop()
    if not active then return end
    active = false
    wantedKey, wantedChar = nil, nil

    deletePed(previewPed)
    previewPed, shownKey = nil, nil
    table.wipe(skinCache)

    RenderScriptCams(false, false, 0, true, true)
    Flight.stop()
    ClearFocus()

    RemoveNamedPtfxAsset(scene.confetti.asset)
    if scene.idleAnim then RemoveAnimDict(scene.idleAnim.dict) end

    NetworkClearClockTimeOverride()
    PauseClock(false)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    exports.cobalt_weather:SetSync(true)

    local playerPed <const> = cache.ped
    SetEntityCollision(playerPed, true, true)
    SetEntityInvincible(playerPed, false)
    FreezeEntityPosition(playerPed, false)
    ResetEntityAlpha(playerPed)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CharScene.stop()
end)

return CharScene
