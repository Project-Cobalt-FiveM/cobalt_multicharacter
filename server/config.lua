---@class MulticharSlotOverride
---@field license string
---@field numberOfChars integer

return {
    -- Items every new character starts with, as item name = amount; id_card gets the character's details
    startItems = {
        phone = 1,
        id_card = 1,
        bread = 3,
        water = 3,
    },

    -- Character slots
    defaultNumberOfCharacters = 5, -- slots per player
    ---@type MulticharSlotOverride[]
    playersNumberOfCharacters = {}, -- per-player overrides: { license = 'license:...', numberOfChars = 8 }
}
