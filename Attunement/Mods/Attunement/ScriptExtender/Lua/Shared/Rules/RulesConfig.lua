-- Can't assign any of these fields to local fields for convenience - breaks VSCode Lua type hints

--- @class AttunementRules
ConfigurationStructure.DynamicClassDefinitions.rules = {
	totalAttunementLimit = 5
}

---@enum RarityLimitCategories
RarityLimitCategories = {
	[1] = "Total",
	[2] = "Weapons",
	[3] = "Armor",
	[4] = "Accessories",
	Total = 1,
	Weapons = 2,
	Armor = 3,
	Accessories = 4
}

--- @class LimitRarityBySlotGroup
ConfigurationStructure.DynamicClassDefinitions.rarityLimitPerSlot = {
	Total = 12,
	Weapons = 4,
	Armor = 5,
	Accessories = 3,
}

--- @type {[Rarity] : {[RarityLimitCategories] : number }}
ConfigurationStructure.DynamicClassDefinitions.rules.rarityLimits = {}

--- @alias DifficultyID string

---@type { [DifficultyID|'Base'] : AttunementRules }
ConfigurationStructure.config.rules = {}
