---@class MulticharSceneCam
---@field distance number meters in front of the ped along its heading
---@field height number camera height above the ground
---@field lookHeight number aim height on the ped
---@field gap { left: number, right: number } NUI rem from each screen edge to the clear gap between the rail and the details panel
---@field fov number
---@field introPullback number
---@field introRise number
---@field introMs integer

---@class MulticharSpawnView
---@field heading number compass heading the camera faces
---@field distance number meters back from the spawn point
---@field height number meters above the spawn point
---@field lookHeight number aim height above the spawn point

---@alias MulticharArrivalVariant 'bus' | 'taxi' | 'wave' | 'greeting' | 'wake' | 'stretch' | 'phone' | 'door' | 'room'

---@class MulticharSpawnArrival
---@field enabled boolean
---@field variants MulticharArrivalVariant[]
---@field locals string[] ped models for the NPCs in the scene

---@class MulticharCreation
---@field minYear integer
---@field maxYear integer
---@field blockedWords string[]
---@field blockedFragments string[]

---@class MulticharSpawn
---@field id string key of its name and description in locales/en.json, under spawn.<id>
---@field coords vector4
---@field view MulticharSpawnView
---@field arrival MulticharSpawnArrival

return {
    -- Fallback spawn when a character has no last location and picks nothing
    defaultSpawn = vector3(-1035.71, -2731.87, 12.86), -- x, y, z

    -- Character select scene
    scene = {
        pedCoords = vector4(-425.52, 1123.62, 325.85, 345.0), -- where the selected character stands (Galileo Observatory)
        time = { hours = 19, minutes = 30 }, -- clock shown during selection, for this player only
        weather = 'EXTRASUNNY', -- weather shown during selection
        ---@type MulticharSceneCam
        cam = {
            distance = 3.4, -- meters in front of the ped
            height = 1.0, -- camera height above the ground, in meters
            lookHeight = 0.85, -- aim height on the ped, in meters
            gap = { left = 30.25, right = 37.75 }, -- NUI rem from each screen edge to the gap between the list and the details panel
            fov = 40.0, -- field of view in degrees
            introPullback = 4.0, -- extra meters the camera starts back from the ped on open
            introRise = 1.5, -- extra meters the camera starts above on open
            introMs = 3500, -- milliseconds of the opening camera move
        },
        fadeSteps = 17, -- steps of the ped fade when switching characters
        fadeStepMs = 15, -- milliseconds per fade step
        confetti = { asset = 'scr_xs_celebration', effect = 'scr_xs_confetti_burst', scale = 1.0 }, -- particle burst each time a character appears
        idleAnim = { dict = 'anim@heists@heist_corona@single_team', clip = 'single_team_loop_boss' }, -- pose of the selected character
    },

    -- Creating and deleting characters; the nationalities a new character can pick are in data/nationalities.json
    enableDeleteButton = true, -- players can delete their own characters
    ---@type MulticharCreation
    creation = {
        minYear = 1940, -- earliest birth year a new character can have
        maxYear = 2008, -- latest birth year a new character can have
        blockedWords = { 'ass', 'dick' }, -- a first or last name with any of these as a whole word, in any case, is refused; for short words that sit inside real names (Hassan, Dickson)
        blockedFragments = { 'fuck', 'shit', 'bitch', 'nigger', 'nigga', 'faggot', 'cunt', 'retard' }, -- a first or last name containing any of these anywhere, in any case, is refused
    },

    -- Spawn points offered after picking a character
    ---@type MulticharSpawn[]
    spawns = {
        {
            id = 'legion', -- its name and description are spawn.legion.name and spawn.legion.description in locales/en.json
            coords = vector4(215.76, -932.08, 30.69, 3.54), -- spawn position and heading
            view = { heading = 160.0, distance = 34.0, height = 16.0, lookHeight = 4.0 }, -- preview camera: facing, meters back, meters up, aim height
            arrival = { -- arrival scene played on spawning here
                enabled = true, -- false spawns straight in
                variants = { 'bus', 'taxi', 'greeting' }, -- scenes tried in random order: bus, taxi, wave, greeting, wake, stretch, phone, door, room
                locals = { 'a_m_y_business_01', 'a_f_y_business_01', 'a_m_y_business_02', 'a_f_y_business_02' }, -- ped models for the NPCs
            },
        },
        {
            id = 'airport',
            coords = vector4(-1038.0, -2738.0, 20.0, 330.0),
            view = { heading = 150.0, distance = 46.0, height = 22.0, lookHeight = 6.0 },
            arrival = {
                enabled = true,
                variants = { 'taxi', 'greeting' },
                locals = { 'a_m_m_tourist_01', 'a_f_y_tourist_01', 's_f_y_airhostess_01' },
            },
        },
        {
            id = 'vespucci',
            coords = vector4(-1185.0, -1505.0, 4.38, 310.0),
            view = { heading = 40.0, distance = 30.0, height = 12.0, lookHeight = 2.0 },
            arrival = {
                enabled = true,
                variants = { 'wave', 'greeting' },
                locals = { 'a_f_y_beach_01', 'a_m_y_beach_01', 'a_f_y_hipster_01' },
            },
        },
        {
            id = 'sandy',
            coords = vector4(1784.0, 3646.0, 34.0, 300.0),
            view = { heading = 210.0, distance = 32.0, height = 14.0, lookHeight = 2.5 },
            arrival = {
                enabled = true,
                variants = { 'bus', 'wave', 'greeting' },
                locals = { 'a_m_m_hillbilly_01', 'a_f_m_salton_01', 'a_m_m_salton_01' },
            },
        },
        {
            id = 'paleto',
            coords = vector4(-106.0, 6314.0, 31.0, 136.0),
            view = { heading = 330.0, distance = 32.0, height = 13.0, lookHeight = 2.5 },
            arrival = {
                enabled = true,
                variants = { 'taxi', 'wave', 'greeting' },
                locals = { 'a_m_m_farmer_01', 'a_m_m_salton_01', 'a_f_m_salton_01' },
            },
        },
    },

    -- Camera flight to the chosen spawn
    spawnCam = {
        fov = 50.0, -- camera field of view during the flight, in degrees
        minMs = 1400, -- shortest flight, in milliseconds
        maxMs = 4800, -- longest flight, in milliseconds
        msPerKm = 700, -- extra milliseconds per kilometer travelled
        arcDistance = 400.0, -- meters under which the flight uses nearRise instead of arcRise
        arcRise = 0.22, -- arc height as a fraction of the distance for long flights
        arcMax = 1100.0, -- highest the arc climbs, in meters
        nearRise = 0.12, -- arc height as a fraction of the distance for short flights
        ---@type MulticharSpawnView
        defaultView = { heading = 0.0, distance = 22.0, height = 9.0, lookHeight = 1.5 }, -- camera for spawns without their own view (last location, apartment, house): heading in degrees added to the spawn's facing, distance back and height up in meters, lookHeight is the aim point above the spawn in meters
    },

    -- Short scenes that play when a character arrives
    arrival = {
        enabled = true, -- false spawns straight in with no scene
        skipAfterMs = 1500, -- milliseconds before a scene can be skipped
        timecycle = { name = 'NG_filmic02', strength = 0.35 }, -- colour grade during the scene
        lastLocation = { enabled = true, variants = { 'wake', 'stretch', 'phone' } }, -- spawning at the last location
        property = { enabled = true, variants = { 'door', 'stretch' } }, -- spawning at an owned property
        apartment = { enabled = true, variants = { 'room' } }, -- spawning in the starter apartment
        driver = 's_m_m_gentransport', -- driver model for the bus and taxi scenes
        bottle = { -- the bottle thrown in the wake-up scene
            minPhase = 0.2, -- earliest point in the get-up, 0 to 1, at which a hand swing counts as the throw
            handSpeed = 3.5, -- hand speed in meters per second that releases the bottle
            fallbackPhase = 0.7, -- point in the get-up, 0 to 1, at which the bottle is thrown if no swing was fast enough
        },
    },
}
