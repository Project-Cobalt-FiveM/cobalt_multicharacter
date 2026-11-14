local config <const> = require 'config'
local geometry <const> = require 'client.geometry'

local settings <const> = config.arrival

---@class MulticharArrivalContext
---@field clone integer
---@field spawn vector4
---@field locals string[]

---@class MulticharFraming
---@field distance number meters from the subject to the camera
---@field height number camera height above the subject's ground
---@field angle number degrees around the subject from the take's basis heading, 0 is in front
---@field fov number?
---@field spread number? extra meters of distance per meter between two subjects

---@class MulticharTake
---@field subjects integer[]
---@field weights number[] share of each subject in the point the camera centres on
---@field basis number heading the framing angle is measured from
---@field framing MulticharFraming

---@class MulticharAnchor
---@field center vector3 root position the subjects centre on at one moment of the take
---@field separation number meters between the subjects at that moment

---@class MulticharPose
---@field center vector3
---@field yaw number
---@field distance number
---@field height number
---@field fov number

---@class MulticharRig
---@field cam integer?
---@field take MulticharTake?
---@field from MulticharTake?
---@field started integer
---@field ms integer

---@class MulticharStop
---@field lane vector4 road position the vehicle parks on, heading with its kerb side towards the spawn
---@field door vector3 where a passenger steps out
---@field target vector3 open pavement the passenger walks to

---@class MulticharPairClip
---@field dict string
---@field a string clip for the arriving character
---@field b string clip for the NPC
---@field facial boolean whether the dict has `<clip>_facial` clips

---@class MulticharInteraction
---@field gap number meters between the two peds
---@field pair? fun(clone: integer, npc: integer): MulticharPairClip
---@field run? fun(clone: integer, npc: integer): boolean

---@alias MulticharArrivalRun fun(ctx: MulticharArrivalContext): boolean

local Arrival <const> = {}

local INTERACTION <const> = 'mp_ped_interaction'
local IDLE_DICT <const> = 'amb@world_human_hang_out_street@male_b@base'
local WAVE_DICT <const> = 'friends@frj@ig_1'
local STRETCH_DICT <const> = 'mini@triathlon'
local WAKE_DICT <const> = 'switch@trevor@slouched_get_up'
local DOOR_DICT <const> = 'switch@franklin@exit_building'
local FACIAL_DICT <const> = 'mp_facial'
local SOUNDSET <const> = 'PLAYER_SWITCH_CUSTOM_SOUNDSET'
local BOTTLE_MODEL <const> = `prop_cs_whiskey_bottle`
local PROP_HAND_BONE <const> = 28422
local SKIP_CONTROLS <const> = { 22, 191, 201 }
local FADE_MS <const> = 600
local NPC_FADE_MS <const> = 1000
local SHOT_FOV <const> = 42.0
local PED_ROOT_HEIGHT <const> = 0.98
local COLLISION_WAIT_MS <const> = 2000
local DEFAULT_LOCALS <const> = { 'a_m_y_genstreet_01', 'a_f_y_hipster_01', 'a_m_y_hipster_01' }
local WAVES <const> = { 'wave_a', 'wave_b', 'wave_c', 'wave_d', 'wave_e' }
local TALK <const> = {
    'gesture_you_soft', 'gesture_me', 'gesture_why', 'gesture_shrug_soft',
    'gesture_what_soft', 'gesture_pleased', 'gesture_easy_now', 'gesture_bring_it_on',
}
local APPROACH_ANGLES <const> = { 180.0, 150.0, 210.0, 120.0, 240.0, 90.0, 270.0 }
local PROBE_FLAGS <const> = 1 | 16
local AIM_ABOVE_ROOT <const> = 0.3
local HEAD_ABOVE_ROOT <const> = 0.7
local FEET_BELOW_ROOT <const> = 0.75
local NEAR_REACH <const> = 2.2
local NEAR_RAYS <const> = {
    { yaw = 0.0, drop = 0.0 },
    { yaw = 0.0, drop = 0.7 },
    { yaw = -28.0, drop = 0.6 },
    { yaw = 28.0, drop = 0.6 },
    { yaw = -28.0, drop = 0.0 },
    { yaw = 28.0, drop = 0.0 },
}
local DISTANCE_SCALES <const> = { 1.0, 0.8, 0.62 }
local MIN_CAM_DISTANCE <const> = 1.6
local SOLO <const> = { 1.0 }
local PAIR <const> = { 0.72, 0.28 }
---@type MulticharFraming
local FALLBACK_FRAMING <const> = { distance = 3.2, height = 1.5, angle = 25.0, fov = 40.0 }
local VEHICLE_BODY <const> = {
    [`bus`] = { halfWidth = 1.6, samples = { -5.5, -2.0, 1.5, 4.5 }, door = 4.2, seat = 0 },
    [`taxi`] = { halfWidth = 1.0, samples = { -2.0, 0.0, 2.0 }, door = -0.6, seat = 2 },
}

local SOLO_PLANS <const> = {
    last = settings.lastLocation,
    apartment = settings.apartment,
    house = settings.property,
}

---@type integer[]
local entities <const> = {}
---@type integer[]
local npcs <const> = {}
---@type integer[]
local cams <const> = {}
---@type integer[]
local scenes <const> = {}
---@type table<string, true>
local dicts <const> = {}

---@type MulticharRig
local rig <const> = { started = 0, ms = 0 }

local active = false
local skipped = false
---@type integer?
local skippableAt
local hintShown = false

---@generic T
---@param list T[]
---@return T
local function pick(list)
    return list[math.random(#list)]
end

---@generic T
---@param list T[]
---@return T[]
local function shuffled(list)
    local copy <const> = {}

    for i = 1, #list do copy[i] = list[i] end

    for i = #copy, 2, -1 do
        local j <const> = math.random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end

    return copy
end

---@param origin vector4
---@param forward number
---@param right number
---@param up number?
---@return vector3
local function offset(origin, forward, right, up)
    local rad <const> = math.rad(origin.w)
    local ahead <const> = geometry.forwardOf(origin.w)
    local side <const> = vector3(math.cos(rad), math.sin(rad), 0.0)

    return origin.xyz + ahead * forward + side * right + vector3(0.0, 0.0, up or 0.0)
end

---@param from vector3
---@param to vector3
---@return number
local function headingTo(from, to)
    return GetHeadingFromVector_2d(to.x - from.x, to.y - from.y)
end

---@param pos vector3
---@return vector3
local function grounded(pos)
    local found <const>, z <const> = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
    return found and vector3(pos.x, pos.y, z) or pos
end

---@param from vector3
---@param to vector3
---@param ignore integer?
---@return boolean
local function clear(from, to, ignore)
    local probe <const> = StartExpensiveSynchronousShapeTestLosProbe(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        PROBE_FLAGS, ignore or 0, 7
    )
    local _ <const>, hit <const> = GetShapeTestResult(probe)

    return hit ~= 1
end

---@param from vector3 ground position
---@param to vector3 ground position
---@return boolean
local function walkable(from, to)
    local a <const>, b <const> = grounded(from), grounded(to)
    local mid <const> = grounded((a + b) / 2.0)

    if math.abs(a.z - b.z) > 0.6 or math.abs(a.z - mid.z) > 0.6 then return false end

    local knee <const>, chest <const> = vector3(0.0, 0.0, 0.5), vector3(0.0, 0.0, 1.3)

    return clear(a + knee, b + knee) and clear(a + chest, b + chest)
end

---@param target vector4 ground position and heading of the end point
---@param distance number
---@return vector3?
local function approachFrom(target, distance)
    for _, angle in ipairs(APPROACH_ANGLES) do
        local start <const> = offset(vector4(target.x, target.y, target.z, (target.w + angle) % 360.0), distance, 0.0)

        if walkable(start, target.xyz) then return grounded(start) end
    end
end

---@param dict string
local function loadDict(dict)
    lib.requestAnimDict(dict)
    dicts[dict] = true
end

---@param entity integer
---@param fades boolean?
---@return integer
local function track(entity, fades)
    entities[#entities + 1] = entity

    if fades then npcs[#npcs + 1] = entity end

    return entity
end

---@param model string | integer
---@param pos vector3
---@param heading number
---@return integer
local function localPed(model, pos, heading)
    local hash <const> = type(model) == 'string' and joaat(model) or model --[[@as integer]]
    lib.requestModel(hash)

    local ground <const> = grounded(pos)
    local ped <const> = track(CreatePed(4, hash, ground.x, ground.y, ground.z, heading, false, false), true)

    SetModelAsNoLongerNeeded(hash)
    SetEntityCoordsNoOffset(ped, ground.x, ground.y, ground.z + PED_ROOT_HEIGHT, false, false, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedRandomComponentVariation(ped, 0)

    return ped
end

---@param model integer
---@param pos vector3
---@param heading number
---@return integer
local function localVehicle(model, pos, heading)
    lib.requestModel(model)

    local vehicle <const> = track(CreateVehicle(model, pos.x, pos.y, pos.z, heading, false, false), true)

    SetModelAsNoLongerNeeded(model)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetEntityInvincible(vehicle, true)

    return vehicle
end

---@param center vector3 root position of the subject
---@param yaw number heading from the subject to the camera
---@param distance number
---@param height number above the subject's ground
---@return vector3
local function camAt(center, yaw, distance, height)
    return center + geometry.forwardOf(yaw) * distance + vector3(0.0, 0.0, height - PED_ROOT_HEIGHT)
end

---@param pos vector3 camera position
---@param center vector3 root position of the subject
---@return boolean
local function viewClear(pos, center)
    local chest <const> = center + vector3(0.0, 0.0, AIM_ABOVE_ROOT)

    if not clear(chest, pos) then return false end
    if not clear(center + vector3(0.0, 0.0, HEAD_ABOVE_ROOT), pos) then return false end
    if not clear(center - vector3(0.0, 0.0, FEET_BELOW_ROOT), pos) then return false end

    local view <const> = chest - pos
    local heading <const> = GetHeadingFromVector_2d(view.x, view.y)
    local rise <const> = view.z / #view * NEAR_REACH

    for _, ray in ipairs(NEAR_RAYS) do
        local reach <const> = geometry.forwardOf(heading + ray.yaw) * NEAR_REACH + vector3(0.0, 0.0, rise - ray.drop)

        if not clear(pos, pos + reach) then return false end
    end

    return true
end

---@param angle number
---@return number[]
local function anglesAround(angle)
    return {
        angle, -angle,
        angle + 20.0, -angle - 20.0,
        angle - 20.0, -angle + 20.0,
        angle + 50.0, -angle - 50.0,
        90.0, -90.0, 180.0,
    }
end

---Picks the framing nearest the one asked for whose camera sees every anchor with nothing in the foreground.
---@param anchors MulticharAnchor[]
---@param basis number
---@param framing MulticharFraming
---@return MulticharFraming
local function frame(anchors, basis, framing)
    local best, bestScore = framing, -1

    for _, scale in ipairs(DISTANCE_SCALES) do
        for _, angle in ipairs(anglesAround(framing.angle)) do
            ---@type MulticharFraming
            local candidate <const> = {
                distance = math.max(MIN_CAM_DISTANCE, framing.distance * scale),
                height = framing.height,
                angle = angle,
                fov = framing.fov,
                spread = framing.spread,
            }
            local score = 0

            for _, anchor in ipairs(anchors) do
                local distance <const> = candidate.distance + anchor.separation * (candidate.spread or 0.0)

                if viewClear(camAt(anchor.center, basis + angle, distance, candidate.height), anchor.center) then
                    score += 1
                end
            end

            if score == #anchors then return candidate end
            if score > bestScore then best, bestScore = candidate, score end
        end
    end

    return best
end

---@param ground vector3
---@return MulticharAnchor
local function soloAnchor(ground)
    return { center = ground + vector3(0.0, 0.0, PED_ROOT_HEIGHT), separation = 0.0 }
end

---@param ground vector3 the character's ground position
---@param other vector3 the other ped's ground position
---@return MulticharAnchor
local function pairAnchor(ground, other)
    return {
        center = ground * PAIR[1] + other * PAIR[2] + vector3(0.0, 0.0, PED_ROOT_HEIGHT),
        separation = #(ground.xy - other.xy),
    }
end

---@param ped integer
---@param basis number
---@param framing MulticharFraming
---@return MulticharTake
local function solo(ped, basis, framing)
    return { subjects = { ped }, weights = SOLO, basis = basis, framing = framing }
end

---@param ped integer
---@param other integer
---@param basis number
---@param framing MulticharFraming
---@return MulticharTake
local function pair(ped, other, basis, framing)
    return { subjects = { ped, other }, weights = PAIR, basis = basis, framing = framing }
end

---@param take MulticharTake
---@return MulticharPose
local function poseOf(take)
    local subjects <const> = take.subjects
    local center = vector3(0.0, 0.0, 0.0)

    for i, subject in ipairs(subjects) do
        center += GetEntityCoords(subject) * take.weights[i]
    end

    local separation <const> = #subjects > 1
        and #(GetEntityCoords(subjects[1]).xy - GetEntityCoords(subjects[2]).xy)
        or 0.0
    local framing <const> = take.framing

    return {
        center = center,
        yaw = take.basis + framing.angle,
        distance = framing.distance + separation * (framing.spread or 0.0),
        height = framing.height,
        fov = framing.fov or SHOT_FOV,
    }
end

---@param from MulticharPose
---@param to MulticharPose
---@param t number
---@return MulticharPose
local function blend(from, to, t)
    local e <const> = t * t * (3.0 - 2.0 * t)

    return {
        center = from.center + (to.center - from.center) * e,
        yaw = from.yaw + ((to.yaw - from.yaw + 540.0) % 360.0 - 180.0) * e,
        distance = from.distance + (to.distance - from.distance) * e,
        height = from.height + (to.height - from.height) * e,
        fov = from.fov + (to.fov - from.fov) * e,
    }
end

---@return MulticharPose
local function rigPose()
    local current <const> = poseOf(rig.take --[[@as MulticharTake]])
    local from <const> = rig.from

    if not from then return current end

    local t <const> = (GetGameTimer() - rig.started) / rig.ms

    if t >= 1.0 then
        rig.from = nil
        return current
    end

    return blend(poseOf(from), current, t)
end

---@param cam integer
---@param pose MulticharPose
local function place(cam, pose)
    local pos <const> = camAt(pose.center, pose.yaw, pose.distance, pose.height)
    local look <const> = pose.center + vector3(0.0, 0.0, AIM_ABOVE_ROOT)

    SetCamCoord(cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    SetCamFov(cam, pose.fov)
    SetCamNearDof(cam, math.max(0.1, pose.distance - 1.5))
    SetCamFarDof(cam, pose.distance + 6.0)
end

---Films a take with one camera that tracks its subjects every frame, easing over from the previous take.
---@param take MulticharTake
---@param ms integer?
local function follow(take, ms)
    rig.from = ms and ms > 0 and rig.take or nil
    rig.take, rig.started, rig.ms = take, GetGameTimer(), ms or 0

    if rig.cam then return end

    local cam <const> = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)

    cams[#cams + 1] = cam
    rig.cam = cam
    SetCamUseShallowDofMode(cam, true)
    SetCamDofStrength(cam, 0.5)
    place(cam, rigPose())
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    CreateThread(function()
        while active and rig.cam == cam do
            place(cam, rigPose())
            Wait(0)
        end
    end)
end

---@param ms integer
---@return boolean finished false when the player skipped
local function wait(ms)
    local deadline <const> = GetGameTimer() + ms

    while GetGameTimer() < deadline do
        if skipped then return false end
        Wait(0)
    end

    return not skipped
end

---@param done fun(): boolean
---@param timeout integer
---@return boolean finished false when the player skipped
local function waitUntil(done, timeout)
    pcall(lib.waitFor, function() return skipped or done() or nil end, nil, timeout)

    return not skipped
end

---@param ped integer
---@param target vector3
---@param range number
---@return fun(): boolean
local function arrivedAt(ped, target, range)
    return function()
        return #(GetEntityCoords(ped).xy - target.xy) <= range
    end
end

---@param ped integer
---@param dict string
---@param clip string
---@param flag integer?
local function playAnim(ped, dict, clip, flag)
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, flag or 0, 0.0, false, false, false)
end

---@param dict string
---@param clip string
---@return integer
local function clipMs(dict, clip)
    return math.floor(GetAnimDuration(dict, clip) * 1000)
end

local function reveal()
    DoScreenFadeIn(FADE_MS)
    PlaySoundFrontend(-1, 'Hit_Out', SOUNDSET, true)
    skippableAt = GetGameTimer() + settings.skipAfterMs
end

---@param origin vector4
---@param dict string
---@param peds { ped: integer, clip: string }[]
---@param camClip string? the scene's own camera, left out when the follow rig films it
---@return integer scene
---@return integer? cam
local function syncedScene(origin, dict, peds, camClip)
    local scene <const> = CreateSynchronizedScene(origin.x, origin.y, origin.z, 0.0, 0.0, origin.w, 2)
    scenes[#scenes + 1] = scene

    for _, entry in ipairs(peds) do
        TaskSynchronizedScene(entry.ped, scene, dict, entry.clip, 1000.0, -8.0, 0, 0, 1000.0, 0)
    end

    if not camClip then return scene end

    local handle <const> = CreateCam('DEFAULT_ANIMATED_CAMERA', true)
    cams[#cams + 1] = handle

    PlaySynchronizedCamAnim(handle, scene, camClip, dict)
    SetCamActive(handle, true)
    RenderScriptCams(true, false, 0, true, true)

    return scene, handle
end

---Swaps a scene's own camera for the follow rig when a wall or prop stands between it and the character.
---@param ctx MulticharArrivalContext
---@param animCam integer
---@return boolean rigged
local function guardAnimCam(ctx, animCam)
    Wait(0)

    if viewClear(GetCamCoord(animCam), GetEntityCoords(ctx.clone)) then return false end

    local spawn <const> = ctx.spawn

    SetCamActive(animCam, false)
    follow(solo(ctx.clone, spawn.w, frame({ soloAnchor(spawn.xyz) }, spawn.w, FALLBACK_FRAMING)))

    return true
end

---@param scene integer
---@param timeout integer
---@return boolean finished
local function sceneDone(scene, timeout)
    return waitUntil(function() return GetSynchronizedScenePhase(scene) >= 0.98 end, timeout)
end

---@param ped integer
---@return string
local function gestureDict(ped)
    return IsPedMale(ped) and 'gestures@m@standing@casual' or 'gestures@f@standing@casual'
end

---@param ped integer
---@param clip string
---@return string dict
local function react(ped, clip)
    local dict <const> = gestureDict(ped)

    loadDict(dict)
    playAnim(ped, dict, clip, 48)

    return dict
end

---@param ped integer
---@param clip string
---@return boolean finished
local function gesture(ped, clip)
    return wait(math.floor(clipMs(react(ped, clip), clip) * 0.85))
end

---@param ped integer
local function talk(ped)
    loadDict(FACIAL_DICT)
    PlayFacialAnim(ped, 'mic_chatter', FACIAL_DICT)
end

---@param a integer
---@param b integer
---@return boolean finished
local function faceEachOther(a, b)
    TaskTurnPedToFaceEntity(a, b, 900)
    TaskTurnPedToFaceEntity(b, a, 900)

    if not wait(900) then return false end

    local posA <const>, posB <const> = GetEntityCoords(a), GetEntityCoords(b)

    SetEntityHeading(a, headingTo(posA, posB))
    SetEntityHeading(b, headingTo(posB, posA))
    TaskLookAtEntity(a, b, -1, 2048, 3)
    TaskLookAtEntity(b, a, -1, 2048, 3)

    return true
end

---@param kind string
---@return fun(clone: integer, npc: integer): MulticharPairClip
local function celebration(kind)
    return function(clone, npc)
        local male <const>, otherMale <const> = IsPedMale(clone), IsPedMale(npc)
        local pairing <const> = (male and otherMale) and 'm_m' or (not male and not otherMale) and 'f_f' or 'f_m'

        return {
            dict = ('anim@mp_player_intcelebrationpaired@%s_%s'):format(pairing, kind),
            a = ('%s_left'):format(kind),
            b = ('%s_right'):format(kind),
            facial = true,
        }
    end
end

---@param a string
---@param b string
---@return fun(): MulticharPairClip
local function interactionPair(a, b)
    return function()
        return { dict = INTERACTION, a = a, b = b, facial = false }
    end
end

---@type table<string, MulticharInteraction>
local interactions <const> = {
    handshake = { gap = 0.9, pair = interactionPair('handshake_guy_a', 'handshake_guy_b') },
    hug = { gap = 1.05, pair = interactionPair('hugs_guy_a', 'hugs_guy_b') },
    highfive = { gap = 0.9, pair = interactionPair('highfive_guy_a', 'highfive_guy_b') },
    fistbump = { gap = 1.0, pair = celebration('fist_bump') },
    brohug = { gap = 1.0, pair = celebration('bro_hug') },
    chat = {
        gap = 1.3,
        run = function(clone, npc)
            talk(npc)
            if not gesture(npc, 'gesture_hello') then return false end
            if not gesture(clone, 'gesture_hello') then return false end

            for turn = 1, 4 do
                local speaker <const>, listener <const> = turn % 2 == 1 and npc or clone, turn % 2 == 1 and clone or npc

                talk(speaker)
                react(listener, pick({ 'gesture_nod_yes_soft', 'gesture_pleased' }))

                if not gesture(speaker, pick(TALK)) then return false end
            end

            if not gesture(npc, 'gesture_bye_soft') then return false end

            return gesture(clone, 'gesture_bye_soft')
        end,
    },
    directions = {
        gap = 1.4,
        run = function(clone, npc)
            talk(clone)
            if not gesture(clone, 'gesture_what_soft') then return false end

            talk(npc)
            if not gesture(npc, 'gesture_point') then return false end
            if not gesture(npc, pick({ 'gesture_hand_left', 'gesture_hand_right' })) then return false end
            if not gesture(clone, 'gesture_nod_yes_soft') then return false end

            talk(clone)

            return gesture(clone, 'gesture_bye_soft')
        end,
    },
}

---@return MulticharInteraction
local function pickInteraction()
    local names <const> = {}

    for name in pairs(interactions) do names[#names + 1] = name end

    table.sort(names)

    return interactions[pick(names)]
end

---@param clone integer
---@param npc integer
---@param interaction MulticharInteraction
---@return boolean finished
local function interact(clone, npc, interaction)
    if not faceEachOther(clone, npc) then return false end

    if interaction.run then return interaction.run(clone, npc) end

    local pair <const> = interaction.pair

    if not pair then return true end

    local clips <const> = pair(clone, npc)

    loadDict(clips.dict)
    playAnim(clone, clips.dict, clips.a)
    playAnim(npc, clips.dict, clips.b)

    if clips.facial then
        PlayFacialAnim(clone, ('%s_facial'):format(clips.a), clips.dict)
        PlayFacialAnim(npc, ('%s_facial'):format(clips.b), clips.dict)
    end

    return wait(clipMs(clips.dict, clips.a))
end

---@type table<MulticharArrivalVariant, MulticharArrivalRun>
local variants <const> = {}

---@param spawn vector4
---@param model integer
---@return MulticharStop?
local function findStop(spawn, model)
    local body <const> = VEHICLE_BODY[model]

    for nth = 1, 12 do
        local found <const>, node <const>, nodeHeading <const> = GetNthClosestVehicleNodeWithHeading(
            spawn.x, spawn.y, spawn.z,
            nth, 1, 3.0, 0
        )

        if found and #(node.xy - spawn.xy) <= 45.0 then
            local lane = vector4(node.x, node.y, node.z, nodeHeading)

            if #(offset(lane, 0.0, 1.0) - spawn.xyz) > #(offset(lane, 0.0, -1.0) - spawn.xyz) then
                lane = vector4(node.x, node.y, node.z, (nodeHeading + 180.0) % 360.0)
            end

            local bodyClear = true

            for _, along in ipairs(body.samples) do
                if not clear(offset(lane, along, 0.0, 1.2), offset(lane, along, body.halfWidth + 0.6, 1.2)) then
                    bodyClear = false
                    break
                end
            end

            local door <const> = grounded(offset(lane, body.door, body.halfWidth + 0.7, 0.5))
            local target <const> = grounded(offset(lane, body.door + 0.8, body.halfWidth + 3.4, 0.5))

            if bodyClear and walkable(door, target) then
                return { lane = lane, door = door, target = target }
            end
        end
    end
end

---@param ctx MulticharArrivalContext
---@param model integer
---@param commuters integer
---@return boolean
local function dropoff(ctx, model, commuters)
    local stop <const> = findStop(ctx.spawn, model)

    if not stop then return false end

    local body <const> = VEHICLE_BODY[model]
    local lane <const> = stop.lane
    local vehicle <const> = localVehicle(model, lane.xyz, lane.w)
    local driver <const> = localPed(settings.driver, lane.xyz, lane.w)
    local seats <const> = GetVehicleModelNumberOfSeats(model) - 1
    local cloneSeat <const> = math.min(body.seat, seats - 1)

    SetPedIntoVehicle(driver, vehicle, -1)
    SetPedIntoVehicle(ctx.clone, vehicle, cloneSeat)

    ---@type integer[]
    local riders <const> = {}

    for seat = 1, math.min(commuters, seats - 1) do
        if seat ~= cloneSeat then
            local rider <const> = localPed(pick(ctx.locals), lane.xyz, lane.w)
            SetPedIntoVehicle(rider, vehicle, seat)
            riders[#riders + 1] = rider
        end
    end

    local facing <const> = headingTo(stop.door, stop.target)
    local seated <const> = { soloAnchor(stop.door) }
    local walk <const> = { soloAnchor(stop.door), soloAnchor(stop.target) }
    local wide <const> = frame(seated, facing, { distance = 5.5, height = 1.7, angle = 35.0, fov = 45.0 })
    local close <const> = frame(walk, facing, { distance = 3.2, height = 1.5, angle = 25.0, fov = 40.0 })

    follow(solo(ctx.clone, facing, wide))
    reveal()

    if not wait(900) then return true end

    for _, rider in ipairs(riders) do
        TaskLeaveVehicle(rider, vehicle, 0)
        if not wait(700) then return true end
    end

    TaskLeaveVehicle(ctx.clone, vehicle, 0)

    if not waitUntil(function() return not IsPedInAnyVehicle(ctx.clone, false) end, 6000) then return true end

    for _, rider in ipairs(riders) do
        TaskWanderStandard(rider, 10.0, 10)
    end

    TaskGoStraightToCoord(ctx.clone, stop.target.x, stop.target.y, stop.target.z, 1.0, 6000, facing, 0.2)
    TaskVehicleDriveWander(driver, vehicle, 10.0, 786603)
    follow(solo(ctx.clone, facing, close), 2500)

    if waitUntil(arrivedAt(ctx.clone, stop.target, 0.6), 7000) then wait(700) end

    return true
end

variants.bus = function(ctx)
    return dropoff(ctx, `bus`, 3)
end

variants.taxi = function(ctx)
    return dropoff(ctx, `taxi`, 0)
end

variants.greeting = function(ctx)
    local spawn <const> = ctx.spawn
    local interaction <const> = pickInteraction()
    local friendPos <const> = offset(spawn, interaction.gap, 0.0)
    local start <const> = approachFrom(spawn, 5.0)

    if not start or not walkable(spawn.xyz, friendPos) then return false end

    local friend <const> = localPed(pick(ctx.locals), friendPos, headingTo(friendPos, start))

    loadDict(IDLE_DICT)
    SetEntityCoordsNoOffset(ctx.clone, start.x, start.y, start.z + PED_ROOT_HEIGHT, false, false, false)
    SetEntityHeading(ctx.clone, headingTo(start, spawn.xyz))
    playAnim(friend, IDLE_DICT, 'base', 1)
    TaskLookAtEntity(friend, ctx.clone, -1, 2048, 3)

    local basis <const> = headingTo(spawn.xyz, friendPos) + 90.0
    local anchors <const> = { pairAnchor(start, friendPos), pairAnchor(spawn.xyz, friendPos) }
    local opening <const> = frame(anchors, basis, {
        distance = 2.7,
        height = 1.6,
        angle = 25.0,
        fov = 40.0,
        spread = 0.95,
    })
    local settled <const> = frame(anchors, basis, {
        distance = 2.7,
        height = 1.45,
        angle = 0.0,
        fov = 40.0,
        spread = 0.95,
    })

    follow(pair(ctx.clone, friend, basis, opening))
    follow(pair(ctx.clone, friend, basis, settled), 5500)
    reveal()

    TaskGoStraightToCoord(ctx.clone, spawn.x, spawn.y, spawn.z, 1.0, 7000, headingTo(spawn.xyz, friendPos), 0.2)

    if not waitUntil(arrivedAt(ctx.clone, spawn.xyz, 0.35), 7000) then return true end

    ClearPedTasks(friend)

    if not interact(ctx.clone, friend, interaction) then return true end

    TaskWanderStandard(friend, 10.0, 10)
    wait(900)

    return true
end

variants.wave = function(ctx)
    local spawn <const> = ctx.spawn
    local interaction <const> = pickInteraction()
    local neighbourPos <const> = offset(spawn, 4.5, -3.0)
    local start <const> = approachFrom(spawn, 4.0)

    if not start or not walkable(spawn.xyz, neighbourPos) then return false end

    local neighbour <const> = localPed(pick(ctx.locals), neighbourPos, headingTo(neighbourPos, start))
    local meet <const> = neighbourPos + (spawn.xyz - neighbourPos) / #(spawn.xyz - neighbourPos) * interaction.gap
    local gestures <const> = gestureDict(ctx.clone)

    loadDict(WAVE_DICT)
    loadDict(gestures)
    SetEntityCoordsNoOffset(ctx.clone, start.x, start.y, start.z + PED_ROOT_HEIGHT, false, false, false)
    SetEntityHeading(ctx.clone, headingTo(start, spawn.xyz))
    TaskLookAtEntity(neighbour, ctx.clone, -1, 2048, 3)

    local basis <const> = headingTo(start, neighbourPos) + 90.0
    local anchors <const> = {
        pairAnchor(start, neighbourPos),
        pairAnchor(spawn.xyz, neighbourPos),
        pairAnchor(meet, neighbourPos),
    }
    local opening <const> = frame(anchors, basis, {
        distance = 2.7,
        height = 1.6,
        angle = 20.0,
        fov = 40.0,
        spread = 0.95,
    })
    local settled <const> = frame(anchors, basis, {
        distance = 2.7,
        height = 1.45,
        angle = 0.0,
        fov = 40.0,
        spread = 0.95,
    })

    follow(pair(ctx.clone, neighbour, basis, opening))
    follow(pair(ctx.clone, neighbour, basis, settled), 6500)
    reveal()

    TaskGoStraightToCoord(ctx.clone, spawn.x, spawn.y, spawn.z, 1.0, 7000, headingTo(spawn.xyz, neighbourPos), 0.2)

    if not wait(1200) then return true end

    playAnim(neighbour, WAVE_DICT, pick(WAVES))

    if not wait(800) then return true end

    playAnim(ctx.clone, gestures, 'gesture_hello', 48)

    if not waitUntil(arrivedAt(ctx.clone, spawn.xyz, 0.5), 6000) then return true end

    TaskGoStraightToCoord(ctx.clone, meet.x, meet.y, meet.z, 1.0, 5000, headingTo(meet, neighbourPos), 0.15)

    if not waitUntil(arrivedAt(ctx.clone, meet, 0.3), 5000) then return true end
    if not interact(ctx.clone, neighbour, interaction) then return true end

    TaskStartScenarioInPlace(neighbour, 'WORLD_HUMAN_SMOKING', 0, true)
    wait(900)

    return true
end

---@param bottle integer
---@param velocity vector3
local function throwBottle(bottle, velocity)
    DetachEntity(bottle, true, true)
    SetEntityCollision(bottle, true, true)
    ActivatePhysics(bottle)
    SetEntityVelocity(bottle, velocity.x, velocity.y, math.max(velocity.z, 1.8))

    CreateThread(function()
        Wait(150)

        local deadline <const> = GetGameTimer() + 2500

        while DoesEntityExist(bottle) and not HasEntityCollidedWithAnything(bottle) and GetGameTimer() < deadline do
            Wait(0)
        end

        if not DoesEntityExist(bottle) then return end

        local pos <const> = GetEntityCoords(bottle)

        UseParticleFxAsset('core')
        StartParticleFxNonLoopedAtCoord(
            'ent_dst_glass_bottles',
            pos.x, pos.y, pos.z,
            0.0, 0.0, 0.0,
            1.0, false, false, false
        )
        PlaySoundFromCoord(-1, 'Glass_Smash', pos.x, pos.y, pos.z, 'FBI_HEIST_RAID', false, 0, false)
        DeleteEntity(bottle)
    end)
end

---@param clone integer
---@param scene integer
---@param bottle integer
---@return boolean finished
local function watchThrow(clone, scene, bottle)
    local bone <const> = GetPedBoneIndex(clone, PROP_HAND_BONE)
    local throw <const> = settings.bottle
    local last = GetWorldPositionOfEntityBone(clone, bone)
    local lastTime = GetGameTimer()

    return waitUntil(function()
        local phase <const> = GetSynchronizedScenePhase(scene)
        local hand <const> = GetWorldPositionOfEntityBone(clone, bone)
        local now <const> = GetGameTimer()
        local velocity <const> = (hand - last) / math.max(0.001, (now - lastTime) / 1000.0)

        last, lastTime = hand, now

        if IsEntityAttached(bottle) then
            if phase >= throw.minPhase and #velocity >= throw.handSpeed then
                throwBottle(bottle, velocity * 1.15)
            elseif phase >= throw.fallbackPhase then
                throwBottle(bottle, geometry.forwardOf(GetEntityHeading(clone)) * 5.5 + vector3(0.0, 0.0, 2.5))
            end
        end

        return phase >= 0.98
    end, 10000)
end

variants.wake = function(ctx)
    local spawn <const> = ctx.spawn

    loadDict(WAKE_DICT)
    lib.requestModel(BOTTLE_MODEL)

    local idle <const>, idleCam <const> = syncedScene(spawn, WAKE_DICT, {
        { ped = ctx.clone, clip = 'trev_slouched_get_up_idle' },
    }, 'trev_slouched_get_up_idle_cam')
    local bottle <const> = track(CreateObject(BOTTLE_MODEL, spawn.x, spawn.y, spawn.z, false, false, false))

    SetModelAsNoLongerNeeded(BOTTLE_MODEL)
    SetEntityCollision(bottle, false, false)
    AttachEntityToEntity(
        bottle, ctx.clone, GetPedBoneIndex(ctx.clone, PROP_HAND_BONE),
        0.0, 0.0, -0.06,
        0.0, 0.0, 0.0,
        true, true, false, false, 2, true
    )
    SetSynchronizedSceneLooped(idle, true)

    local rigged <const> = guardAnimCam(ctx, idleCam --[[@as integer]])

    reveal()

    if not wait(2200) then return true end

    local exit <const>, exitCam <const> = syncedScene(spawn, WAKE_DICT, {
        { ped = ctx.clone, clip = 'trev_slouched_get_up_exit' },
    }, not rigged and 'trev_slouched_get_up_exit_cam' or nil)

    if exitCam then guardAnimCam(ctx, exitCam) end

    PlayFacialAnim(ctx.clone, 'trev_slouched_get_up_exit_facial', WAKE_DICT)
    watchThrow(ctx.clone, exit, bottle)

    return true
end

variants.door = function(ctx)
    loadDict(DOOR_DICT)

    local scene <const>, cam <const> = syncedScene(ctx.spawn, DOOR_DICT, {
        { ped = ctx.clone, clip = 'switch_01' },
    }, 'switch_01_cam')

    guardAnimCam(ctx, cam --[[@as integer]])
    reveal()
    sceneDone(scene, 10000)

    return true
end

variants.stretch = function(ctx)
    local spawn <const> = ctx.spawn

    loadDict(STRETCH_DICT)
    playAnim(ctx.clone, STRETCH_DICT, 'idle_e')

    local anchors <const> = { soloAnchor(spawn.xyz) }

    follow(solo(ctx.clone, spawn.w, frame(anchors, spawn.w, {
        distance = 6.0,
        height = 4.0,
        angle = 30.0,
        fov = 45.0,
    })))
    follow(solo(ctx.clone, spawn.w, frame(anchors, spawn.w, {
        distance = 3.0,
        height = 1.5,
        angle = 20.0,
        fov = 40.0,
    })), 4500)
    reveal()
    wait(math.max(5500, clipMs(STRETCH_DICT, 'idle_e')))

    return true
end

variants.phone = function(ctx)
    local spawn <const> = ctx.spawn

    TaskStartScenarioInPlace(ctx.clone, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

    local anchors <const> = { soloAnchor(spawn.xyz) }

    follow(solo(ctx.clone, spawn.w, frame(anchors, spawn.w, {
        distance = 3.6,
        height = 1.6,
        angle = -50.0,
        fov = 45.0,
    })))
    follow(solo(ctx.clone, spawn.w, frame(anchors, spawn.w, {
        distance = 2.8,
        height = 1.4,
        angle = 20.0,
        fov = 38.0,
    })), 6000)
    reveal()

    if not wait(4800) then return true end

    ClearPedTasks(ctx.clone)
    wait(1600)

    return true
end

variants.room = function(ctx)
    local spawn <const> = ctx.spawn

    loadDict(STRETCH_DICT)
    playAnim(ctx.clone, STRETCH_DICT, 'idle_e')

    local anchors <const> = { soloAnchor(spawn.xyz) }

    follow(solo(ctx.clone, spawn.w, frame(anchors, spawn.w, {
        distance = 2.4,
        height = 1.5,
        angle = 15.0,
        fov = 45.0,
    })))
    follow(solo(ctx.clone, spawn.w, frame(anchors, spawn.w, {
        distance = 2.0,
        height = 1.45,
        angle = 5.0,
        fov = 40.0,
    })), 5000)
    reveal()
    wait(math.max(5000, clipMs(STRETCH_DICT, 'idle_e')))

    return true
end

local function runFrame()
    CreateThread(function()
        while active do
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            SetUseHiDof()

            if skippableAt and GetGameTimer() >= skippableAt then
                if not hintShown then
                    hintShown = true
                    exports.cobalt_core:ShowTextUI(locale('arrival.skip'))
                end

                for _, control in ipairs(SKIP_CONTROLS) do
                    if IsDisabledControlJustPressed(0, control) then skipped = true end
                end
            end

            Wait(0)
        end
    end)
end

local function fadeOutNpcs()
    local started <const> = GetGameTimer()

    while GetGameTimer() - started < NPC_FADE_MS do
        local alpha <const> = math.floor(255 * (1.0 - (GetGameTimer() - started) / NPC_FADE_MS))

        for _, entity in ipairs(npcs) do
            if DoesEntityExist(entity) then SetEntityAlpha(entity, alpha, false) end
        end

        Wait(0)
    end
end

---@param ease boolean
local function cleanup(ease)
    active = false
    skippableAt = nil

    if hintShown then exports.cobalt_core:HideTextUI() end

    hintShown = false

    RenderScriptCams(false, ease, ease and 900 or 0, true, true)

    for i = #entities, 1, -1 do
        local entity <const> = entities[i]
        if DoesEntityExist(entity) then DeleteEntity(entity) end
        entities[i] = nil
    end

    table.wipe(npcs)
    rig.cam, rig.take, rig.from = nil, nil, nil

    for i = #cams, 1, -1 do
        if DoesCamExist(cams[i]) then DestroyCam(cams[i], false) end
        cams[i] = nil
    end

    for i = #scenes, 1, -1 do
        DisposeSynchronizedScene(scenes[i])
        scenes[i] = nil
    end

    for dict in pairs(dicts) do
        RemoveAnimDict(dict)
        dicts[dict] = nil
    end

    ClearTimecycleModifier()
end

---@param target MulticharSpawnTarget
---@return MulticharArrivalVariant[]? variants
---@return string[] locals
local function planFor(target)
    if not settings.enabled then return nil, DEFAULT_LOCALS end

    if target.kind == 'favorite' then
        local index <const> = math.tointeger(target.id)
        local entry <const> = index and config.spawns[index + 1]
        local arrival <const> = entry?.arrival

        if not arrival?.enabled then return nil, DEFAULT_LOCALS end

        return arrival.variants, arrival.locals
    end

    local solo <const> = SOLO_PLANS[target.kind] or settings.property

    return solo.enabled and solo.variants or nil, DEFAULT_LOCALS
end

---@param player integer
---@param spawn vector4
---@return integer
local function makeClone(player, spawn)
    local clone <const> = track(ClonePed(player, false, false, true))

    SetEntityCoordsNoOffset(clone, spawn.x, spawn.y, spawn.z + PED_ROOT_HEIGHT, false, false, false)
    SetEntityHeading(clone, spawn.w)
    SetEntityVisible(clone, true, false)
    SetEntityCollision(clone, true, true)
    FreezeEntityPosition(clone, false)
    SetBlockingOfNonTemporaryEvents(clone, true)
    SetEntityInvincible(clone, true)

    return clone
end

---Puts the player at a root position and heading, frozen until the collision there has loaded.
---@param player integer
---@param root vector3
---@param heading number
local function handOff(player, root, heading)
    SetEntityCoordsNoOffset(player, root.x, root.y, root.z, false, false, false)
    SetEntityHeading(player, heading)
    RequestCollisionAtCoord(root.x, root.y, root.z)

    local deadline <const> = GetGameTimer() + COLLISION_WAIT_MS

    while not HasCollisionLoadedAroundEntity(player) and GetGameTimer() < deadline do
        Wait(0)
    end

    SetEntityCollision(player, true, true)
    FreezeEntityPosition(player, false)
    SetEntityVisible(player, true, false)
end

---Places a ped standing on the ground at a spawn point, with no drop.
---@param player integer
---@param spawn vector4
function Arrival.settle(player, spawn)
    local ground <const> = grounded(spawn.xyz)

    handOff(player, vector3(ground.x, ground.y, ground.z + PED_ROOT_HEIGHT), spawn.w)
end

---Plays the arrival scene while the screen is faded out and the player hidden.
---Hands the player off where the scene leaves the character.
---@param spawn vector4
---@param target MulticharSpawnTarget
---@return boolean faded true when the screen is still faded out
function Arrival.play(spawn, target)
    local list <const>, locals <const> = planFor(target)
    local player <const> = PlayerPedId()

    if not list or #list == 0 then
        Arrival.settle(player, spawn)
        return true
    end

    local ground <const> = grounded(spawn.xyz)
    local origin <const> = vector4(ground.x, ground.y, ground.z, spawn.w)

    active, skipped, hintShown = true, false, false
    SetTimecycleModifier(settings.timecycle.name)
    SetTimecycleModifierStrength(settings.timecycle.strength)
    runFrame()

    local ok, played = false, false
    ---@type integer?
    local clone

    for _, name in ipairs(shuffled(list)) do
        local run <const> = variants[name]

        if run then
            clone = clone or makeClone(player, origin)

            local ctx <const> = { clone = clone, spawn = origin, locals = #locals > 0 and locals or DEFAULT_LOCALS }

            ok, played = pcall(run, ctx)

            if not ok then lib.print.error(('arrival %s failed: %s'):format(name, played)) end
            if not ok or played then break end
        end
    end

    local finished <const> = ok and played and not skipped and clone ~= nil

    if finished and clone then
        fadeOutNpcs()
        handOff(player, GetEntityCoords(clone), GetEntityHeading(clone))
    else
        if not IsScreenFadedOut() then
            DoScreenFadeOut(250)
            Wait(250)
        end

        Arrival.settle(player, spawn)
    end

    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(-8.0, 1.0)
    cleanup(finished)

    return not finished
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not active then return end

    cleanup(false)
end)

return Arrival
