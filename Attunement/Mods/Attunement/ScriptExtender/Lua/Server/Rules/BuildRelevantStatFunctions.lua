local function buildStatString(stringToModify, stringToAdd)
	local result
	if not stringToModify or stringToModify == "" then
		result = stringToAdd
	else
		if stringToModify:sub(-1) ~= ";" then
			result = stringToModify .. ";" .. stringToAdd
		else
			result = stringToModify .. stringToAdd
		end
	end

	return result
end

local slotToCategory = {
	["Helmet"] = "Armor",
	["Breast"] = "Armor",
	["Cloak"] = "Armor",
	["Boots"] = "Armor",
	["Gloves"] = "Armor",
	["Amulet"] = "Accessories",
	["Ring"] = "Accessories"
}

local statFunctions = {
	---@param stat ItemStat
	["attunements"] = function(stat, _)
		-- Friggen lua falsy logic
		local shouldAttune = ConfigurationStructure.config.items.requiresAttunementOverrides[stat.Name]
		if shouldAttune == nil then
			shouldAttune = (stat.Boosts ~= "" or stat.PassivesOnEquip ~= "" or stat.StatusOnEquip ~= "")
		end

		if shouldAttune and (not stat.UseCosts or not string.find(stat.UseCosts, "Attunement:")) then
			stat.UseCosts = buildStatString(stat.UseCosts, "Attunement:1")
		end
	end,
	---@param rarity Rarity
	---@param category RarityLimitCategories
	["rarityLimits"] = function(rarity, category)
		---@param stat ItemStat
		return function(stat)
			if stat.Rarity == rarity
				and (category == "Total"
					or (((string.find(stat.Slot, "Melee") or string.find(stat.Slot, "Ranged")) and category == "Weapon")
						or (slotToCategory[stat.Slot] or "") == category))
			then
				local resourceString = string.format("%s%sLimitAttunement:1", rarity, category)
				if (not stat.UseCosts or not string.find(stat.UseCosts, resourceString)) then
					stat.UseCosts = buildStatString(stat.UseCosts, resourceString)
				end
			end
		end
	end,
}

-- Thanks Focus
---@return AttunementRules
local function GetDifficulty()
	local difficulty = Osi.GetRulesetModifierString("cac2d8bd-c197-4a84-9df1-f86f54ad4521")
	if difficulty == "HARD" and Osi.GetRulesetModifierBool("338450d9-d77d-4950-9e1e-0e7f12210bb3") == 1 then
		difficulty = "HONOUR"
	end
	Logger:BasicInfo("Processing rules with Difficulty rules %s", ConfigManager.ConfigCopy.rules[difficulty] and difficulty or "Base")

	return ConfigManager.ConfigCopy.rules[difficulty] or ConfigManager.ConfigCopy.rules["Base"]
end

function BuildRelevantStatFunctions()
	local difficultyRules = GetDifficulty()

	local actionResources = ""

	local functionsToReturn = {}
	if difficultyRules.totalAttunementLimit < 12 then
		Logger:BasicInfo("Attunement limit is set to %s, which is less than 12 (max number of equipable slots), so enabling Attunement resources",
			difficultyRules.totalAttunementLimit)

		actionResources = buildStatString(actionResources, string.format("Attunement:%s", difficultyRules.totalAttunementLimit))
		table.insert(functionsToReturn, statFunctions["attunements"])
	end

	for _, rarity in ipairs(RarityEnum) do
		for _, category in ipairs(RarityLimitCategories) do
			local categoryMaxSlots = RarityLimitCategories[category]
			if difficultyRules.rarityLimits[rarity][category] < categoryMaxSlots then
				Logger:BasicInfo("Rarity %s's %s limit is set to %s, which is less than the max of %s, so enabling the associated resource",
					rarity,
					category,
					difficultyRules.rarityLimits[rarity][category],
					categoryMaxSlots
				)

				actionResources = buildStatString(actionResources,
					string.format("%s%sLimit:%s", rarity, category, difficultyRules.rarityLimits[rarity][category]))

				table.insert(functionsToReturn, statFunctions["rarityLimits"](rarity, category))
			end
		end
	end

	for _, characterStat in pairs(Ext.Stats.GetStats("Character")) do
		---@type Character
		local stat = Ext.Stats.Get(characterStat)

		if stat.ActionResources then
			stat.ActionResources = stat.ActionResources:gsub("[^;]*Attunement:%d+;?", "")
		end

		stat.ActionResources = buildStatString(stat.ActionResources, actionResources)
		stat:Sync()
	end

	-- for _, player in pairs(Osi.DB_Players:Get(nil)) do
	-- 	player = player[1]
	-- 	if Osi.HasPassive(player, "ATTUNEMENT_ACTION_RESOURCE_PASSIVE") == 1 then
	-- 		-- Using ReplenishType `Never` prevents restoring resource through Stats and Osiris, so hacking it
	-- 		---@type EntityHandle
	-- 		local charEntity = Ext.Entity.Get(player)

	-- 		local resources = charEntity.ActionResources.Resources

	-- 		-- TODO: Add a ModVar to track max number of attunement slots so when the difficulty is changed, we math this out correctly
	-- 		local attunementResource = resources["0869d45b-9bdf-4315-aeae-da7fb6a7ca09"][1]
	-- 		attunementResource.MaxAmount = difficultyRules.totalAttunementLimit
	-- 		attunementResource.Amount = difficultyRules.totalAttunementLimit

	-- 		charEntity:Replicate("ActionResources")
	-- 	else
	-- 		Osi.AddPassive(player, "ATTUNEMENT_ACTION_RESOURCE_PASSIVE")
	-- 	end
	-- end

	return functionsToReturn
end
