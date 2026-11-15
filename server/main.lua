local config <const> = require 'config'
local serverConfig <const> = require 'server.config'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()
local starter <const> = require '@cobalt_core.config.shared'.starterApartment
local creation <const> = config.creation

local NAME_MAX <const> = 20
local DAYS_IN_MONTH <const> = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

---@type table<string, true>
local knownNationalities <const> = {}

for _, nationality in ipairs(lib.loadJson('data.nationalities')) do
    knownNationalities[nationality] = true
end

---@class MulticharNewCharacter
---@field cid integer
---@field charinfo { firstname: string, lastname: string, nationality: string, birthdate: string, gender: 0 | 1 }

local INVENTORY_LOAD_TIMEOUT <const> = 10000

---@param source integer
local function giveStarterItems(source)
    if not Cobalt.Functions.GetPlayer(source) then return end

    lib.waitFor(
        function() return Player(source).state.inventoryLoaded end,
        'inventory did not load',
        INVENTORY_LOAD_TIMEOUT
    )

    local metadata <const> = { id_card = exports.cobalt_core:CardMetadata(source) }

    for itemName, amount in pairs(serverConfig.startItems) do
        exports.cobalt_inventory:AddItem(source, itemName, amount, metadata[itemName], nil, 'starter_items')
    end
end

---@param name string?
---@return boolean
local function isAffiliated(name)
    return name ~= nil and name ~= '' and name ~= 'none' and name ~= 'unemployed'
end

---@param group table?
---@return MulticharOrg?
local function toOrg(group)
    if not group or not isAffiliated(group.name) then return end

    return { label = group.label or group.name, grade = group.grade?.name or '' }
end

---@param character CoreAccountCharacter
---@return MulticharOrg?
local function resolveOrg(character)
    return toOrg(character.job) or toOrg(character.gang)
end

---@param license string
---@return integer
local function maxSlotsFor(license)
    for _, v in pairs(serverConfig.playersNumberOfCharacters) do
        if v.license == license then return v.numberOfChars end
    end

    return serverConfig.defaultNumberOfCharacters
end

---@param citizenid string
---@return number?
local function bankBalance(citizenid)
    if GetResourceState('cobalt_banking') ~= 'started' then return end

    return exports.cobalt_banking:GetBalance(citizenid)
end

---@param door vector4
---@return { x: number, y: number, z: number, w: number }
local function plainDoor(door)
    return { x = door.x, y = door.y, z = door.z, w = door.w }
end

---@param id string?
---@return MulticharSpawnPlace?
local function starterApartment(id)
    if not id or not starter.enabled then return end

    for _, location in ipairs(starter.locations) do
        if location.id == id then
            return {
                id = location.id,
                name = location.label,
                subtitle = location.description,
                door = plainDoor(location.door),
            }
        end
    end
end

---@param citizenid string
---@return MulticharSpawnPlace[]
local function ownedHouses(citizenid)
    if GetResourceState('cobalt_housing') ~= 'started' then return {} end

    local houses <const> = {}

    for i, property in ipairs(exports.cobalt_housing:GetOwnedProperties(citizenid)) do
        houses[i] = {
            id = property.id,
            name = property.name,
            subtitle = locale('spawn.property'),
            door = plainDoor(property.door),
        }
    end

    return houses
end

---@param value any
---@return table?
local function decode(value)
    return value and json.decode(value)
end

---@param character CoreAccountCharacter
---@return MulticharCharacter
local function toCharacter(character)
    local money <const> = character.money
    local meta <const> = character.metadata

    money.bank = bankBalance(character.citizenid) or money.bank or 0

    return {
        citizenid = character.citizenid,
        cid = character.cid,
        charinfo = character.charinfo,
        money = money,
        org = resolveOrg(character),
        position = character.position,
        isDead = meta.isdead == true or meta.inlaststand == true,
        lastPlayed = character.lastPlayed,
        starterApartment = starterApartment(meta.starterApartment),
        houses = ownedHouses(character.citizenid),
    }
end

---@param name string
---@return boolean
local function isBlockedName(name)
    local lowered <const> = name:lower()

    for _, fragment in ipairs(creation.blockedFragments) do
        if lowered:find(fragment:lower(), 1, true) then return true end
    end

    for word in lowered:gmatch("[^%s%-']+") do
        for _, blocked in ipairs(creation.blockedWords) do
            if word == blocked:lower() then return true end
        end
    end

    return false
end

---@param value unknown
---@return string?
local function parseName(value)
    if type(value) ~= 'string' then return end

    local name <const> = value:match('^%s*(.-)%s*$')

    if #name == 0 or #name > NAME_MAX or not name:match("^[%a%s%-']+$") then return end
    if isBlockedName(name) then return end

    return name
end

---@param year integer
---@param month integer
---@return integer
local function daysInMonth(year, month)
    local leap <const> = year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)

    if month == 2 and leap then return 29 end

    return DAYS_IN_MONTH[month]
end

---@param value unknown
---@return string?
local function parseBirthdate(value)
    if type(value) ~= 'string' then return end

    local y <const>, m <const>, d <const> = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not y then return end

    local year <const> = tonumber(y) --[[@as integer]]
    local month <const> = tonumber(m) --[[@as integer]]
    local day <const> = tonumber(d) --[[@as integer]]

    if year < creation.minYear or year > creation.maxYear then return end
    if month < 1 or month > 12 then return end
    if day < 1 or day > daysInMonth(year, month) then return end

    return value
end

---@param license string
---@param value unknown
---@return integer?
local function parseFreeSlot(license, value)
    local cid <const> = math.tointeger(value)
    if not cid or cid < 1 or cid > maxSlotsFor(license) then return end

    local taken <const> = MySQL.scalar.await(
        'SELECT 1 FROM players WHERE license = ? AND cid = ? LIMIT 1',
        { license, cid }
    )
    if taken then return end

    return cid
end

---@param license string
---@param data unknown
---@return MulticharNewCharacter?
local function parseNewCharacter(license, data)
    if type(data) ~= 'table' then return end

    local firstname <const> = parseName(data.firstname)
    local lastname <const> = parseName(data.lastname)
    local birthdate <const> = parseBirthdate(data.birthdate)
    local nationality <const> = data.nationality
    local gender <const> = math.tointeger(data.gender)

    if not firstname or not lastname or not birthdate then return end
    if not knownNationalities[nationality] then return end
    if gender ~= 0 and gender ~= 1 then return end

    local cid <const> = parseFreeSlot(license, data.cid)
    if not cid then return end

    return {
        cid = cid,
        charinfo = {
            firstname = firstname,
            lastname = lastname,
            nationality = nationality,
            birthdate = birthdate,
            gender = gender,
        },
    }
end

---@param source integer
local function returnToSelect(source)
    Cobalt.Player.Logout(source)
    TriggerClientEvent('cobalt_multicharacter:client:chooseChar', source)
end

Cobalt.Commands.Add('logout', locale('command.logout'), {}, false, returnToSelect, 'admin')

lib.callback.register('cobalt_multicharacter:server:getCharacters', function(source)
    local license <const> = Cobalt.Functions.GetIdentifier(source, 'license')
    if not license then return {}, 0 end

    local account <const> = exports.cobalt_core:GetAccount(license)
    local characters <const> = {}

    for i, character in ipairs(account?.characters or {}) do characters[i] = toCharacter(character) end

    return characters, maxSlotsFor(license)
end)

local OWN_ACTIVE_SKIN <const> = [[
    SELECT s.model, s.skin FROM playerskins s
    JOIN players p ON p.citizenid = s.citizenid
    WHERE s.citizenid = ? AND p.license = ? AND s.active = 1
    LIMIT 1
]]

lib.callback.register('cobalt_multicharacter:server:getSkin', function(source, citizenid)
    if type(citizenid) ~= 'string' then return end

    local license <const> = Cobalt.Functions.GetIdentifier(source, 'license')

    if not license then return end

    local result <const> = MySQL.single.await(OWN_ACTIVE_SKIN, { citizenid, license })
    local skin <const> = result and decode(result.skin)

    if type(skin) ~= 'table' then return end

    skin.model = skin.model or result.model

    return skin
end)

RegisterNetEvent('cobalt_multicharacter:server:loadCharacter', function(citizenid)
    local src <const> = source

    if type(citizenid) ~= 'string' or Cobalt.Functions.GetPlayer(src) then return end

    local ok <const>, loaded <const> = pcall(Cobalt.Player.Login, src, citizenid)

    if not ok then lib.print.error(('loading %s for %s failed: %s'):format(citizenid, src, loaded)) end

    if not ok or not loaded then
        if GetPlayerName(src) then TriggerClientEvent('cobalt_multicharacter:client:chooseChar', src) end

        return
    end

    exports.cobalt_core:LogPlayer(
        src,
        'multicharacter.loaded',
        ('Loaded character %s'):format(citizenid),
        { citizenid = citizenid }
    )
    Cobalt.Commands.Refresh(src)
    TriggerClientEvent('cobalt_multicharacter:client:closeNUI', src)
end)

lib.callback.register('cobalt_multicharacter:server:createCharacter', function(source, data)
    if Cobalt.Functions.GetPlayer(source) then return false end

    local license <const> = Cobalt.Functions.GetIdentifier(source, 'license')
    local newData <const> = license and parseNewCharacter(license, data)

    if not newData then
        exports.cobalt_core:Notify(source, locale('create.invalid'), 'error')
        return false
    end

    local ok <const>, result <const> = pcall(Cobalt.Player.Login, source, false, newData)

    if not ok then
        lib.print.error(('creating a character for %s failed: %s'):format(source, result))
        return false
    end

    if not result then return false end

    local name <const> = ('%s %s'):format(newData.charinfo.firstname, newData.charinfo.lastname)
    exports.cobalt_core:LogPlayer(
        source,
        'multicharacter.created',
        ('Created character %s'):format(name),
        { cid = newData.cid }
    )
    Cobalt.Commands.Refresh(source)

    local given <const>, err <const> = pcall(giveStarterItems, source)
    if not given then lib.print.error(('starter items for %s failed: %s'):format(source, err)) end

    TriggerClientEvent('cobalt_multicharacter:client:spawn', source)

    return true
end)

lib.callback.register('cobalt_multicharacter:server:deleteCharacter', function(source, citizenid)
    if not config.enableDeleteButton then return false end
    if type(citizenid) ~= 'string' then return false end
    if Cobalt.Functions.GetPlayer(source) then return false end

    exports.cobalt_core:LogPlayer(
        source,
        'multicharacter.deleted',
        ('Requested deletion of character %s'):format(citizenid),
        { citizenid = citizenid }
    )

    return Cobalt.Player.DeleteCharacter(source, citizenid)
end)

RegisterNetEvent('illenium-appearance:server:ResetRoutingBucket', function()
    TriggerClientEvent('cobalt_multicharacter:client:creatorClosed', source)
end)
