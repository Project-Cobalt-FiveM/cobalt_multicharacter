---@param heading number degrees
---@return vector3
local function forwardOf(heading)
    local rad <const> = math.rad(heading)

    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

return {
    forwardOf = forwardOf,
}
