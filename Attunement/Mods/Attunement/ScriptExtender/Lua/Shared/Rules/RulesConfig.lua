-- Can't assign any of these fields to local fields for convenience - breaks VSCode Lua type hints

--- @class AttunementRules
ConfigurationStructure.DynamicClassDefinitions.rules = {
	totalAttunementLimit = 5
}

--- @class LimitRarityBySlotGroup
ConfigurationStructure.DynamicClassDefinitions.rules.rarityLimitPerSlot = {
	Weapons = 4,
	Armor = 5,
	Accessories = 3
}

--- @alias DifficultyID string

---@type { [DifficultyID] : AttunementRules }
ConfigurationStructure.config.rules = {}
