---@meta

---@class MulticharOrg
---@field label string
---@field grade string

---@class MulticharSpawnPlace
---@field id string | integer
---@field name string
---@field subtitle string
---@field door { x: number, y: number, z: number, w: number }

---@class MulticharCharacter
---@field citizenid string
---@field cid integer
---@field charinfo table
---@field money table
---@field org MulticharOrg?
---@field position { x: number, y: number, z: number }?
---@field isDead boolean
---@field lastPlayed integer? unix time of the last save
---@field starterApartment MulticharSpawnPlace?
---@field houses MulticharSpawnPlace[]

---@class MulticharSpawnTarget
---@field kind 'last' | 'apartment' | 'house' | 'favorite'
---@field id string | integer | nil

---@class MulticharSpawnOption : MulticharSpawnTarget
---@field name string
---@field subtitle string?
---@field area string?
---@field postal string?

---@class MulticharPendingSpawn
---@field coords vector4
---@field target MulticharSpawnTarget
---@field downed boolean
---@field skin table | false | nil the look the preview fetched, reused on spawn
