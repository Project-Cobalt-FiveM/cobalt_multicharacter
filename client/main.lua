local config <const> = require 'config'
local scene <const> = require 'client.scene'
local arrival <const> = require 'client.arrival'
local geometry <const> = require 'client.geometry'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()
local starter <const> = require '@cobalt_core.config.shared'.starterApartment

local COLLISION_TIMEOUT <const> = 5000
local POSITION_SYNC_MS <const> = 1000
local SPAWN_KINDS <const> = { last = true, apartment = true, house = true, favorite = true }

---@type table<string, MulticharCharacter>
local cachedCharacters <const> = {}

---@type table<string, string>
local uiLocales <const> = {}

for key, value in pairs(lib.getLocales()) do
    if key:sub(1, 3) == 'ui.' then
        uiLocales[key] = value
    end
end

local creationRules <const> = {
    minYear = config.creation.minYear,
    maxYear = config.creation.maxYear,
    blockedWords = config.creation.blockedWords,
    blockedFragments = config.creation.blockedFragments,
    nationalities = lib.loadJson('data.nationalities'),
}

---@type MulticharPendingSpawn?
local pendingSpawn
local entering = false

---@return vector4
local function defaultSpawn()
    local c <const> = config.defaultSpawn
    return vector4(c.x, c.y, c.z, 0.0)
end

---@param charData MulticharCharacter?
---@return { kind: 'apartment' | 'house', place: MulticharSpawnPlace }[]
local function housingPlaces(charData)
    local places <const> = {}

    if not charData then return places end

    if charData.starterApartment then
        places[1] = { kind = 'apartment', place = charData.starterApartment }
    end

    for _, house in ipairs(charData.houses or {}) do
        places[#places + 1] = { kind = 'house', place = house }
    end

    return places
end

---@param spawn MulticharSpawnTarget
---@param charData MulticharCharacter?
---@return vector4?
local function housingSpawn(spawn, charData)
    for _, entry in ipairs(housingPlaces(charData)) do
        if entry.kind == spawn.kind and entry.place.id == spawn.id then
            local door <const> = entry.place.door
            return vector4(door.x, door.y, door.z, door.w)
        end
    end
end

---@param spawn unknown
---@param charData MulticharCharacter?
---@return vector4 coords
---@return boolean downed
local function resolveSpawn(spawn, charData)
    if type(spawn) ~= 'table' then return defaultSpawn(), false end

    local position <const> = charData?.position

    if spawn.kind == 'last' and position then
        return vector4(position.x, position.y, position.z, 0.0), charData?.isDead == true
    end

    if spawn.kind == 'favorite' then
        local index <const> = math.tointeger(spawn.id)
        local entry <const> = index and config.spawns[index + 1]
        return entry?.coords or defaultSpawn(), false
    end

    return housingSpawn(spawn, charData) or defaultSpawn(), false
end

---@param coords vector4
---@return string? area
---@return string? postal
local function describePlace(coords)
    local area <const> = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    local postal

    if GetResourceState('cobalt_map') == 'started' then
        local nearest <const> = exports.cobalt_map:GetNearestPostal(coords.xyz)
        postal = nearest and tostring(nearest.code)
    end

    return area ~= 'NULL' and area or nil, postal
end

---@param citizenid string
---@return MulticharSpawnOption[]
local function spawnList(citizenid)
    local charData <const> = cachedCharacters[citizenid]
    local list <const> = {}

    if charData?.position then
        list[1] = { kind = 'last', name = locale('spawn.last.name'), subtitle = locale('spawn.last.subtitle') }
    end

    for _, entry in ipairs(housingPlaces(charData)) do
        list[#list + 1] = {
            kind = entry.kind,
            id = entry.place.id,
            name = entry.place.name,
            subtitle = entry.place.subtitle,
        }
    end

    for i, spawn in ipairs(config.spawns) do
        list[#list + 1] = {
            kind = 'favorite',
            id = i - 1,
            name = locale(('spawn.%s.name'):format(spawn.id)),
            subtitle = locale(('spawn.%s.description'):format(spawn.id)),
        }
    end

    for _, option in ipairs(list) do
        option.area, option.postal = describePlace(resolveSpawn(option, charData))
    end

    return list
end

---@param target MulticharSpawnTarget
---@param coords vector4
---@return MulticharSpawnView
local function spawnView(target, coords)
    if target.kind == 'favorite' then
        local index <const> = math.tointeger(target.id)
        local view <const> = index and config.spawns[index + 1]?.view

        if view then return view end
    end

    local default <const> = config.spawnCam.defaultView

    return {
        heading = (coords.w + 180.0 + default.heading) % 360.0,
        distance = default.distance,
        height = default.height,
        lookHeight = default.lookHeight,
    }
end

---@param target MulticharSpawnTarget
---@param coords vector4
---@return vector3 camPos
---@return vector3 lookAt
local function spawnCamera(target, coords)
    local view <const> = spawnView(target, coords)
    local facing <const> = geometry.forwardOf(view.heading)
    local look <const> = coords.xyz + vector3(0.0, 0.0, view.lookHeight)

    return coords.xyz - facing * view.distance + vector3(0.0, 0.0, view.height), look
end

---@param hidden boolean
local function hideHud(hidden)
    if GetResourceState('cobalt_hud') ~= 'started' then return end

    exports.cobalt_hud:SetHiddenBy('character', hidden)
end

local function openMenu()
    local characters <const>, maxSlots <const> = lib.callback.await('cobalt_multicharacter:server:getCharacters', false)

    table.wipe(cachedCharacters)

    for _, c in ipairs(characters or {}) do
        cachedCharacters[c.citizenid] = c
    end

    hideHud(true)
    scene.start()

    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(500) end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        characters = characters or {},
        maxSlots = maxSlots,
        enableDelete = config.enableDeleteButton,
        creation = creationRules,
        locales = uiLocales,
    })
end

local function closeMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    scene.stop()
end

---@param playerData table
local function createMissingAppearance(playerData)
    local female <const> = tonumber(playerData.charinfo?.gender) == 1

    exports['illenium-appearance']:setPlayerModel(female and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end

---@param playerData table?
---@param skin table | false | nil the look the preview already fetched
---@return boolean creating true when no saved look applied and the creator opened instead
local function restoreAppearance(playerData, skin)
    if not playerData or not playerData.citizenid then
        lib.print.warn('no player data to restore the appearance from')
        return false
    end

    if type(skin) ~= 'table' then
        skin = lib.callback.await('cobalt_multicharacter:server:getSkin', false, playerData.citizenid)
    end

    local ok, err = false, 'none saved'

    if skin then
        ok, err = pcall(exports['illenium-appearance'].setPlayerAppearance, exports['illenium-appearance'], skin)
    end

    if not ok then
        lib.print.warn(('no usable appearance for %s (%s), opening the creator'):format(playerData.citizenid, err))
        createMissingAppearance(playerData)
    end

    Wait(200)

    local ped <const> = PlayerPedId()
    local maxHp <const> = GetEntityMaxHealth(ped)
    local savedHp <const> = playerData.metadata?.health

    SetEntityHealth(ped, (savedHp and savedHp > 0 and savedHp <= maxHp) and savedHp or maxHp)
    SetPedArmour(ped, playerData.metadata?.armor or 0)

    return not ok
end

local function chooseCharacter()
    pendingSpawn = nil
    entering = false

    SetNuiFocus(false, false)
    DoScreenFadeOut(10)
    Wait(1000)

    FreezeEntityPosition(cache.ped, true)
    SetEntityVisible(cache.ped, false, false)
    Wait(1500)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    openMenu()
end

---@param ped integer
---@param hidden boolean
local function setHidden(ped, hidden)
    SetEntityVisible(ped, not hidden, false)
    SetEntityCollision(ped, not hidden, not hidden)
    FreezeEntityPosition(ped, hidden)
    SetEntityInvincible(ped, hidden)
end

---@param spawn MulticharPendingSpawn
---@return vector4? entry where the player stands inside the room
local function enterStarterRoom(spawn)
    if spawn.target.kind ~= 'apartment' or spawn.downed then return end
    if GetResourceState('cobalt_housing') ~= 'started' then return end

    Wait(POSITION_SYNC_MS)

    local entered <const> = promise.new()

    TriggerEvent('cobalt_housing:client:enterStarter', true, function(ok) entered:resolve(ok) end)

    if not Citizen.Await(entered) then return end

    local ped <const> = PlayerPedId()
    local pos <const> = GetEntityCoords(ped)

    return vector4(pos.x, pos.y, pos.z, GetEntityHeading(ped))
end

---@param spawn MulticharPendingSpawn
local function enterWorld(spawn)
    Wait(500)

    local coords <const> = spawn.coords
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(cache.ped, coords.w)
    setHidden(cache.ped, true)

    local creating <const> = restoreAppearance(Cobalt.Functions.GetPlayerData(), spawn.skin)
    local ped <const> = PlayerPedId()
    local deadline <const> = GetGameTimer() + COLLISION_TIMEOUT

    setHidden(ped, true)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
        Wait(50)
    end

    if creating then
        arrival.settle(PlayerPedId(), coords)
        setHidden(PlayerPedId(), false)
        DoScreenFadeIn(500)
        entering = false
        return
    end

    local arrivalAt <const> = enterStarterRoom(spawn) or coords

    if spawn.downed then arrival.settle(PlayerPedId(), arrivalAt) end

    local faded <const> = spawn.downed or arrival.play(arrivalAt, spawn.target)

    setHidden(PlayerPedId(), false)

    if faded then DoScreenFadeIn(500) end

    hideHud(false)
    entering = false
end

RegisterNUICallback('ready', function(_, cb)
    cb('ok')

    if LocalPlayer.state.LoggedIn then return end

    CreateThread(function()
        while not NetworkIsSessionStarted() do Wait(10) end
        chooseCharacter()
    end)
end)

RegisterNUICallback('previewPed', function(data, cb)
    cb('ok')

    local char <const> = type(data.character) == 'table' and data.character.citizenid and data.character or nil

    if char then
        SendNUIMessage({ action = 'spawnOptions', spawns = spawnList(char.citizenid) })
    end

    scene.preview(char)
end)

RegisterNUICallback('rotatePed', function(data, cb)
    cb('ok')

    if type(data.delta) ~= 'number' then return end

    scene.rotate(data.delta)
end)

RegisterNUICallback('previewSpawn', function(data, cb)
    cb('ok')

    if type(data.spawn) ~= 'table' then return end

    local coords <const> = resolveSpawn(data.spawn, cachedCharacters[data.citizenid])

    scene.flyTo(spawnCamera(data.spawn, coords))
end)

RegisterNUICallback('spawnBack', function(_, cb)
    cb('ok')
    scene.focusPed()
end)

RegisterNUICallback('select', function(data, cb)
    cb('ok')

    local coords <const>, downed <const> = resolveSpawn(data.spawn, cachedCharacters[data.citizenid])
    local requested <const> = type(data.spawn) == 'table' and data.spawn or {}
    local kind <const> = SPAWN_KINDS[requested.kind] and requested.kind or 'favorite'

    pendingSpawn = {
        coords = coords,
        target = { kind = kind, id = requested.id },
        downed = downed,
        skin = scene.skinOf(data.citizenid),
    }
    entering = true

    DoScreenFadeOut(10)
    TriggerServerEvent('cobalt_multicharacter:server:loadCharacter', data.citizenid)
    closeMenu()
end)

RegisterNUICallback('create', function(data, cb)
    cb('ok')
    DoScreenFadeOut(150)

    local created <const> = lib.callback.await('cobalt_multicharacter:server:createCharacter', false, data)

    if not created then DoScreenFadeIn(250) end
end)

RegisterNUICallback('delete', function(data, cb)
    cb('ok')
    lib.callback.await('cobalt_multicharacter:server:deleteCharacter', false, data.citizenid)
    scene.forgetSkin(data.citizenid)
    openMenu()
end)

RegisterNetEvent('cobalt_multicharacter:client:chooseChar', chooseCharacter)

RegisterNetEvent('cobalt_multicharacter:client:creatorClosed', function()
    hideHud(false)
end)

RegisterNetEvent('cobalt_multicharacter:client:closeNUI', function()
    SetNuiFocus(false, false)

    local spawn <const> = pendingSpawn
    if not spawn then return end

    pendingSpawn = nil

    CreateThread(function()
        enterWorld(spawn)
    end)
end)

RegisterNetEvent('cobalt_multicharacter:client:spawn', function()
    SetNuiFocus(false, false)
    DoScreenFadeOut(500)
    Wait(1000)
    closeMenu()

    local model <const> = `mp_m_freemode_01`
    lib.requestModel(model)
    SetPlayerModel(cache.playerId, model)
    SetModelAsNoLongerNeeded(model)

    local ped <const> = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
    local start <const> = config.defaultSpawn
    SetEntityCoords(ped, start.x, start.y, start.z, false, false, false, false)

    hideHud(true)
    Wait(500)

    SetEntityVisible(ped, true)
    Wait(500)

    if starter.enabled and GetResourceState('cobalt_housing') == 'started' then
        TriggerEvent('cobalt_housing:client:chooseStarterApartment')
        return
    end

    DoScreenFadeIn(250)
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    SetNuiFocus(false, false)

    if not entering then return end

    setHidden(PlayerPedId(), false)
    DoScreenFadeIn(0)
end)
