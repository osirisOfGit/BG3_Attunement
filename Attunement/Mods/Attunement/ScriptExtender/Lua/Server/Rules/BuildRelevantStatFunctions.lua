---@type AttunementRules
local difficultyRules

Ext.Vars.RegisterModVariable(ModuleUUID, "Config_State_Tracker", {
	Server = true,
	Client = false
})

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
	["Ring"] = "Accessories",
	["MusicalInstrument"] = "Accessories"
}

local statFunctions = {
	["attunements"] = function(disable)
		---@param stat ItemStat
		return function(stat)
			if (stat.Slot ~= "Underwear" and not string.find(stat.Slot, "Vanity")) then
				-- Friggen lua falsy logic
				local shouldAttune = ConfigManager.ConfigCopy.items.requiresAttunementOverrides[stat.Name]
				if shouldAttune == nil then
					shouldAttune = (RarityEnum[stat.Rarity] >= RarityEnum[ConfigManager.ConfigCopy.items.attunementRarityThreshold] and (stat.Boosts ~= "" or stat.PassivesOnEquip ~= "" or stat.StatusOnEquip ~= ""))
				end
				shouldAttune = not disable and shouldAttune

				-- Remove any occurrence of 'Attunement:<number>' (with optional leading/trailing semicolons)
				stat.UseCosts = stat.UseCosts
					:gsub(";%s*Attunement:%d+%s*;?", ";")
					:gsub("^Attunement:%d+;?", "")
					:gsub(";?Attunement:%d+$", "")
					:gsub("^;+", "")
					:gsub(";+$", "")

				if shouldAttune then
					stat.UseCosts = buildStatString(stat.UseCosts, "Attunement:" .. (difficultyRules.rarityLimits[stat.Rarity]["Attunement Slots"] or "1"))
				end
			end
		end
	end,
	---@param rarity Rarity
	---@param category RarityLimitCategories
	["rarityLimits"] = function(rarity, category, disable)
		---@param stat ItemStat
		return function(stat)
			if disable then
				-- Remove any occurrence of 'Attunement:<number>' or '<Rarity><Category>LimitAttunement:<number>' (with optional leading/trailing semicolons)
				stat.UseCosts = stat.UseCosts
					:gsub(";%s*[%w]+LimitAttunement:%d+%s*;?", ";")
					:gsub("^%w+LimitAttunement:%d+;?", "")
					:gsub(";?%w+LimitAttunement:%d+$", "")
					:gsub("^;+", "")
					:gsub(";+$", "")
			else
				if stat.Rarity == rarity
					and (category == "Total"
						or (((string.find(stat.Slot, "Melee") or string.find(stat.Slot, "Ranged")) and category == "Weapons")
							or (slotToCategory[stat.Slot] or "") == category))
				then
					local resourceString = string.format("%s%sLimitAttunement:1", rarity, category)
					if (not stat.UseCosts or not string.find(stat.UseCosts, resourceString)) then
						stat.UseCosts = buildStatString(stat.UseCosts, resourceString)
					end
				end
			end
		end
	end,
}

---@return AttunementRules
local function GetDifficulty()
	-- Thanks Focus
	local difficulty = Osi.GetRulesetModifierString("cac2d8bd-c197-4a84-9df1-f86f54ad4521")
	if Osi.GetRulesetModifierBool("ef0506df-da9f-40e2-903a-1349523c1ae4") == 1 then
		difficulty = "HONOUR"
	end
	Logger:BasicInfo("Processing rules with Difficulty rules %s", ConfigManager.ConfigCopy.rules.difficulties[difficulty] and difficulty or "Base")

	return ConfigManager.ConfigCopy.rules.difficulties[difficulty] or ConfigManager.ConfigCopy.rules.difficulties["Base"]
end

---@return function[] StatFunctions to run
---@return {[string]: number}? MaxAmounts per resource
---@return AttunementRules?
function BuildRelevantStatFunctions()
	difficultyRules = GetDifficulty()

	if not difficultyRules then
		Logger:BasicWarning("Difficulty rules haven't been configured yet, meaning this is your first time loading. Reload to pick up the functionality!")
		return {}
	end

	local actionResources = ""

	local enabled = MCM.Get("enabled")

	if not enabled then
		Logger:BasicInfo("Functionality is disabled - disabling all resources")
	end

	local maxAmounts = {}
	local functionsToReturn = {}
	if difficultyRules.totalAttunementLimit ~= 13
		-- If any of the rarities take up more than 1 attunement slot, we need to show the resource as it's not just 1:1
		or TableUtils:ListContains(difficultyRules.rarityLimits, function(value)
			return (value["Attunement Slots"] or 1) > 1
		end)
	then
		if enabled then
			Logger:BasicInfo("Attunement limit is set to %s, so enabling Attunement resources",
				difficultyRules.totalAttunementLimit)
		end

		actionResources = buildStatString(actionResources, string.format("ActionResource(Attunement,%s,0)", enabled and difficultyRules.totalAttunementLimit or 0))
		maxAmounts["Attunement"] = enabled and tonumber(difficultyRules.totalAttunementLimit) or 0
		table.insert(functionsToReturn, statFunctions["attunements"](false))
	else
		table.insert(functionsToReturn, statFunctions["attunements"](true))
	end

	for _, rarity in ipairs(RarityEnum) do
		if rarity ~= "Common" then
			for _, category in ipairs(RarityLimitCategories) do
				if category ~= "Attunement Slots" then
					local categoryMaxSlots = RarityLimitCategories[category]
					if difficultyRules.rarityLimits[rarity][category] < categoryMaxSlots then
						if enabled then
							Logger:BasicInfo("Rarity %s's %s limit is set to %s, which is less than the max of %s, so enabling the associated resource",
								rarity,
								category,
								difficultyRules.rarityLimits[rarity][category],
								categoryMaxSlots
							)
						end

						actionResources = buildStatString(actionResources,
							string.format("ActionResource(%s%sLimitAttunement,%s,0)", rarity, category, enabled and difficultyRules.rarityLimits[rarity][category] or 0))


						maxAmounts[string.format("%s%sLimitAttunement", rarity, category)] = enabled and difficultyRules.rarityLimits[rarity][category] or 0
						table.insert(functionsToReturn, statFunctions["rarityLimits"](rarity, category, false))
					else
						table.insert(functionsToReturn, statFunctions["rarityLimits"](rarity, category, true))
					end
				end
			end
		end
	end

	local configState = Ext.Vars.GetModVariables(ModuleUUID).Config_State_Tracker or {
		maxAmounts = {},
		overrides = {}
	}

	if not configState.maxAmounts then
		configState.maxAmounts = {}
	end
	if not configState.overrides then
		configState.overrides = {}
	end

	if TableUtils:CompareLists(configState.maxAmounts, maxAmounts) and TableUtils:CompareLists(configState.overrides, ConfigManager.ConfigCopy.items) then
		Logger:BasicInfo("Configuration hasn't changed for this save - skipping rest of initialization")
		return {}
	else
		Logger:BasicInfo("Configuration has been changed for this save - proceeeding with the rest of initialization")
		Ext.Vars.GetModVariables(ModuleUUID).Config_State_Tracker = {
			maxAmounts = maxAmounts,
			overrides = ConfigManager.ConfigCopy.items
		}
	end

	for _, charEntity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ActionResources")) do
		if charEntity.Uuid then
			local character = charEntity.Uuid.EntityUuid

			-- You would not believe the amount of shit i tried before i landed on this
			-- TLDR: Stats modified after StatsLoaded don't update the GUI for things using those stats that are already in the gameworld.
			-- e.g. adding a passive to CharacterStats gives them the initial passive, but changing the passive boosts on LevelGameplayReady doesn't show the resources until a reload
			-- So, shortcutting the process by just applying/removing boosts directly, which does update the GUI
			local playerAmountTracker = TableUtils:DeeplyCopyTable(maxAmounts)
			for _, boostEntry in pairs(charEntity.BoostsContainer.Boosts) do
				if boostEntry.Type == "ActionResource" then
					for _, boost in pairs(boostEntry.Boosts) do
						local resourceBoost = boost.ActionResourceValueBoost
						local resourceName = Ext.StaticData.Get(resourceBoost.ResourceUUID, "ActionResource").Name
						if playerAmountTracker[resourceName] then
							resourceBoost.Amount = playerAmountTracker[resourceName]
							playerAmountTracker[resourceName] = nil
						elseif string.match(resourceName, "^.*Attunement$") then
							Osi.RemoveBoosts(character, string.format("ActionResource(%s,%s,0)", resourceName, resourceBoost.Amount), 0, "", character)
						end
					end
					break
				end
			end

			for maxAmountResource, maxAmount in pairs(playerAmountTracker) do
				Osi.AddBoosts(character, string.format("ActionResource(%s,%s,0)", maxAmountResource, maxAmount), "", character)
			end

			local resources = charEntity.ActionResources.Resources
			for _, resource in pairs(resources) do
				local resource = resource[1]
				if Ext.StaticData.Get(resource.ResourceUUID, "ActionResource") then
					local resourceName = Ext.StaticData.Get(resource.ResourceUUID, "ActionResource").Name
					if string.match(resourceName, "^.*Attunement$") then
						if not maxAmounts[resourceName] then
							Osi.AddBoosts(character, string.format("ActionResource(%s,0,0)", resourceName), "", character)
						end
					end
				end
			end
		end
	end

	return functionsToReturn, maxAmounts, difficultyRules
end
